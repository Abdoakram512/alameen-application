import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/core/network/api_client.dart';
import 'package:secure_screen_app/core/network/auth_interceptor.dart';
import 'package:secure_screen_app/core/storage/secure_token_storage.dart';
import 'package:secure_screen_app/datasources/auth_remote_data_source.dart';

class InMemoryTokenStorage implements SecureTokenStorage {
  String? _token;
  Map<String, dynamic>? _user;

  @override
  Future<void> saveToken(String token) async => _token = token;
  @override
  Future<String?> getToken() async => _token;
  @override
  Future<void> deleteToken() async => _token = null;
  @override
  Future<bool> hasToken() async => _token != null && _token!.isNotEmpty;
  @override
  Future<void> saveUserData(Map<String, dynamic> user) async => _user = user;
  @override
  Future<Map<String, dynamic>?> getUserData() async => _user;
  @override
  Future<void> deleteUserData() async => _user = null;
  @override
  Future<void> clearAll() async {
    _token = null;
    _user = null;
  }
}

class MockHttpClientAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) _handler;
  MockHttpClientAdapter(this._handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;
  late ApiClient apiClient;
  late AuthRemoteDataSource remoteDataSource;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://api.elameen.test/api/v1'));
    apiClient = ApiClient(
      dio: dio,
      authInterceptor: AuthInterceptor(tokenStorage: InMemoryTokenStorage()),
    );
    remoteDataSource = AuthRemoteDataSourceImpl(apiClient: apiClient);
  });

  group('AuthRemoteDataSource Contract & Implementation Tests', () {
    test('register returns pending status and Arabic message on 201', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        expect(options.path, equals('/auth/register'));
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'status': 'pending',
            'message': 'تم إنشاء حسابك بنجاح وهو الآن قيد المراجعة من قِبل إدارة المنصة.',
            'data': {
              'user': {
                'id': 15,
                'name': 'د. أحمد محمد',
                'email': 'ahmed@example.com',
                'status': 'pending',
              }
            }
          }),
          201,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final result = await remoteDataSource.register(
        name: 'د. أحمد محمد',
        email: 'ahmed@example.com',
        password: 'password123',
        passwordConfirmation: 'password123',
        phone: '01012345678',
      );

      expect(result.isPending, isTrue);
      expect(result.isAuthenticated, isFalse);
      expect(result.token, isNull);
      expect(result.message, contains('قيد المراجعة'));
      expect(result.user, isNotNull);
      expect(result.user!.displayName, equals('د. أحمد محمد'));
      expect(result.user!.isPending, isTrue);
    });

    test('login returns Sanctum token and authenticated user on 200', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        expect(options.path, equals('/auth/login'));
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'status': 'authenticated',
            'message': 'تم تسجيل الدخول بنجاح.',
            'data': {
              'token': '1|laravel_sanctum_token_abc123',
              'token_type': 'Bearer',
              'user': {
                'id': 15,
                'name': 'د. أحمد محمد',
                'email': 'student@example.com',
                'status': 'active',
              }
            }
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final result = await remoteDataSource.login(
        email: 'student@example.com',
        password: 'password123',
      );

      expect(result.isAuthenticated, isTrue);
      expect(result.token, equals('1|laravel_sanctum_token_abc123'));
      expect(result.tokenType, equals('Bearer'));
      expect(result.user, isNotNull);
      expect(result.user!.id, equals(15));
      expect(result.user!.displayName, equals('د. أحمد محمد'));
      expect(result.user!.isPending, isFalse);
    });

    test('login returns pending status when account is pending on 403', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        return ResponseBody.fromString(
          jsonEncode({
            'status': 'pending',
            'message': 'حسابك قيد المراجعة من قِبل إدارة المنصة.',
          }),
          403,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final result = await remoteDataSource.login(
        email: 'pending@example.com',
        password: 'password123',
      );

      expect(result.isPending, isTrue);
      expect(result.isAuthenticated, isFalse);
      expect(result.token, isNull);
      expect(result.message, contains('قيد المراجعة'));
    });

    test('loginWithGoogleToken sends OAuth access_token and returns AuthResult', () async {
      RequestOptions? recordedOptions;
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        recordedOptions = options;
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'status': 'authenticated',
            'message': 'تم تسجيل الدخول عبر Google بنجاح.',
            'data': {
              'token': '2|google_sanctum_token_xyz',
              'token_type': 'Bearer',
              'user': {
                'id': 20,
                'name': 'طالب جوجل',
                'email': 'google.student@gmail.com',
                'status': 'active',
              }
            }
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final result = await remoteDataSource.loginWithGoogleToken(
        accessToken: 'ya29.a0AfH6SMBx_mock_oauth_access_token',
      );

      expect(recordedOptions, isNotNull);
      expect(recordedOptions!.path, equals('/auth/google/token'));
      expect(result.isAuthenticated, isTrue);
      expect(result.token, equals('2|google_sanctum_token_xyz'));
      expect(result.user!.email, equals('google.student@gmail.com'));
    });

    test('loginWithFirebaseIdToken sends id_token to transition bridge', () async {
      RequestOptions? recordedOptions;
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        recordedOptions = options;
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'status': 'authenticated',
            'message': 'تم تسجيل الدخول عبر Firebase بنجاح.',
            'data': {
              'token': '3|firebase_sanctum_token_123',
              'token_type': 'Bearer',
              'user': {
                'id': 25,
                'name': 'طالب قديم',
                'email': 'legacy@example.com',
                'status': 'active',
              }
            }
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final result = await remoteDataSource.loginWithFirebaseIdToken(
        idToken: 'mock_firebase_jwt_id_token',
      );

      expect(recordedOptions, isNotNull);
      expect(recordedOptions!.path, equals('/auth/firebase'));
      expect(result.isAuthenticated, isTrue);
      expect(result.token, equals('3|firebase_sanctum_token_123'));
      expect(result.user!.displayName, equals('طالب قديم'));
    });

    test('getMe returns current UserModel profile', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        expect(options.path, equals('/auth/me'));
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'data': {
              'user': {
                'id': 15,
                'name': 'د. أحمد محمد',
                'email': 'student@example.com',
                'phone': '+201012345678',
                'country': 'Egypt',
                'city': 'Cairo',
                'status': 'active',
                'created_at': '2026-10-01T08:55:00+02:00',
              }
            }
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final user = await remoteDataSource.getMe();
      expect(user.id, equals(15));
      expect(user.displayName, equals('د. أحمد محمد'));
      expect(user.phone, equals('+201012345678'));
      expect(user.city, equals('Cairo'));
      expect(user.isPending, isFalse);
    });

    test('forgotPassword dispatches OTP email request', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        expect(options.path, equals('/auth/forgot-password'));
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'message': 'تم إرسال رمز التحقق إلى بريدك الإلكتروني.',
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final msg = await remoteDataSource.forgotPassword(email: 'student@example.com');
      expect(msg, contains('رمز التحقق'));
    });

    test('verifyOtp validates 6-digit OTP code', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        expect(options.path, equals('/auth/verify-otp'));
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'valid': true,
            'message': 'رمز التحقق صحيح.',
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final isValid = await remoteDataSource.verifyOtp(
        email: 'student@example.com',
        otp: '123456',
      );
      expect(isValid, isTrue);
    });

    test('resetPassword submits new password and confirmation', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        expect(options.path, equals('/auth/reset-password'));
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'message': 'تمت إعادة تعيين كلمة المرور بنجاح.',
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final msg = await remoteDataSource.resetPassword(
        email: 'student@example.com',
        otp: '123456',
        password: 'new_password_123',
        passwordConfirmation: 'new_password_123',
      );
      expect(msg, contains('إعادة تعيين كلمة المرور'));
    });
  });
}

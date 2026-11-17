import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/core/network/api_client.dart';
import 'package:secure_screen_app/core/network/api_exceptions.dart';
import 'package:secure_screen_app/core/network/auth_interceptor.dart';
import 'package:secure_screen_app/core/storage/secure_token_storage.dart';

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
  late InMemoryTokenStorage tokenStorage;
  late AuthInterceptor authInterceptor;
  late Dio dio;
  late ApiClient apiClient;

  setUp(() {
    tokenStorage = InMemoryTokenStorage();
    authInterceptor = AuthInterceptor(tokenStorage: tokenStorage);
    dio = Dio(BaseOptions(baseUrl: 'http://api.elameen.test/api/v1'));
    apiClient = ApiClient(dio: dio, authInterceptor: authInterceptor);
  });

  group('ApiClient Network & AuthInterceptor Tests', () {
    test('Injects standard headers (Accept, X-Locale, Accept-Language)', () async {
      RequestOptions? recordedOptions;

      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        recordedOptions = options;
        return ResponseBody.fromString(
          jsonEncode({'success': true, 'data': {}}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      await apiClient.get('/public/test');

      expect(recordedOptions, isNotNull);
      expect(recordedOptions!.headers['Accept'], equals('application/json'));
      expect(recordedOptions!.headers['X-Locale'], equals('ar'));
      expect(recordedOptions!.headers['Accept-Language'], equals('ar'));
      expect(recordedOptions!.headers.containsKey('Authorization'), isFalse);
    });

    test('Injects Authorization Bearer header when token is stored', () async {
      await tokenStorage.saveToken('sanctum_secret_token_abc');
      RequestOptions? recordedOptions;

      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        recordedOptions = options;
        return ResponseBody.fromString(
          jsonEncode({'success': true, 'data': {'user_id': 1}}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      await apiClient.get('/student/dashboard');

      expect(recordedOptions, isNotNull);
      expect(recordedOptions!.headers['Authorization'], equals('Bearer sanctum_secret_token_abc'));
    });

    test('getParsed decodes ApiResponse envelope correctly', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'message': 'تم جلب البيانات بنجاح',
            'data': {'course_id': 'flutter_101', 'title': 'كورس فلاتر الاحترافي'},
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final response = await apiClient.getParsed<Map<String, dynamic>>(
        '/student/courses/flutter_101',
        fromDataJson: (json) => json as Map<String, dynamic>,
      );

      expect(response.success, isTrue);
      expect(response.message, equals('تم جلب البيانات بنجاح'));
      expect(response.data!['course_id'], equals('flutter_101'));
      expect(response.data!['title'], equals('كورس فلاتر الاحترافي'));
    });

    test('Maps HTTP 401 to UnauthorizedException and clears stored token', () async {
      await tokenStorage.saveToken('expired_token_123');
      expect(await tokenStorage.hasToken(), isTrue);

      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        return ResponseBody.fromString(
          jsonEncode({'message': 'Unauthenticated.'}),
          401,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      await expectLater(
        () => apiClient.get('/student/protected-endpoint'),
        throwsA(isA<UnauthorizedException>().having(
          (e) => e.statusCode,
          'statusCode',
          401,
        )),
      );

      // Verify token was revoked locally
      expect(await tokenStorage.hasToken(), isFalse);
    });

    test('Maps HTTP 403 to ForbiddenException without clearing token', () async {
      await tokenStorage.saveToken('valid_token_pending_student');

      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        return ResponseBody.fromString(
          jsonEncode({'message': 'حسابك قيد المراجعة من قِبل إدارة المنصة.'}),
          403,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      await expectLater(
        () => apiClient.get('/student/courses/locked-course'),
        throwsA(isA<ForbiddenException>().having(
          (e) => e.message,
          'message',
          contains('قيد المراجعة'),
        )),
      );

      // Token should remain because 403 is access denial, not expired credentials
      expect(await tokenStorage.hasToken(), isTrue);
    });

    test('Maps HTTP 422 to ValidationException with parsed field errors', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        return ResponseBody.fromString(
          jsonEncode({
            'message': 'بيانات الإدخال غير صالحة.',
            'errors': {
              'email': ['البريد الإلكتروني مستخدم بالفعل.'],
              'password': ['كلمة المرور يجب ألا تقل عن 8 أحرف.'],
            },
          }),
          422,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      try {
        await apiClient.post('/auth/register', data: {});
        fail('Should have thrown ValidationException');
      } on ValidationException catch (e) {
        expect(e.statusCode, equals(422));
        expect(e.errors.containsKey('email'), isTrue);
        expect(e.errors['email'], contains('البريد الإلكتروني مستخدم بالفعل.'));
        expect(e.firstErrorMessage, equals('البريد الإلكتروني مستخدم بالفعل.'));
      }
    });

    test('Maps HTTP 429 to RateLimitException with retry-after header', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        return ResponseBody.fromString(
          jsonEncode({'message': 'Too Many Requests.'}),
          429,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'retry-after': ['60'],
          },
        );
      });

      try {
        await apiClient.post('/auth/login', data: {});
        fail('Should have thrown RateLimitException');
      } on RateLimitException catch (e) {
        expect(e.statusCode, equals(429));
        expect(e.retryAfterSeconds, equals(60));
      }
    });

    test('Maps HTTP 500 to ServerException', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        return ResponseBody.fromString(
          jsonEncode({'message': 'Internal Server Error'}),
          500,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      await expectLater(
        () => apiClient.get('/student/dashboard'),
        throwsA(isA<ServerException>().having(
          (e) => e.statusCode,
          'statusCode',
          500,
        )),
      );
    });

    test('Maps connection timeout to NetworkTimeoutException', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        );
      });

      await expectLater(
        () => apiClient.get('/student/dashboard'),
        throwsA(isA<NetworkTimeoutException>().having(
          (e) => e.message,
          'message',
          contains('مهلة الاتصال'),
        )),
      );
    });
  });
}

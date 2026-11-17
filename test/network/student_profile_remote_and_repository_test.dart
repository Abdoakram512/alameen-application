import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/core/network/api_client.dart';
import 'package:secure_screen_app/core/network/auth_interceptor.dart';
import 'package:secure_screen_app/core/storage/secure_token_storage.dart';
import 'package:secure_screen_app/datasources/auth_remote_data_source.dart';
import 'package:secure_screen_app/datasources/courses_remote_data_source.dart';
import 'package:secure_screen_app/repositories/impl/student_courses_repository_impl.dart';
import 'package:secure_screen_app/repositories/impl/student_profile_repository_impl.dart';

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
  late AuthRemoteDataSource authRemoteDataSource;
  late CoursesRemoteDataSource coursesRemoteDataSource;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://api.elameen.test/api/v1'));
    apiClient = ApiClient(
      dio: dio,
      authInterceptor: AuthInterceptor(tokenStorage: InMemoryTokenStorage()),
    );
    authRemoteDataSource = AuthRemoteDataSourceImpl(apiClient: apiClient);
    coursesRemoteDataSource = CoursesRemoteDataSourceImpl(apiClient: apiClient);
  });

  ResponseBody jsonResponse(Map<String, dynamic> data, {int statusCode = 200}) {
    return ResponseBody.fromString(
      jsonEncode(data),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  group('Student Profile & Courses Repository Tests (P3)', () {
    test('getProfile() sends GET /student/settings/profile and maps UserModel', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        expect(options.path, equals('/student/settings/profile'));
        expect(options.method, equals('GET'));
        return jsonResponse({
          'success': true,
          'data': {
            'user': {
              'id': 15,
              'name': 'أحمد إبراهيم',
              'email': 'ahmed.ibrahim@example.com',
              'phone': '+201012345678',
              'status': 'active',
              'email_verified': true,
              'created_at': '2026-01-15T08:30:00Z',
            }
          }
        });
      });

      final user = await authRemoteDataSource.getProfile();
      expect(user.id, equals(15));
      expect(user.displayName, equals('أحمد إبراهيم'));
      expect(user.email, equals('ahmed.ibrahim@example.com'));
      expect(user.phone, equals('+201012345678'));
      expect(user.status, equals('active'));
    });

    test('updateProfile() sends multipart POST /student/settings/profile', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        expect(options.path, equals('/student/settings/profile'));
        expect(options.method, equals('POST'));
        expect(options.contentType, contains('multipart/form-data'));
        return jsonResponse({
          'success': true,
          'message': 'تم تحديث البيانات بنجاح',
          'data': {
            'user': {
              'id': 15,
              'name': 'د. أحمد إبراهيم المعدل',
              'email': 'ahmed.ibrahim@example.com',
              'phone': '+201099999999',
              'status': 'active',
            }
          }
        });
      });

      final updatedUser = await authRemoteDataSource.updateProfile(
        name: 'د. أحمد إبراهيم المعدل',
        phone: '+201099999999',
      );

      expect(updatedUser.displayName, equals('د. أحمد إبراهيم المعدل'));
      expect(updatedUser.phone, equals('+201099999999'));
    });

    test('deleteAccount() sends DELETE /student/settings/profile with current_password', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        expect(options.path, equals('/student/settings/profile'));
        expect(options.method, equals('DELETE'));
        final data = options.data as Map;
        expect(data['current_password'], equals('Secret1234#'));
        return jsonResponse({
          'success': true,
          'message': 'تم حذف حسابك وجميع بياناتك بنجاح',
        });
      });

      final success = await authRemoteDataSource.deleteAccount(
        currentPassword: 'Secret1234#',
      );
      expect(success, isTrue);
    });

    test('StudentProfileRepositoryImpl delegates to AuthRemoteDataSource', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        if (options.path == '/student/settings/profile' && options.method == 'GET') {
          return jsonResponse({
            'success': true,
            'data': {
              'user': {
                'id': 42,
                'name': 'طالب الأمين المتميز',
                'email': 'student42@alameen.com',
                'status': 'active',
              }
            }
          });
        }
        return jsonResponse({'success': true});
      });

      final repository = StudentProfileRepositoryImpl(
        authRemoteDataSource: authRemoteDataSource,
      );

      final profile = await repository.getProfile();
      expect(profile, isNotNull);
      expect(profile?.displayName, equals('طالب الأمين المتميز'));
      expect(profile?.email, equals('student42@alameen.com'));
    });

    test('StudentCoursesRepositoryImpl fetches public courses and streams them', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) {
        return jsonResponse({
          'success': true,
          'data': {
            'courses': [
              {
                'id': 101,
                'slug': 'test-course',
                'title': 'كورس تشخيص النطق المتقدم',
                'price': 1200,
                'videos_count': 15,
                'is_published': true,
              }
            ]
          }
        });
      });

      final repository = StudentCoursesRepositoryImpl(
        remoteDataSource: coursesRemoteDataSource,
      );

      final courses = await repository.getPublicCourses();
      expect(courses.length, equals(1));
      expect(courses.first.title, contains('تشخيص النطق'));
      expect(courses.first.price, equals(1200.0));
      expect(courses.first.totalLessonsCount, equals(15));
    });
  });
}

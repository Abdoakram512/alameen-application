import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/core/network/api_client.dart';
import 'package:secure_screen_app/core/network/auth_interceptor.dart';
import 'package:secure_screen_app/core/storage/course_local_cache.dart';
import 'package:secure_screen_app/core/storage/secure_token_storage.dart';
import 'package:secure_screen_app/datasources/courses_remote_data_source.dart';
import 'package:secure_screen_app/repositories/impl/student_content_repository_impl.dart';
import 'package:secure_screen_app/repositories/impl/student_courses_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LiveTestTokenStorage implements SecureTokenStorage {
  String? _token;
  Map<String, dynamic>? _user;

  @override
  Future<void> saveToken(String token) async {
    _token = token;
  }

  @override
  Future<String?> getToken() async => _token;

  @override
  Future<void> deleteToken() async {
    _token = null;
  }

  @override
  Future<bool> hasToken() async => _token != null;

  @override
  Future<void> saveUserData(Map<String, dynamic> user) async {
    _user = user;
  }

  @override
  Future<Map<String, dynamic>?> getUserData() async => _user;

  @override
  Future<void> deleteUserData() async {
    _user = null;
  }

  @override
  Future<void> clearAll() async {
    _token = null;
    _user = null;
  }
}

class RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = RealHttpOverrides();

  group('Live Backend Integration Tests (Real HTTP over https://alameen-center.online/api/v1)', () {
    late ApiClient apiClient;
    late CoursesRemoteDataSource remoteDataSource;
    late CourseLocalCache localCache;
    late StudentCoursesRepositoryImpl coursesRepository;
    late StudentContentRepositoryImpl contentRepository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      localCache = CourseLocalCacheImpl();

      final tokenStorage = LiveTestTokenStorage();
      final authInterceptor = AuthInterceptor(
        tokenStorage: tokenStorage,
        onSessionExpired: () {},
      );

      apiClient = ApiClient(
        authInterceptor: authInterceptor,
        baseUrl: 'https://alameen-center.online/api/v1',
      );

      remoteDataSource = CoursesRemoteDataSourceImpl(apiClient: apiClient);
      coursesRepository = StudentCoursesRepositoryImpl(
        remoteDataSource: remoteDataSource,
        localCache: localCache,
        tokenStorage: tokenStorage,
      );
      contentRepository = StudentContentRepositoryImpl(
        coursesRemoteDataSource: remoteDataSource,
        localCache: localCache,
      );
    });

    test('Live GET /public/bootstrap returns real platform data and parses cleanly', () async {
      final bootstrap = await remoteDataSource.getBootstrapConfig();

      expect(bootstrap.siteName, equals('مركز الأمين'));
      expect(bootstrap.currencySymbol, equals('ج.م'));
      expect(bootstrap.logoUrl, contains('https://alameen-center.online'));
      expect(bootstrap.logoUrl, isNot(contains('localhost')));
      expect(bootstrap.logoUrl, isNot(contains('alameen.edu.sa')));
    });

    test('Live GET /public/courses returns real published courses and resolves thumbnail', () async {
      final courses = await remoteDataSource.getPublicCourses();

      expect(courses, isNotEmpty);
      final firstCourse = courses.first;
      expect(firstCourse.id, equals('2'));
      expect(firstCourse.slug, equals('course-rdleht1a'));
      expect(firstCourse.title, contains('كورس التخاطب الشامل'));
      expect(firstCourse.price, greaterThan(0));
      expect(firstCourse.thumbnailUrl, startsWith('https://alameen-center.online'));
      expect(firstCourse.thumbnailUrl, isNot(contains('localhost')));
    });

    test('Live GET /public/courses/{slug} returns course details with levels and lessons', () async {
      final course = await remoteDataSource.getPublicCourseBySlug('course-rdleht1a');

      expect(course.id, equals('2'));
      expect(course.slug, equals('course-rdleht1a'));
      expect(course.levels, isNotEmpty);
      expect(course.levels.first.title, equals('المستوى الاول'));
      expect(course.levels.first.lessons, isNotEmpty);
      expect(course.levels.first.lessons.length, equals(5));
      expect(course.levels.first.lessons.first.title, isNotEmpty);
    });

    test('Live GET /public/contact returns real contact channels', () async {
      final contact = await remoteDataSource.getContactInfo();

      expect(contact.email, equals('hm2991479@gmail.com'));
      expect(contact.phone, equals('01005123784'));
      expect(contact.whatsapp, equals('https://wa.me/201005123784'));
      expect(contact.address, isNotEmpty);
    });

    test('StudentCoursesRepositoryImpl caches live courses without any Firestore fallback', () async {
      final courses = await coursesRepository.getCourses();

      expect(courses, isNotEmpty);
      expect(courses.first.slug, equals('course-rdleht1a'));

      // Check that cache now holds this data
      final cached = await localCache.getPublicCourses();
      expect(cached, isNotNull);
      expect(cached!.length, equals(courses.length));
      expect(cached.first.slug, equals('course-rdleht1a'));
    });

    test('StudentContentRepositoryImpl retrieves bootstrap and contact info cleanly', () async {
      final bootstrap = await contentRepository.getBootstrapConfig();
      expect(bootstrap?.siteName, equals('مركز الأمين'));
      final contact = await contentRepository.getContactInfo();
      expect(contact?.phone, equals('01005123784'));
    });
  });
}

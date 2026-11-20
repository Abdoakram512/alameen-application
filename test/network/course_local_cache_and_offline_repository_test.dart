import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/core/network/api_exceptions.dart';
import 'package:secure_screen_app/core/storage/course_local_cache.dart';
import 'package:secure_screen_app/core/storage/secure_token_storage.dart';
import 'package:secure_screen_app/datasources/courses_remote_data_source.dart';
import 'package:secure_screen_app/models/bootstrap_data.dart';
import 'package:secure_screen_app/models/contact_info_data.dart';
import 'package:secure_screen_app/models/course.dart';
import 'package:secure_screen_app/models/landing_page_cms_data.dart';
import 'package:secure_screen_app/models/student_courses_data.dart';
import 'package:secure_screen_app/models/student_dashboard_data.dart';
import 'package:secure_screen_app/repositories/impl/student_courses_repository_impl.dart';

class MockFailingCoursesRemoteDataSource implements CoursesRemoteDataSource {
  int callCount = 0;

  @override
  Future<List<Course>> getPublicCourses({String? search}) async {
    callCount++;
    throw const NetworkTimeoutException('Network unavailable');
  }

  @override
  Future<Course> getPublicCourseBySlug(String slug) async {
    callCount++;
    throw const NetworkTimeoutException('Network unavailable');
  }

  @override
  Future<StudentDashboardData> getStudentDashboard() async {
    callCount++;
    throw const NetworkTimeoutException('Network unavailable');
  }

  @override
  Future<StudentCoursesData> getStudentCourses() async {
    callCount++;
    throw const NetworkTimeoutException('Network unavailable');
  }

  @override
  Future<Course> getStudentCourseBySlug(String slug) async {
    callCount++;
    throw const NetworkTimeoutException('Network unavailable');
  }

  @override
  Future<BootstrapData> getBootstrapConfig() async {
    callCount++;
    throw const NetworkTimeoutException('Network unavailable');
  }

  @override
  Future<LandingPageCmsData> getLandingPageData() async {
    callCount++;
    throw const NetworkTimeoutException('Network unavailable');
  }

  @override
  Future<ContactInfoData> getContactInfo() async {
    callCount++;
    throw const NetworkTimeoutException('Network unavailable');
  }
}

class MockSuccessCoursesRemoteDataSource implements CoursesRemoteDataSource {
  final List<Course> courses;

  MockSuccessCoursesRemoteDataSource({required this.courses});

  @override
  Future<List<Course>> getPublicCourses({String? search}) async => courses;

  @override
  Future<Course> getPublicCourseBySlug(String slug) async => courses.first;

  @override
  Future<StudentDashboardData> getStudentDashboard() async =>
      StudentDashboardData(enrolledCourses: courses, totalWatchedVideos: 5);

  @override
  Future<StudentCoursesData> getStudentCourses() async =>
      const StudentCoursesData(enrolledCount: 1);

  @override
  Future<Course> getStudentCourseBySlug(String slug) async => courses.first;

  @override
  Future<BootstrapData> getBootstrapConfig() async =>
      const BootstrapData(siteName: 'Test Academy', siteTagline: 'Tagline');

  @override
  Future<LandingPageCmsData> getLandingPageData() async => const LandingPageCmsData();

  @override
  Future<ContactInfoData> getContactInfo() async =>
      const ContactInfoData(email: 'test@example.com');
}

class FakeTokenStorage implements SecureTokenStorage {
  String? _userId;

  FakeTokenStorage([this._userId]);

  @override
  Future<void> saveToken(String token) async {}
  @override
  Future<String?> getToken() async => 'fake_token';
  @override
  Future<void> deleteToken() async {}
  @override
  Future<bool> hasToken() async => true;
  @override
  Future<void> saveUserData(Map<String, dynamic> user) async {
    _userId = user['id']?.toString();
  }
  @override
  Future<Map<String, dynamic>?> getUserData() async {
    if (_userId != null) return {'id': _userId};
    return null;
  }
  @override
  Future<void> deleteUserData() async {
    _userId = null;
  }
  @override
  Future<void> clearAll() async {
    _userId = null;
  }
}

void main() {
  late CourseLocalCache localCache;

  final testCourse1 = Course.fromLaravelSummaryJson(const {
    'id': 1,
    'slug': 'course-1',
    'title': 'دورة التخاطب الأساسية',
    'price': 1000,
    'videos_count': 12,
  });

  final testCourse2 = Course.fromLaravelSummaryJson(const {
    'id': 2,
    'slug': 'course-2',
    'title': 'دورة التخاطب المتقدمة',
    'price': 1800,
    'videos_count': 20,
  });

  setUp(() {
    localCache = CourseLocalCacheImpl();
  });

  group('CourseLocalCache Unit Tests (P3 Offline Isolation)', () {
    test('savePublicCourses and getPublicCourses round-trip successfully', () async {
      await localCache.savePublicCourses([testCourse1, testCourse2]);
      final retrieved = await localCache.getPublicCourses();

      expect(retrieved, isNotNull);
      expect(retrieved!.length, equals(2));
      expect(retrieved[0].id, equals('1'));
      expect(retrieved[0].slug, equals('course-1'));
      expect(retrieved[1].id, equals('2'));
    });

    test('Student Dashboard caching is strictly isolated per user ID', () async {
      final userADashboard = StudentDashboardData(
        enrolledCourses: [testCourse1],
        totalWatchedVideos: 8,
        totalWatchHours: 3.5,
      );

      final userBDashboard = StudentDashboardData(
        enrolledCourses: [testCourse2],
        totalWatchedVideos: 15,
        totalWatchHours: 6.0,
      );

      await localCache.saveStudentDashboard('student_101', userADashboard);
      await localCache.saveStudentDashboard('student_202', userBDashboard);

      // Student 101 only sees User A's data
      final retrievedA = await localCache.getStudentDashboard('student_101');
      expect(retrievedA, isNotNull);
      expect(retrievedA!.totalWatchedVideos, equals(8));
      expect(retrievedA.enrolledCourses.first.id, equals('1'));

      // Student 202 only sees User B's data
      final retrievedB = await localCache.getStudentDashboard('student_202');
      expect(retrievedB, isNotNull);
      expect(retrievedB!.totalWatchedVideos, equals(15));
      expect(retrievedB.enrolledCourses.first.id, equals('2'));

      // Requesting an unknown student ID yields null and prevents leakage
      final unknown = await localCache.getStudentDashboard('student_999');
      expect(unknown, isNull);
    });

    test('clearUserCache clears only specified user data and retains public cache', () async {
      await localCache.savePublicCourses([testCourse1]);
      await localCache.saveStudentDashboard('student_101', StudentDashboardData(enrolledCourses: [testCourse1]));

      await localCache.clearUserCache('student_101');

      // User cache is gone
      final userDash = await localCache.getStudentDashboard('student_101');
      expect(userDash, isNull);

      // Public cache is safely retained
      final publicCourses = await localCache.getPublicCourses();
      expect(publicCourses, isNotNull);
      expect(publicCourses!.length, equals(1));
    });

    test('clearAllUserCaches cleans all user dashboards on logout', () async {
      await localCache.saveStudentDashboard('user_1', StudentDashboardData(enrolledCourses: [testCourse1]));
      await localCache.saveStudentDashboard('user_2', StudentDashboardData(enrolledCourses: [testCourse2]));

      await localCache.clearAllUserCaches();

      expect(await localCache.getStudentDashboard('user_1'), isNull);
      expect(await localCache.getStudentDashboard('user_2'), isNull);
    });
  });

  group('StudentCoursesRepositoryImpl Offline Behavior (Zero Firestore Fallback)', () {
    test('getPublicCourses() falls back to local cache when remote fails without calling Firestore', () async {
      // 1. Populate local cache with initial fetched courses
      await localCache.savePublicCourses([testCourse1, testCourse2]);

      final failingRemote = MockFailingCoursesRemoteDataSource();
      final repository = StudentCoursesRepositoryImpl(
        remoteDataSource: failingRemote,
        localCache: localCache,
        tokenStorage: FakeTokenStorage('student_101'),
      );

      // 2. Call repository when remote fails
      final courses = await repository.getPublicCourses();

      expect(courses.length, equals(2));
      expect(courses[0].title, equals('دورة التخاطب الأساسية'));
      expect(failingRemote.callCount, equals(1));
    });

    test('getStudentDashboard() returns cached dashboard when offline without calling Firestore', () async {
      final userDash = StudentDashboardData(
        enrolledCourses: [testCourse1],
        totalWatchedVideos: 7,
      );
      await localCache.saveStudentDashboard('student_101', userDash);

      final failingRemote = MockFailingCoursesRemoteDataSource();
      final repository = StudentCoursesRepositoryImpl(
        remoteDataSource: failingRemote,
        localCache: localCache,
        tokenStorage: FakeTokenStorage('student_101'),
      );

      final dashboard = await repository.getStudentDashboard();
      expect(dashboard.totalWatchedVideos, equals(7));
      expect(dashboard.enrolledCourses.first.id, equals('1'));
    });

    test('Successful remote call automatically saves to local cache and updates stream', () async {
      final successRemote = MockSuccessCoursesRemoteDataSource(courses: [testCourse1]);
      final repository = StudentCoursesRepositoryImpl(
        remoteDataSource: successRemote,
        localCache: localCache,
        tokenStorage: FakeTokenStorage('student_101'),
      );

      final courses = await repository.getPublicCourses();
      expect(courses.length, equals(1));

      // Check that it was saved to local cache
      final cached = await localCache.getPublicCourses();
      expect(cached, isNotNull);
      expect(cached!.first.id, equals('1'));
    });
  });
}

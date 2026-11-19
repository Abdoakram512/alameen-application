import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secure_screen_app/core/di/injection_container.dart';
import 'package:secure_screen_app/core/storage/course_local_cache.dart';
import 'package:secure_screen_app/core/storage/secure_token_storage.dart';
import 'package:secure_screen_app/datasources/courses_remote_data_source.dart';
import 'package:secure_screen_app/logic/auth/auth_cubit.dart';
import 'package:secure_screen_app/logic/auth/auth_state.dart';
import 'package:secure_screen_app/logic/courses/courses_cubit.dart';
import 'package:secure_screen_app/logic/courses/courses_state.dart';
import 'package:secure_screen_app/models/course.dart';
import 'package:secure_screen_app/models/user_profile.dart';
import 'package:secure_screen_app/repositories/impl/student_content_repository_impl.dart';
import 'package:secure_screen_app/repositories/impl/student_courses_repository_impl.dart';
import 'package:secure_screen_app/core/network/api_client.dart';
import 'package:secure_screen_app/repositories/student_auth_repository.dart';
import 'package:secure_screen_app/repositories/student_content_repository.dart';
import 'package:secure_screen_app/repositories/student_courses_repository.dart';
import 'package:secure_screen_app/repositories/student_profile_repository.dart';
import 'package:secure_screen_app/screens/info/about_us_screen.dart';
import 'package:secure_screen_app/screens/info/faqs_screen.dart';
import 'package:secure_screen_app/screens/info/privacy_policy_screen.dart';
import 'package:secure_screen_app/screens/security/security_protection_watcher.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockStudentAuthRepository extends Mock implements StudentAuthRepository {}

class MockStudentProfileRepository extends Mock implements StudentProfileRepository {}

class MockStudentCoursesRepository extends Mock implements StudentCoursesRepository {}

class MockCourseLocalCache extends Mock implements CourseLocalCache {}

class MockCoursesRemoteDataSource extends Mock implements CoursesRemoteDataSource {}

class MockStudentContentRepository extends Mock implements StudentContentRepository {}

class InMemoryTokenStorage implements SecureTokenStorage {
  String? _token = 'test_sanctum_token';
  Map<String, dynamic>? _user = {
    'id': 99,
    'uid': '99',
    'name': 'طالب لارفيل فقط',
    'email': 'laravel_only@alameen.com',
  };

  @override
  Future<void> saveToken(String token) async => _token = token;
  @override
  Future<String?> getToken() async => _token;
  @override
  Future<void> deleteToken() async => _token = null;
  @override
  Future<bool> hasToken() async => _token != null;
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
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  tearDown(() {
  });

  group('P3 Clean Architecture & Zero Legacy Debt Verification Tests', () {
    test('1. CMS Repository getAboutUs() parses from Laravel API (/public/home) without Firestore', () async {
      final mockCoursesRemote = MockCoursesRemoteDataSource();
      when(() => mockCoursesRemote.getLandingPageData()).thenAnswer(
        (_) async => {
          'hero': {
            'headline': 'مركز الأمين الدولي للتخاطب',
            'subheadline': 'الريادة والتميز في التأهيل',
          },
          'about_pillars': [
            {'title': 'الاعتماد الأكاديمي', 'description': 'شهادات موثقة'},
            {'title': 'التطبيق العملي', 'description': 'تدريب سريري مباشر'},
          ],
        },
      );

      final repo = StudentContentRepositoryImpl(
        coursesRemoteDataSource: mockCoursesRemote,
      );

      final about = await repo.getAboutUs();
      expect(about['title'], equals('مركز الأمين الدولي للتخاطب'));
      expect(about['content'], contains('الريادة والتميز'));
      expect(about['content'], contains('• الاعتماد الأكاديمي: شهادات موثقة'));
      expect(about['content'], contains('• التطبيق العملي: تدريب سريري مباشر'));
    });

    test('2. CMS Repository getFaqs() parses FAQ list from Laravel API without Firestore', () async {
      final mockCoursesRemote = MockCoursesRemoteDataSource();
      when(() => mockCoursesRemote.getLandingPageData()).thenAnswer(
        (_) async => {
          'faq': [
            {
              'question': 'هل التدريب معتمد من المركز؟',
              'answer': 'نعم، معتمد دولياً ومحلياً.',
            },
            {
              'question': 'ما هي مدة صلاحية الكورس؟',
              'answer': 'صلاحية غير محدودة لمدة عام كامل.',
            },
          ],
        },
      );

      final repo = StudentContentRepositoryImpl(
        coursesRemoteDataSource: mockCoursesRemote,
      );

      final faqs = await repo.getFaqs();
      expect(faqs.length, equals(2));
      expect(faqs[0]['question'], equals('هل التدريب معتمد من المركز؟'));
      expect(faqs[0]['answer'], equals('نعم، معتمد دولياً ومحلياً.'));
      expect(faqs[1]['question'], equals('ما هي مدة صلاحية الكورس؟'));
    });

    test('3. CMS Repository getPrivacyPolicy() returns bundled legal text without network/Firestore', () async {
      final repo = StudentContentRepositoryImpl();
      final privacy = await repo.getPrivacyPolicy();
      expect(privacy['title'], equals('سياسة الخصوصية والأمان'));
      expect(privacy['content'], contains('حقوق ملكية فكرية'));
      expect(privacy['content'], contains('حذف حسابه بالكامل'));
    });

    test('4. AuthCubit updateProfileInfo() routes to StudentProfileRepository with zero Firestore writes', () async {
      final mockAuthRepo = MockStudentAuthRepository();
      final mockProfileRepo = MockStudentProfileRepository();

      when(() => mockAuthRepo.restoreSession()).thenAnswer((_) async => null);
      when(
        () => mockProfileRepo.updateStudentProfile(
          uid: any(named: 'uid'),
          displayName: any(named: 'displayName'),
          phone: any(named: 'phone'),
          email: any(named: 'email'),
          bio: any(named: 'bio'),
          locale: any(named: 'locale'),
          avatarFilePath: any(named: 'avatarFilePath'),
        ),
      ).thenAnswer((_) async {});

      final cubit = AuthCubit(
        authRepository: mockAuthRepo,
        profileRepository: mockProfileRepo,
      );

      final student = UserModel(
        uid: '101',
        id: 101,
        displayName: 'علي محمد',
        email: 'ali@example.com',
        photoUrl: '',
        phone: '01011112222',
        createdAt: DateTime.now(),
      );

      // Emit authenticated state
      cubit.emit(Authenticated(student));

      await cubit.updateProfileInfo(
        displayName: 'علي محمد المنقح',
        phone: '01033334444',
      );

      expect(cubit.state, isA<Authenticated>());
      final updatedState = cubit.state as Authenticated;
      expect(updatedState.user.displayName, equals('علي محمد المنقح'));
      expect(updatedState.user.phone, equals('01033334444'));

      verify(
        () => mockProfileRepo.updateStudentProfile(
          uid: '101',
          displayName: 'علي محمد المنقح',
          phone: '01033334444',
        ),
      ).called(1);
    });

    test('5. AuthCubit signOut() resets auth state to prevent cross-user leak', () async {
      final mockAuthRepo = MockStudentAuthRepository();
      when(() => mockAuthRepo.restoreSession()).thenAnswer((_) async => null);
      when(() => mockAuthRepo.logout()).thenAnswer((_) async {});

      final cubit = AuthCubit(
        authRepository: mockAuthRepo,
      );

      // Verify signOut emits Unauthenticated
      await cubit.signOut();
      expect(cubit.state, isA<Unauthenticated>());
    });

    test('6. Stale asynchronous restoreSession response arriving after logout is safely ignored', () async {
      final mockAuthRepo = MockStudentAuthRepository();
      final completer = Completer<UserModel?>();

      when(() => mockAuthRepo.restoreSession()).thenAnswer((_) => completer.future);
      when(() => mockAuthRepo.logout()).thenAnswer((_) async {});

      final cubit = AuthCubit(
        authRepository: mockAuthRepo,
      );

      // User immediately clicks logout before restoreSession finishes
      await cubit.signOut();
      expect(cubit.state, isA<Unauthenticated>());

      // Stale network response resolves with old user
      completer.complete(
        UserModel(
          uid: 'old_99',
          displayName: 'طالب قديم',
          email: 'old@example.com',
          photoUrl: '',
          createdAt: DateTime.now(),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 20));

      // Must remain Unauthenticated; must NOT resurrect the old user!
      expect(cubit.state, isA<Unauthenticated>());
    });

    test('7. CoursesCubit has NO dependency on FirestoreService and initializes cleanly', () async {
      final mockCoursesRepo = MockStudentCoursesRepository();
      when(() => mockCoursesRepo.streamCourses()).thenAnswer((_) => const Stream.empty());
      when(() => mockCoursesRepo.getPublicCourses(forceRefresh: any(named: 'forceRefresh'))).thenAnswer((_) async => []);
      when(() => mockCoursesRepo.getCourses()).thenAnswer((_) async => []);

      final cubit = CoursesCubit(
        coursesRepository: mockCoursesRepo,
      );

      expect(cubit.state, isA<CoursesLoading>());
      await Future.delayed(Duration.zero);
      cubit.search('نطق');
      cubit.filterByCategory('تخاطب');
      verify(() => mockCoursesRepo.streamCourses()).called(1);
    });

    test('8. Offline course lookup falls back strictly to local cache with ZERO Firestore requests', () async {
      final mockCoursesRemote = MockCoursesRemoteDataSource();
      final mockCache = MockCourseLocalCache();

      const cachedCourse = Course(
        id: '201',
        slug: 'speech-pathology',
        title: 'علم أمراض النطق والتخاطب',
        description: 'شرح شامل',
        instructor: 'د. الأمين',
        category: 'تخاطب سريري',
        thumbnailUrl: '',
        levels: [],
        price: 500,
      );

      // Remote throws network timeout
      when(() => mockCoursesRemote.getPublicCourses()).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/public/courses'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      // Local cache returns cached courses
      when(() => mockCache.getPublicCourses()).thenAnswer((_) async => [cachedCourse]);

      final repo = StudentCoursesRepositoryImpl(
        remoteDataSource: mockCoursesRemote,
        localCache: mockCache,
      );

      final courses = await repo.getPublicCourses();
      expect(courses.length, equals(1));
      expect(courses.first.slug, equals('speech-pathology'));
      verify(() => mockCache.getPublicCourses()).called(1);
    });

    test('9. AuthCubit deleteAccount() clears session and local caches cleanly', () async {
      final mockAuthRepo = MockStudentAuthRepository();
      final mockProfileRepo = MockStudentProfileRepository();

      when(() => mockAuthRepo.restoreSession()).thenAnswer((_) async => UserModel(
        uid: 'user_404',
        displayName: 'طالب مغادر',
        email: 'leave@alameen.com',
        photoUrl: '',
        createdAt: DateTime.now(),
      ));
      when(() => mockProfileRepo.deleteStudentAccount('user_404', currentPassword: any(named: 'currentPassword'))).thenAnswer((_) async {});
      when(() => mockAuthRepo.logout()).thenAnswer((_) async {});

      final cubit = AuthCubit(
        authRepository: mockAuthRepo,
        profileRepository: mockProfileRepo,
      );

      await Future.delayed(Duration.zero);
      expect(cubit.state, isA<Authenticated>());

      await cubit.deleteAccount(password: 'secret');
      expect(cubit.state, isA<Unauthenticated>());
      verify(() => mockProfileRepo.deleteStudentAccount('user_404', currentPassword: 'secret')).called(1);
      verify(() => mockAuthRepo.logout()).called(1);
    });
  });

  group('P3 CMS Screen Widget Rendering without Firestore Tests', () {
    testWidgets('AboutUsScreen renders verified content without Firestore', (tester) async {
      final mockContentRepo = MockStudentContentRepository();
      when(() => mockContentRepo.getAboutUs()).thenAnswer(
        (_) async => {
          'title': 'مركز الأمين الدولي',
          'content': 'مرحباً بكم في الصرح التدريبي الرائد.',
        },
      );

      if (sl.isRegistered<StudentContentRepository>()) {
        sl.unregister<StudentContentRepository>();
      }
      sl.registerSingleton<StudentContentRepository>(mockContentRepo);

      await tester.pumpWidget(
        const MaterialApp(
          home: AboutUsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('من نحن'), findsOneWidget);
      expect(find.text('مركز الأمين الدولي'), findsOneWidget);
      expect(find.text('مرحباً بكم في الصرح التدريبي الرائد.'), findsOneWidget);
    });

    testWidgets('FaqsScreen renders FAQ items without Firestore', (tester) async {
      final mockContentRepo = MockStudentContentRepository();
      when(() => mockContentRepo.getFaqs()).thenAnswer(
        (_) async => [
          {
            'question': 'هل الشهادة معتمدة من سنتر الأمين؟',
            'answer': 'نعم، معتمدة وموثقة برقم كودي.',
          },
        ],
      );

      if (sl.isRegistered<StudentContentRepository>()) {
        sl.unregister<StudentContentRepository>();
      }
      sl.registerSingleton<StudentContentRepository>(mockContentRepo);

      await tester.pumpWidget(
        const MaterialApp(
          home: FaqsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الأسئلة الشائعة'), findsOneWidget);
      expect(find.text('هل الشهادة معتمدة من سنتر الأمين؟'), findsOneWidget);
    });

    testWidgets('PrivacyPolicyScreen renders verified legal text without Firestore', (tester) async {
      final mockContentRepo = MockStudentContentRepository();
      when(() => mockContentRepo.getPrivacyPolicy()).thenAnswer(
        (_) async => {
          'title': 'سياسة الخصوصية وحماية البيانات',
          'content': 'حماية تامة للبيانات وحقوق الملكية الفكرية.',
        },
      );

      if (sl.isRegistered<StudentContentRepository>()) {
        sl.unregister<StudentContentRepository>();
      }
      sl.registerSingleton<StudentContentRepository>(mockContentRepo);

      await tester.pumpWidget(
        const MaterialApp(
          home: PrivacyPolicyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('سياسة الخصوصية'), findsOneWidget);
      expect(find.text('سياسة الخصوصية وحماية البيانات'), findsOneWidget);
      expect(find.text('حماية تامة للبيانات وحقوق الملكية الفكرية.'), findsOneWidget);
    });

    testWidgets('SecurityProtectionWatcher routes violation to Laravel /student/security/violation for Laravel students', (tester) async {
      final key = GlobalKey<SecurityProtectionWatcherState>();
      final mockApiClient = MockApiClient();

      when(() => mockApiClient.post(
        '/student/security/violation',
        data: any(named: 'data'),
      )).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: '/student/security/violation'),
        statusCode: 200,
        data: {'success': true, 'logged': true},
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: SecurityProtectionWatcher(
            key: key,
            studentId: '101',
            studentEmail: 'laravel_student@alameen.com',
            apiClient: mockApiClient,
            child: const Scaffold(body: Text('محتوى محمي')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('محتوى محمي'), findsOneWidget);

      await key.currentState?.reportSecurityViolationForTesting('screenshot_attempt');

      verify(() => mockApiClient.post(
        '/student/security/violation',
        data: any(
          named: 'data',
          that: isA<Map<String, dynamic>>()
              .having((m) => m['type'], 'type', 'screenshot_attempt')
              .having((m) => m['details'], 'details', contains('platform:'))
              .having((m) => m['details'], 'details', isNot(contains('@'))),
        ),
      )).called(1);
    });
  });
}

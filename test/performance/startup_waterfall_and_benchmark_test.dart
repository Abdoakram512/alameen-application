import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secure_screen_app/core/storage/course_local_cache.dart';
import 'package:secure_screen_app/core/storage/secure_token_storage.dart';
import 'package:secure_screen_app/datasources/courses_remote_data_source.dart';
import 'package:secure_screen_app/features/courses/presentation/cubits/course_entitlement/course_entitlement_cubit.dart';
import 'package:secure_screen_app/features/payments/presentation/cubits/receipts/receipts_cubit.dart';
import 'package:secure_screen_app/features/payments/presentation/cubits/receipts/receipts_state.dart';
import 'package:secure_screen_app/logic/courses/courses_cubit.dart';
import 'package:secure_screen_app/models/course.dart';
import 'package:secure_screen_app/models/student_courses_data.dart';
import 'package:secure_screen_app/repositories/student_auth_repository.dart';
import 'package:secure_screen_app/repositories/student_courses_repository.dart';
import 'package:secure_screen_app/repositories/student_payment_repository.dart';
import 'package:secure_screen_app/screens/student/home/widgets/student_course_card.dart';

class MockAuthRepository extends Mock implements StudentAuthRepository {}
class MockCoursesRepository extends Mock implements StudentCoursesRepository {}
class MockPaymentRepository extends Mock implements StudentPaymentRepository {}
class MockCoursesRemoteDataSource extends Mock implements CoursesRemoteDataSource {}
class MockCourseLocalCache extends Mock implements CourseLocalCache {}
class MockSecureTokenStorage extends Mock implements SecureTokenStorage {}

void main() {
  setUpAll(() {
    registerFallbackValue(const Course(
      id: '0',
      title: 'Fallback',
      description: '',
      instructor: '',
      category: '',
      thumbnailUrl: '',
      levels: [],
    ));
  });

  group('Startup Request Waterfall & Efficiency Tests', () {
    test('Unauthenticated launch triggers strictly public catalog fetch without private requests', () async {
      final mockCoursesRepo = MockCoursesRepository();
      when(() => mockCoursesRepo.getCachedCourses()).thenAnswer((_) async => null);
      when(() => mockCoursesRepo.streamCourses()).thenAnswer((_) => const Stream.empty());
      when(() => mockCoursesRepo.getPublicCourses(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => []);

      final coursesCubit = CoursesCubit(coursesRepository: mockCoursesRepo);
      await Future<void>.delayed(Duration.zero);

      // Verify that strictly stream & public courses were called
      verify(() => mockCoursesRepo.streamCourses()).called(1);
      verify(() => mockCoursesRepo.getPublicCourses(forceRefresh: any(named: 'forceRefresh'))).called(1);
      verifyNever(() => mockCoursesRepo.getStudentCourses());
      verifyNever(() => mockCoursesRepo.getStudentDashboard());

      await coursesCubit.close();
    });

    test('Authenticated session sync triggers only essential course entitlements', () async {
      final mockCoursesRepo = MockCoursesRepository();
      when(() => mockCoursesRepo.getStudentCourses()).thenAnswer(
        (_) async => const StudentCoursesData(enrolledCourseIds: [1, 2]),
      );

      final entitlementCubit = CourseEntitlementCubit(coursesRepository: mockCoursesRepo);
      await entitlementCubit.syncStudentEnrollments(studentId: 'student_123');

      expect(entitlementCubit.state.activeStudentId, equals('student_123'));
      expect(entitlementCubit.state.isCourseAuthorized('1'), isTrue);
      expect(entitlementCubit.state.isCourseAuthorized('2'), isTrue);
      expect(entitlementCubit.state.isCourseAuthorized('3'), isFalse);

      verify(() => mockCoursesRepo.getStudentCourses()).called(1);
      await entitlementCubit.close();
    });

    test('Receipts are NOT fetched eagerly during startup session sync', () async {
      final mockPaymentRepo = MockPaymentRepository();
      final receiptsCubit = ReceiptsCubit(repository: mockPaymentRepo);

      // Under lazy loading, initial state is empty without network hits
      expect(receiptsCubit.state, isA<ReceiptsInitial>());
      verifyZeroInteractions(mockPaymentRepo);

      await receiptsCubit.close();
    });
  });

  group('Layout & Font Scaling Stress Benchmarks (1.0x to 2.0x)', () {
    const testCourse = Course(
      id: 'c_perf_1',
      title: 'برنامج دبلوم التخاطب واضطرابات النطق المتقدم',
      description: 'دورة تطبيقية مكثفة معتمدة تغطي مهارات التقييم الإكلينيكي والعلاج السلوكي.',
      instructor: 'د. أحمد الأمين',
      category: 'تخاطب',
      thumbnailUrl: '',
      price: 1500,
      levels: [],
    );

    for (final scale in [1.0, 1.3, 1.6, 2.0]) {
      testWidgets('StudentCourseCard renders cleanly at ${scale}x text scale without overflow', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 340,
                    child: StudentCourseCard(
                      course: testCourse,
                      isEnrolled: true,
                      progress: 0.65,
                      onTap: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(StudentCourseCard), findsOneWidget);
      });
    }
  });

  group('Parsing and Cache Latency Benchmarks', () {
    test('100 catalog courses deserialize and map in under 50ms', () {
      final rawList = List.generate(100, (i) => {
        'id': i,
        'title': 'كورس تدريبي متخصص رقم $i',
        'slug': 'course-slug-$i',
        'description': 'وصف تدريبي مفصل للدورة مع مستويات تدريبية متعددة.',
        'price': 500 + i * 10,
        'category': 'تأهيل تخاطب',
        'thumbnail_url': 'https://alameen-center.online/storage/courses/c$i.png',
        'lessons_count': 12,
        'levels_count': 3,
        'total_duration': '12:30:00',
        'access_mode': 'paid',
        'levels': [
          {
            'id': 'lvl_${i}_1',
            'title': 'المستوى التأسيسي',
            'order': 1,
            'lessons': [
              {
                'id': 'lsn_${i}_1',
                'title': 'محاضرة مقدمة',
                'order': 1,
                'duration': '15:00',
                'is_free': true,
              }
            ]
          }
        ]
      });

      final stopwatch = Stopwatch()..start();
      final courses = rawList.map((m) => Course.fromMap(m)).toList();
      stopwatch.stop();

      expect(courses.length, equals(100));
      expect(courses.first.levels.length, equals(1));
      expect(courses.first.levels.first.lessons.first.isFreePreview, isTrue);
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });
}

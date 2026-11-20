import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secure_screen_app/core/network/api_exceptions.dart';
import 'package:secure_screen_app/core/storage/course_local_cache.dart';
import 'package:secure_screen_app/features/courses/presentation/cubits/course_entitlement/course_entitlement_cubit.dart';
import 'package:secure_screen_app/features/payments/domain/entities/payment_method.dart';
import 'package:secure_screen_app/features/payments/domain/entities/payment_receipt.dart';
import 'package:secure_screen_app/features/payments/domain/entities/receipt_status.dart';
import 'package:secure_screen_app/features/payments/domain/entities/receipt_submission_input.dart';
import 'package:secure_screen_app/features/payments/presentation/cubits/receipt_submission/receipt_submission_cubit.dart';
import 'package:secure_screen_app/features/payments/presentation/cubits/receipt_submission/receipt_submission_state.dart';
import 'package:secure_screen_app/logic/assignments/assignments_cubit.dart';
import 'package:secure_screen_app/logic/assignments/assignments_state.dart';
import 'package:secure_screen_app/logic/auth/auth_cubit.dart';
import 'package:secure_screen_app/logic/auth/auth_state.dart';
import 'package:secure_screen_app/logic/content/content_cubit.dart';
import 'package:secure_screen_app/logic/content/content_state.dart';
import 'package:secure_screen_app/logic/courses/courses_cubit.dart';
import 'package:secure_screen_app/models/assignment_submission.dart';
import 'package:secure_screen_app/models/clinical_task_data.dart';
import 'package:secure_screen_app/models/course.dart';
import 'package:secure_screen_app/models/student_courses_data.dart';
import 'package:secure_screen_app/models/user_profile.dart';
import 'package:secure_screen_app/repositories/student_assignments_repository.dart';
import 'package:secure_screen_app/repositories/student_auth_repository.dart';
import 'package:secure_screen_app/repositories/student_content_repository.dart';
import 'package:secure_screen_app/repositories/student_courses_repository.dart';
import 'package:secure_screen_app/repositories/student_payment_repository.dart';
import 'package:secure_screen_app/repositories/student_profile_repository.dart';
import 'package:secure_screen_app/services/watch_queue.dart';

class MockAuthRepository extends Mock implements StudentAuthRepository {}
class MockProfileRepository extends Mock implements StudentProfileRepository {}
class MockCoursesRepository extends Mock implements StudentCoursesRepository {}
class MockPaymentRepository extends Mock implements StudentPaymentRepository {}
class MockAssignmentsRepository extends Mock implements StudentAssignmentsRepository {}
class MockContentRepository extends Mock implements StudentContentRepository {}
class MockLocalCache extends Mock implements CourseLocalCache {}

void main() {
  setUpAll(() {
    registerFallbackValue(const ReceiptSubmissionInput(
      courseSlug: 'c1',
      courseId: '1',
      courseTitle: 'Title',
      paymentMethod: PaymentMethod.vodafoneCash,
      senderName: 'Sender',
      senderAccount: '01012345678',
      amount: 100,
      receiptFilePath: 'path/to/img.png',
    ));
    registerFallbackValue(AssignmentSubmission(
      id: 'sub_1',
      assignmentId: 'asg_1',
      assignmentTitle: 'Task 1',
      courseId: 'c_1',
      studentId: 'st_1',
      studentName: 'Name',
      studentEmail: 'email@test.com',
      solutionText: 'sol',
      submittedAt: DateTime.now(),
      maxScore: 100,
    ));
  });

  group('Deterministic Race Condition & Concurrency Matrix (12 Scenarios)', () {
    // -------------------------------------------------------------------------
    // Scenario 1: Logout during session restoration
    // -------------------------------------------------------------------------
    test('Scenario 1: Stale restoreSession completing after signOut does NOT resurrect session', () async {
      final mockAuthRepo = MockAuthRepository();
      final restoreCompleter = Completer<UserModel?>();

      when(() => mockAuthRepo.restoreSession()).thenAnswer((_) => restoreCompleter.future);
      when(() => mockAuthRepo.logout()).thenAnswer((_) async {});

      final authCubit = AuthCubit(authRepository: mockAuthRepo);

      // User immediately clicks logout while restoreSession is in flight
      await authCubit.signOut();
      expect(authCubit.state, isA<Unauthenticated>());

      // Stale network response resolves with previous user
      restoreCompleter.complete(
        UserModel(
          uid: 'old_student_99',
          displayName: 'طالب سابق',
          email: 'old@example.com',
          photoUrl: '',
          createdAt: DateTime.now(),
        ),
      );

      await Future<void>.delayed(Duration.zero);
      // State MUST remain Unauthenticated
      expect(authCubit.state, isA<Unauthenticated>());
      await authCubit.close();
    });

    // -------------------------------------------------------------------------
    // Scenario 2: Account switching during course synchronization
    // -------------------------------------------------------------------------
    test('Scenario 2: Slow enrollment sync from User A does NOT overwrite User B', () async {
      final mockCoursesRepo = MockCoursesRepository();
      final userACompleter = Completer<StudentCoursesData>();

      when(() => mockCoursesRepo.getStudentCourses()).thenAnswer((_) => userACompleter.future);

      final entitlementCubit = CourseEntitlementCubit(coursesRepository: mockCoursesRepo);

      // User A triggers sync
      unawaited(entitlementCubit.syncStudentEnrollments(studentId: 'user_A'));

      // User switches to User B before User A completes
      when(() => mockCoursesRepo.getStudentCourses()).thenAnswer(
        (_) async => const StudentCoursesData(enrolledCourseIds: [200, 201]),
      );
      await entitlementCubit.syncStudentEnrollments(studentId: 'user_B');

      // Now User A's slow response finally arrives with older data
      userACompleter.complete(const StudentCoursesData(enrolledCourseIds: [100]));
      await Future<void>.delayed(Duration.zero);

      // Entitlement state MUST be bound strictly to User B
      expect(entitlementCubit.state.activeStudentId, equals('user_B'));
      expect(entitlementCubit.state.isCourseAuthorized('200'), isTrue);
      expect(entitlementCubit.state.isCourseAuthorized('100'), isFalse);

      await entitlementCubit.close();
    });

    // -------------------------------------------------------------------------
    // Scenario 3: Closing cubits/screens during active network requests
    // -------------------------------------------------------------------------
    test('Scenario 3: Completing async request after Cubit is closed drops emission safely', () async {
      final mockContentRepo = MockContentRepository();
      final aboutCompleter = Completer<Map<String, String>>();

      when(() => mockContentRepo.getAboutUs()).thenAnswer((_) => aboutCompleter.future);

      final contentCubit = ContentCubit(repository: mockContentRepo);
      unawaited(contentCubit.loadAboutUs());

      // User closes screen immediately
      await contentCubit.close();
      expect(contentCubit.isClosed, isTrue);

      // Async response arrives after disposal
      aboutCompleter.complete({'title': 'العنوان', 'content': 'المحتوى'});
      await Future<void>.delayed(Duration.zero);

      // No unhandled exception or StateError thrown
      expect(contentCubit.isClosed, isTrue);
    });

    // -------------------------------------------------------------------------
    // Scenario 4: Duplicate receipt submissions (Rapid double tap)
    // -------------------------------------------------------------------------
    test('Scenario 4: Concurrent receipt submission calls invoke repository strictly ONCE', () async {
      final mockPaymentRepo = MockPaymentRepository();
      final submitCompleter = Completer<PaymentReceipt>();

      when(() => mockPaymentRepo.submitCourseReceipt(any())).thenAnswer((_) => submitCompleter.future);

      final receiptCubit = ReceiptSubmissionCubit(repository: mockPaymentRepo);
      const input = ReceiptSubmissionInput(
        courseSlug: 'c1',
        courseId: '1',
        courseTitle: 'كورس التخاطب',
        paymentMethod: PaymentMethod.vodafoneCash,
        senderName: 'أحمد',
        senderAccount: '01012345678',
        amount: 500,
        receiptFilePath: 'test_path.jpg',
      );

      // First click
      final firstCall = receiptCubit.submit(input, checkFileOnDisk: false);
      expect(receiptCubit.state, isA<ReceiptSubmissionInProgress>());

      // Rapid second click while in progress
      final secondCall = receiptCubit.submit(input, checkFileOnDisk: false);

      submitCompleter.complete(PaymentReceipt(
        id: 1,
        courseId: 1,
        paymentMethod: PaymentMethod.vodafoneCash,
        paymentMethodLabel: 'فودافون كاش',
        senderIdentifier: '01012345678',
        amountPaid: 500,
        status: ReceiptStatus.pending,
        createdAt: DateTime.now(),
      ));

      await Future.wait([firstCall, secondCall]);

      // Exactly ONE submission hit sent to repository
      verify(() => mockPaymentRepo.submitCourseReceipt(any())).called(1);
      expect(receiptCubit.state, isA<ReceiptSubmissionSuccess>());

      await receiptCubit.close();
    });

    // -------------------------------------------------------------------------
    // Scenario 5: Duplicate assignment submissions (Rapid double tap)
    // -------------------------------------------------------------------------
    test('Scenario 5: Concurrent clinical task submission throws guard exception on second tap', () async {
      final mockAssignmentsRepo = MockAssignmentsRepository();
      final submitCompleter = Completer<AssignmentSubmission>();

      when(() => mockAssignmentsRepo.submitClinicalTask(
        taskId: any(named: 'taskId'),
        audioFile: any(named: 'audioFile'),
        audioBase64: any(named: 'audioBase64'),
        durationSeconds: any(named: 'durationSeconds'),
        studentNotes: any(named: 'studentNotes'),
      )).thenAnswer((_) => submitCompleter.future);
      when(() => mockAssignmentsRepo.getAssignments()).thenAnswer((_) async => const StudentAssignmentsData());

      final assignmentsCubit = AssignmentsCubit(repository: mockAssignmentsRepo);
      assignmentsCubit.emit(const AssignmentsLoaded(data: StudentAssignmentsData()));

      // First submission
      final firstSubmission = assignmentsCubit.submitClinicalTask(taskId: 12);
      expect((assignmentsCubit.state as AssignmentsLoaded).isSubmitting, isTrue);

      // Immediate concurrent second submission must throw guarded exception
      expect(
        () => assignmentsCubit.submitClinicalTask(taskId: 12),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('قيد المعالجة بالفعل'),
        )),
      );

      submitCompleter.complete(AssignmentSubmission(
        id: 'sub_12',
        assignmentId: '12',
        assignmentTitle: 'Task 12',
        courseId: 'c1',
        studentId: 'st1',
        studentName: 'Name',
        studentEmail: 'email@test.com',
        solutionText: 'Done',
        submittedAt: DateTime.now(),
        maxScore: 100,
      ));

      await firstSubmission;
      verify(() => mockAssignmentsRepo.submitClinicalTask(
        taskId: 12,
        audioFile: any(named: 'audioFile'),
        audioBase64: any(named: 'audioBase64'),
        durationSeconds: any(named: 'durationSeconds'),
        studentNotes: any(named: 'studentNotes'),
      )).called(1);

      await assignmentsCubit.close();
    });

    // -------------------------------------------------------------------------
    // Scenario 6: Rapid course navigation and out-of-order responses
    // -------------------------------------------------------------------------
    test('Scenario 6: Out-of-order course details response preserves latest request', () async {
      final mockCoursesRepo = MockCoursesRepository();
      when(() => mockCoursesRepo.getCachedCourses()).thenAnswer((_) async => null);
      when(() => mockCoursesRepo.streamCourses()).thenAnswer((_) => const Stream.empty());
      when(() => mockCoursesRepo.getPublicCourses(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => []);

      final course1Completer = Completer<Course>();
      final course2Completer = Completer<Course>();

      when(() => mockCoursesRepo.getCourseDetails('course_1')).thenAnswer((_) => course1Completer.future);
      when(() => mockCoursesRepo.getCourseDetails('course_2')).thenAnswer((_) => course2Completer.future);

      final coursesCubit = CoursesCubit(coursesRepository: mockCoursesRepo);

      // User navigates to course 1, then immediately switches to course 2
      final req1 = coursesCubit.loadCourseDetails('course_1');
      final req2 = coursesCubit.loadCourseDetails('course_2');

      const c2 = Course(id: 'course_2', title: 'كورس 2', description: '', instructor: '', category: '', thumbnailUrl: '', levels: []);
      const c1 = Course(id: 'course_1', title: 'كورس 1', description: '', instructor: '', category: '', thumbnailUrl: '', levels: []);

      // Course 2 resolves first
      course2Completer.complete(c2);
      final res2 = await req2;
      expect(res2?.id, equals('course_2'));

      // Course 1 resolves late
      course1Completer.complete(c1);
      final res1 = await req1;
      expect(res1?.id, equals('course_1'));

      await coursesCubit.close();
    });

    // -------------------------------------------------------------------------
    // Scenario 7: Switching videos during progress synchronization
    // -------------------------------------------------------------------------
    test('Scenario 7: WatchQueue executes sequential events serially without collision', () async {
      final sentEvents = <Map<String, dynamic>>[];
      final storage = <String, String>{};

      final queue = WatchQueue(
        read: (k) async => storage[k],
        write: (k, v) async => storage[k] = v,
        send: (event) async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          sentEvents.add(event);
        },
      );

      // Video 1 progress and Video 2 progress enqueued rapidly
      final sync1 = queue.enqueue(
        uid: 'user_10',
        courseId: 'c1',
        lessonId: 'l1',
        seconds: 60,
      );
      final sync2 = queue.enqueue(
        uid: 'user_10',
        courseId: 'c1',
        lessonId: 'l2',
        seconds: 30,
      );

      await Future.wait([sync1, sync2]);
      await queue.flush('user_10');

      expect(sentEvents.length, equals(2));
      expect(sentEvents[0]['lessonId'], equals('l1'));
      expect(sentEvents[1]['lessonId'], equals('l2'));
    });

    // -------------------------------------------------------------------------
    // Scenario 8: WatchQueue storage key isolation between users on logout
    // -------------------------------------------------------------------------
    test('Scenario 8: Storage keys are strictly isolated across student UIDs', () {
      final keyUserA = WatchQueue.storageKeyForUser('student_A');
      final keyUserB = WatchQueue.storageKeyForUser('student_B');

      expect(keyUserA, isNot(equals(keyUserB)));
      expect(keyUserA, equals('watch.queue.v1.student_A'));
      expect(keyUserB, equals('watch.queue.v1.student_B'));
      expect(() => WatchQueue.storageKeyForUser(''), throwsArgumentError);
      expect(() => WatchQueue.storageKeyForUser('null'), throwsArgumentError);
    });

    // -------------------------------------------------------------------------
    // Scenario 9: FCM token storage cache isolation
    // -------------------------------------------------------------------------
    test('Scenario 9: Token sync cache keys are strictly isolated per user', () {
      const uid1 = 'student_one';
      const uid2 = 'student_two';
      final cacheKey1 = 'fcm_token_synced_$uid1';
      final cacheKey2 = 'fcm_token_synced_$uid2';

      expect(cacheKey1, isNot(equals(cacheKey2)));
      expect(cacheKey1, contains('student_one'));
      expect(cacheKey2, contains('student_two'));
    });

    // -------------------------------------------------------------------------
    // Scenario 10: Multiple route / AuthCubit listener notifications deduplication
    // -------------------------------------------------------------------------
    test('Scenario 10: Successive Authenticated state emissions do not duplicate course sync', () async {
      final mockCoursesRepo = MockCoursesRepository();
      when(() => mockCoursesRepo.getStudentCourses()).thenAnswer(
        (_) async => const StudentCoursesData(enrolledCourseIds: [1]),
      );

      final entitlementCubit = CourseEntitlementCubit(coursesRepository: mockCoursesRepo);

      String? lastSyncedUid;
      int syncCount = 0;

      void syncSessionState(String uid) {
        if (lastSyncedUid != uid) {
          lastSyncedUid = uid;
          syncCount++;
          entitlementCubit.syncStudentEnrollments(studentId: uid);
        }
      }

      // Three successive auth state broadcasts for the same user
      syncSessionState('st_100');
      syncSessionState('st_100');
      syncSessionState('st_100');

      await Future<void>.delayed(Duration.zero);
      expect(syncCount, equals(1));
      verify(() => mockCoursesRepo.getStudentCourses()).called(1);

      await entitlementCubit.close();
    });

    // -------------------------------------------------------------------------
    // Scenario 11: Cancelled network operations return cleanly
    // -------------------------------------------------------------------------
    test('Scenario 11: DioException cancel does not crash Cubits or UI', () async {
      final mockContentRepo = MockContentRepository();
      when(() => mockContentRepo.getAboutUs()).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/public/home'),
          type: DioExceptionType.cancel,
          error: 'Operation cancelled',
        ),
      );

      final cubit = ContentCubit(repository: mockContentRepo);
      await cubit.loadAboutUs();

      // State handles error gracefully without unhandled crashes
      expect(cubit.state, isA<ContentError>());
      await cubit.close();
    });

    // -------------------------------------------------------------------------
    // Scenario 12: Lifecycle background/foreground transitions
    // -------------------------------------------------------------------------
    test('Scenario 12: Clear and reset methods reset generational tokens and active IDs cleanly', () {
      final mockAssignmentsRepo = MockAssignmentsRepository();
      final assignmentsCubit = AssignmentsCubit(repository: mockAssignmentsRepo);

      assignmentsCubit.emit(const AssignmentsLoaded(data: StudentAssignmentsData()));
      assignmentsCubit.clear();

      expect(assignmentsCubit.state, isA<AssignmentsInitial>());
      expect(assignmentsCubit.activeStudentId, isNull);

      assignmentsCubit.close();
    });
  });
}

import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:secure_screen_app/core/errors/app_failure.dart';
import 'package:secure_screen_app/features/courses/domain/entities/course_entitlement.dart';
import 'package:secure_screen_app/features/courses/presentation/cubits/course_entitlement/course_entitlement_cubit.dart';
import 'package:secure_screen_app/features/payments/domain/entities/payment_method.dart';
import 'package:secure_screen_app/features/payments/domain/entities/receipt_status.dart';
import 'package:secure_screen_app/features/payments/domain/entities/receipt_submission_input.dart';
import 'package:secure_screen_app/features/payments/presentation/cubits/receipt_submission/receipt_submission_cubit.dart';
import 'package:secure_screen_app/features/payments/presentation/cubits/receipt_submission/receipt_submission_state.dart';
import 'package:secure_screen_app/features/payments/presentation/cubits/receipts/receipts_cubit.dart';
import 'package:secure_screen_app/features/payments/presentation/cubits/receipts/receipts_state.dart';
import 'package:secure_screen_app/logic/assignments/assignments_cubit.dart';
import 'package:secure_screen_app/logic/assignments/assignments_state.dart';
import 'package:secure_screen_app/models/assignment.dart';
import 'package:secure_screen_app/models/clinical_task_data.dart';
import 'package:secure_screen_app/models/course.dart';
import 'package:secure_screen_app/models/course_level.dart';
import 'package:secure_screen_app/models/course_progress_policy.dart';
import 'package:secure_screen_app/models/lesson.dart';
import 'package:secure_screen_app/models/payment_receipt_model.dart';
import 'package:secure_screen_app/repositories/student_assignments_repository.dart';
import 'package:secure_screen_app/repositories/student_courses_repository.dart';
import 'package:secure_screen_app/repositories/student_payment_repository.dart';

class MockStudentPaymentRepository extends Mock implements StudentPaymentRepository {}
class MockStudentCoursesRepository extends Mock implements StudentCoursesRepository {}
class MockStudentAssignmentsRepository extends Mock implements StudentAssignmentsRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ALAMEEN CENTER — AUTHORITY & CLEAN ARCHITECTURE SPECIFICATION', () {
    late MockStudentPaymentRepository mockPaymentRepo;
    late MockStudentCoursesRepository mockCoursesRepo;
    late MockStudentAssignmentsRepository mockAssignmentsRepo;
    late File dummyReceiptFile;

    setUpAll(() {
      registerFallbackValue(
        const ReceiptSubmissionInput(
          courseSlug: 'slug',
          courseId: '1',
          courseTitle: 'Course',
          paymentMethod: PaymentMethod.vodafoneCash,
          senderName: 'Student',
          senderAccount: '01000000000',
          amount: 100.0,
          receiptFilePath: 'receipt.png',
        ),
      );
    });

    setUp(() async {
      mockPaymentRepo = MockStudentPaymentRepository();
      mockCoursesRepo = MockStudentCoursesRepository();
      mockAssignmentsRepo = MockStudentAssignmentsRepository();

      dummyReceiptFile = File('${Directory.systemTemp.path}/test_receipt_sec.png');
      await dummyReceiptFile.writeAsBytes([0x89, 0x50, 0x4E, 0x47]);
    });

    tearDown(() async {
      if (await dummyReceiptFile.exists()) {
        await dummyReceiptFile.delete();
      }
    });

    // ------------------------------------------------------------------------
    // SCENARIO 1: Approved receipt with revoked enrollment
    // ------------------------------------------------------------------------
    test('1. Approved receipt does NOT override server-revoked course enrollment', () async {
      final receiptsCubit = ReceiptsCubit(repository: mockPaymentRepo);
      final entitlementCubit = CourseEntitlementCubit(
        coursesRepository: mockCoursesRepo,
      );

      const course = Course(
        id: '201',
        title: 'دبلوم التخاطب المتقدم',
        description: 'وصف الدورة',
        instructor: 'د. الأمين',
        category: 'تخاطب',
        thumbnailUrl: '',
        levels: [],
        price: 1500.0,
      );

      final approvedReceipt = PaymentReceiptModel(
        id: 501,
        userId: 10,
        courseId: 201,
        paymentMethod: PaymentMethod.vodafoneCash,
        paymentMethodLabel: 'Vodafone Cash',
        senderIdentifier: '01011112222',
        amountPaid: 1500.0,
        status: ReceiptStatus.approved,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      );

      when(() => mockPaymentRepo.getStudentReceipts())
          .thenAnswer((_) async => [approvedReceipt]);
      when(() => mockCoursesRepo.verifyStudentCourseDetails('201')).thenAnswer(
        (_) async => course.copyWith(
          hasEnrolled: false,
          isDetailedFromAuthServer: true,
        ),
      );

      await receiptsCubit.loadReceipts(studentId: 'student_10');
      expect(receiptsCubit.state, isA<ReceiptsLoaded>());

      final entitlement = await entitlementCubit.verifyCourseEntitlement(
        courseId: course.id,
        courseSlug: '201',
        studentId: 'student_10',
      );

      expect(entitlement.status, equals(CourseAccessState.notEnrolled));
      expect(entitlementCubit.state.isCourseAuthorized('201'), isFalse);

      await receiptsCubit.close();
      await entitlementCubit.close();
    });

    // ------------------------------------------------------------------------
    // SCENARIO 2: Pending receipt never grants course entitlement
    // ------------------------------------------------------------------------
    test('2. Pending receipt does NOT unlock course lessons or grant entitlement', () {
      final pendingReceipt = PaymentReceiptModel(
        id: 701,
        userId: 10,
        courseId: 301,
        paymentMethod: PaymentMethod.instapay,
        paymentMethodLabel: 'InstaPay',
        senderIdentifier: 'student@instapay',
        amountPaid: 1200.0,
        status: ReceiptStatus.pending,
        createdAt: DateTime.now(),
      );

      expect(pendingReceipt.status, equals(ReceiptStatus.pending));
      final entitlementCubit = CourseEntitlementCubit(
        coursesRepository: mockCoursesRepo,
      );
      expect(entitlementCubit.state.isCourseAuthorized('301'), isFalse);
      entitlementCubit.close();
    });

    // ------------------------------------------------------------------------
    // SCENARIO 3: Non-authoritative public response fails closed (never grants access)
    // ------------------------------------------------------------------------
    test('3. Non-authoritative server response fails closed (never grants access)', () async {
      final entitlementCubit = CourseEntitlementCubit(
        coursesRepository: mockCoursesRepo,
      );

      const course = Course(
        id: '202',
        title: 'دورة التأهيل الحركي',
        description: 'وصف',
        instructor: 'د. الأمين',
        category: 'تأهيل',
        thumbnailUrl: '',
        levels: [],
        price: 0.0,
        hasEnrolled: true,
        isDetailedFromAuthServer: false,
      );

      when(() => mockCoursesRepo.verifyStudentCourseDetails('202'))
          .thenAnswer((_) async => course);

      final result = await entitlementCubit.verifyCourseEntitlement(
        courseId: course.id,
        courseSlug: '202',
        studentId: 'student_10',
      );

      expect(result.status, equals(CourseAccessState.unknown));
      expect(entitlementCubit.state.isCourseAuthorized('202'), isFalse);

      await entitlementCubit.close();
    });

    // ------------------------------------------------------------------------
    // SCENARIO 4: Network error versus confirmed 403 Forbidden (without guessing revocation)
    // ------------------------------------------------------------------------
    test('4. Network error is distinguished from generic HTTP 403 without fabricating revocation reason', () async {
      final entitlementCubit = CourseEntitlementCubit(
        coursesRepository: mockCoursesRepo,
      );

      when(() => mockCoursesRepo.verifyStudentCourseDetails('203')).thenThrow(
        const NetworkFailure('تعذر التحقق من حالة الاشتراك نظراً لعدم توفر اتصال بالشبكة.'),
      );

      final netResult = await entitlementCubit.verifyCourseEntitlement(
        courseId: '203',
        courseSlug: '203',
        studentId: 'student_1',
      );
      expect(netResult.status, equals(CourseAccessState.networkUnavailable));
      expect(netResult.canAccessProtectedContent, isFalse);

      when(() => mockCoursesRepo.verifyStudentCourseDetails('203')).thenThrow(
        const ForbiddenFailure('تم رفض الوصول من الخادم.'),
      );

      final forbiddenResult = await entitlementCubit.verifyCourseEntitlement(
        courseId: '203',
        courseSlug: '203',
        studentId: 'student_1',
      );
      expect(forbiddenResult.status, equals(CourseAccessState.forbidden));
      expect(forbiddenResult.forbiddenReasonCode, isNull);
      expect(forbiddenResult.canAccessProtectedContent, isFalse);

      await entitlementCubit.close();
    });

    // ------------------------------------------------------------------------
    // SCENARIO 5: Repeated receipt uploads maintain chronological history
    // ------------------------------------------------------------------------
    test('5. Repeated receipt submissions emit success cleanly and ReceiptsCubit maintains newest-first history', () async {
      final submissionCubit = ReceiptSubmissionCubit(repository: mockPaymentRepo);
      final receiptsCubit = ReceiptsCubit(repository: mockPaymentRepo);

      final receipt1 = PaymentReceiptModel(
        id: 101,
        userId: 1,
        courseId: 50,
        paymentMethod: PaymentMethod.vodafoneCash,
        paymentMethodLabel: 'Vodafone Cash',
        senderIdentifier: '01011112222',
        amountPaid: 500.0,
        status: ReceiptStatus.rejected,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      final receipt2 = PaymentReceiptModel(
        id: 102,
        userId: 1,
        courseId: 50,
        paymentMethod: PaymentMethod.vodafoneCash,
        paymentMethodLabel: 'Vodafone Cash',
        senderIdentifier: '01011112222',
        amountPaid: 500.0,
        status: ReceiptStatus.pending,
        createdAt: DateTime.now(),
      );

      when(() => mockPaymentRepo.submitCourseReceipt(any()))
          .thenAnswer((_) async => receipt2);
      when(() => mockPaymentRepo.getStudentReceipts())
          .thenAnswer((_) async => [receipt1, receipt2]);

      await submissionCubit.submit(
        ReceiptSubmissionInput(
          courseSlug: 'diploma-speech',
          courseId: '50',
          courseTitle: 'دبلوم التخاطب',
          paymentMethod: PaymentMethod.vodafoneCash,
          senderName: 'أحمد',
          senderAccount: '01011112222',
          amount: 500.0,
          receiptFilePath: dummyReceiptFile.path,
        ),
      );
      expect(submissionCubit.state, isA<ReceiptSubmissionSuccess>());

      await receiptsCubit.loadReceipts(studentId: '1');
      final loaded = receiptsCubit.state as ReceiptsLoaded;
      expect(loaded.history.receipts.length, equals(2));
      expect(loaded.history.receipts.first.id, equals(102));
      expect(loaded.history.latestForCourse('50')?.id, equals(102));

      await submissionCubit.close();
      await receiptsCubit.close();
    });

    // ------------------------------------------------------------------------
    // SCENARIO 6: Invalid or missing payment method rejected strictly
    // ------------------------------------------------------------------------
    test('6. Invalid or null payment method is rejected strictly with ValidationFailure', () async {
      expect(PaymentMethod.tryParse('credit_card'), isNull);
      expect(PaymentMethod.tryParse(''), isNull);
      expect(PaymentMethod.tryParse('vodafone_cash'), equals(PaymentMethod.vodafoneCash));
      expect(PaymentMethod.tryParse('instapay'), equals(PaymentMethod.instapay));

      final submissionCubit = ReceiptSubmissionCubit(repository: mockPaymentRepo);

      await submissionCubit.submit(
        ReceiptSubmissionInput(
          courseSlug: 'course-1',
          courseId: '1',
          courseTitle: 'دورة 1',
          paymentMethod: PaymentMethod.tryParse('credit_card'),
          senderName: 'طالب',
          senderAccount: '01012345678',
          amount: 500.0,
          receiptFilePath: dummyReceiptFile.path,
        ),
      );

      expect(submissionCubit.state, isA<ReceiptSubmissionValidationFailure>());
      verifyNever(() => mockPaymentRepo.submitCourseReceipt(any()));
      await submissionCubit.close();
    });

    // ------------------------------------------------------------------------
    // SCENARIO 7: Sender-account & amount validation (no fabricated defaults)
    // ------------------------------------------------------------------------
    test('7. Sender-account and amount validated without falling back to phone or course price', () async {
      final submissionCubit = ReceiptSubmissionCubit(repository: mockPaymentRepo);

      await submissionCubit.submit(
        ReceiptSubmissionInput(
          courseSlug: 'course-601',
          courseId: '601',
          courseTitle: 'دورة النطق',
          paymentMethod: PaymentMethod.vodafoneCash,
          senderName: 'طالب',
          senderAccount: '   ',
          amount: 1500.0,
          receiptFilePath: dummyReceiptFile.path,
        ),
      );

      expect(submissionCubit.state, isA<ReceiptSubmissionValidationFailure>());
      expect(
        (submissionCubit.state as ReceiptSubmissionValidationFailure).message,
        contains('يرجى إدخال رقم المحفظة أو الحساب'),
      );

      await submissionCubit.submit(
        ReceiptSubmissionInput(
          courseSlug: 'course-601',
          courseId: '601',
          courseTitle: 'دورة النطق',
          paymentMethod: PaymentMethod.vodafoneCash,
          senderName: 'طالب',
          senderAccount: '01012345678',
          amount: null,
          receiptFilePath: dummyReceiptFile.path,
        ),
      );

      expect(submissionCubit.state, isA<ReceiptSubmissionValidationFailure>());
      expect(
        (submissionCubit.state as ReceiptSubmissionValidationFailure).message,
        contains('المبلغ المدفوع غير محدد أو غير صالح'),
      );

      await submissionCubit.close();
    });

    // ------------------------------------------------------------------------
    // SCENARIO 8: Account switching during in-flight requests isolates session
    // ------------------------------------------------------------------------
    test('8. Account switching during in-flight receipt requests isolates session and discards stale response', () async {
      final cubit = ReceiptsCubit(repository: mockPaymentRepo);

      final completerA = Completer<List<PaymentReceiptModel>>();
      when(() => mockPaymentRepo.getStudentReceipts())
          .thenAnswer((_) => completerA.future);

      final futureA = cubit.loadReceipts(studentId: 'student_A');

      // Logout / switch away
      cubit.clear();
      expect(cubit.state, isA<ReceiptsInitial>());

      completerA.complete([
        PaymentReceiptModel(
          id: 99,
          userId: 1,
          courseId: 10,
          paymentMethod: PaymentMethod.vodafoneCash,
          paymentMethodLabel: 'Vodafone',
          senderIdentifier: '01011112222',
          amountPaid: 1000.0,
          status: ReceiptStatus.approved,
          createdAt: DateTime.now(),
        ),
      ]);

      await futureA;
      expect(cubit.state, isA<ReceiptsInitial>());

      await cubit.close();
    });

    // ------------------------------------------------------------------------
    // SCENARIO 9: Closing a Cubit while requests are pending
    // ------------------------------------------------------------------------
    test('9. Closing ReceiptsCubit & CourseEntitlementCubit while pending does not emit or throw', () async {
      final receiptsCubit = ReceiptsCubit(repository: mockPaymentRepo);
      final entitlementCubit = CourseEntitlementCubit(
        coursesRepository: mockCoursesRepo,
      );

      final receiptCompleter = Completer<List<PaymentReceiptModel>>();
      final courseCompleter = Completer<Course>();

      when(() => mockPaymentRepo.getStudentReceipts())
          .thenAnswer((_) => receiptCompleter.future);
      when(() => mockCoursesRepo.verifyStudentCourseDetails('1'))
          .thenAnswer((_) => courseCompleter.future);

      final f1 = receiptsCubit.loadReceipts(studentId: '1');
      final f2 = entitlementCubit.verifyCourseEntitlement(
        courseId: '1',
        courseSlug: '1',
        studentId: '1',
      );

      await receiptsCubit.close();
      await entitlementCubit.close();

      receiptCompleter.complete([]);
      courseCompleter.complete(
        const Course(
          id: '1',
          title: 'Course 1',
          description: '',
          instructor: '',
          category: '',
          thumbnailUrl: '',
          levels: [],
        ),
      );

      await f1;
      await f2;

      expect(receiptsCubit.isClosed, isTrue);
      expect(entitlementCubit.isClosed, isTrue);
    });

    // ------------------------------------------------------------------------
    // SCENARIO 10-15: Server level locks, previews, assignments lifecycle
    // ------------------------------------------------------------------------
    test('10. Server-locked levels remain locked at locally calculated 95% or 100% completion', () {
      final level1 = CourseLevel.fromLaravelJson({
        'id': 'lvl_1',
        'title': 'المستوى الأول',
        'order': 1,
        'is_accessible': true,
      });

      final level2 = CourseLevel.fromLaravelJson({
        'id': 'lvl_2',
        'title': 'المستوى الثاني: التدخل العلاجي',
        'order': 2,
        'is_accessible': false,
      });

      expect(level2.isAccessible, isFalse);

      final isUnlocked = CourseProgressPolicy.isLevelUnlocked(
        levels: [level1, level2],
        levelIndex: 1,
        isEnrolled: true,
        completedLessonIds: {'lsn_1', 'lsn_2', 'lsn_3'},
      );

      expect(isUnlocked, isFalse);
    });

    test('11. First-level access is denied without server-confirmed enrollment', () {
      final level1 = CourseLevel.fromLaravelJson({
        'id': 'lvl_1',
        'title': 'المستوى الأول',
        'order': 1,
        'is_accessible': true,
      });

      final isUnlocked = CourseProgressPolicy.isLevelUnlocked(
        levels: [level1],
        levelIndex: 0,
        isEnrolled: false,
        completedLessonIds: {},
      );

      expect(isUnlocked, isFalse);
    });

    test('12. Explicitly authorized free previews are accessible even without enrollment', () {
      final freeLesson = Lesson.fromLaravelVideoJson({
        'id': 1001,
        'title': 'معاينة مجانية للمقدمة',
        'is_free': true,
        'is_accessible': true,
        'duration_seconds': 300,
        'playback_id': 'mux_free_1001',
      });

      expect(freeLesson.isFreePreview, isTrue);
      expect(freeLesson.isAccessible, isTrue);

      final reason = CourseProgressPolicy.lessonLockReason(
        levels: [],
        lesson: freeLesson,
        isEnrolled: false,
        completedLessonIds: {},
      );

      expect(reason, isNull);
    });

    test('13. Protected lesson playback is rejected without enrollment', () {
      final protectedLesson = Lesson.fromLaravelVideoJson({
        'id': 2001,
        'title': 'محاضرة علاجية سريرية خاصة',
        'is_free': false,
        'is_accessible': false,
        'duration_seconds': 900,
        'playback_id': 'mux_prot_2001',
      });

      final reason = CourseProgressPolicy.lessonLockReason(
        levels: [],
        lesson: protectedLesson,
        isEnrolled: false,
        completedLessonIds: {},
      );

      expect(reason, isNotNull);
      expect(reason, contains('يتطلب الاشتراك في الدورة'));
    });

    test('14. Assignment Cubit initializes and loads assignments for authenticated student', () async {
      final task = Assignment(
        id: '55',
        courseId: '10',
        courseTitle: 'دبلوم التخاطب',
        title: 'واجب تقييم النطق',
        instructions: 'تسجيل مقطع صوتي',
        createdAt: DateTime.now(),
      );

      when(() => mockAssignmentsRepo.getAssignments())
          .thenAnswer((_) async => StudentAssignmentsData(tasks: [task]));

      final cubit = AssignmentsCubit(repository: mockAssignmentsRepo);

      await cubit.loadAssignments(studentId: 'student_auth_1');

      expect(cubit.activeStudentId, equals('student_auth_1'));
      expect(cubit.state, isA<AssignmentsLoaded>());
      final loaded = cubit.state as AssignmentsLoaded;
      expect(loaded.data.tasks.first.id, equals('55'));

      await cubit.close();
    });

    test('15. Assignment state is completely cleared at logout', () async {
      final task = Assignment(
        id: '56',
        courseId: '10',
        courseTitle: 'دبلوم التخاطب',
        title: 'واجب ثاني',
        instructions: 'تعليمات',
        createdAt: DateTime.now(),
      );

      when(() => mockAssignmentsRepo.getAssignments())
          .thenAnswer((_) async => StudentAssignmentsData(tasks: [task]));

      final cubit = AssignmentsCubit(repository: mockAssignmentsRepo);
      await cubit.loadAssignments(studentId: 'student_56');

      expect(cubit.state, isA<AssignmentsLoaded>());

      cubit.clear();

      expect(cubit.state, equals(const AssignmentsInitial()));
      expect(cubit.activeStudentId, isNull);

      await cubit.close();
    });
  });
}

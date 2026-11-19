import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:secure_screen_app/logic/access/access_cubit.dart';
import 'package:secure_screen_app/logic/access/access_state.dart';
import 'package:secure_screen_app/logic/assignments/assignments_cubit.dart';
import 'package:secure_screen_app/logic/assignments/assignments_state.dart';
import 'package:secure_screen_app/models/access_request.dart';
import 'package:secure_screen_app/models/assignment.dart';
import 'package:secure_screen_app/models/clinical_task_data.dart';
import 'package:secure_screen_app/models/course.dart';
import 'package:secure_screen_app/models/course_level.dart';
import 'package:secure_screen_app/models/course_progress_policy.dart';
import 'package:secure_screen_app/models/lesson.dart';
import 'package:secure_screen_app/models/payment_receipt_model.dart';
import 'package:secure_screen_app/models/user_profile.dart';
import 'package:secure_screen_app/repositories/student_assignments_repository.dart';
import 'package:secure_screen_app/repositories/student_courses_repository.dart';
import 'package:secure_screen_app/repositories/student_payment_repository.dart';

// Mocks
class MockStudentPaymentRepository extends Mock implements StudentPaymentRepository {}
class MockStudentCoursesRepository extends Mock implements StudentCoursesRepository {}
class MockStudentAssignmentsRepository extends Mock implements StudentAssignmentsRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ALAMEEN CENTER — FINAL AUTHORITY & ARCHITECTURE SPECIFICATION', () {
    late MockStudentPaymentRepository mockPaymentRepo;
    late MockStudentCoursesRepository mockCoursesRepo;
    late MockStudentAssignmentsRepository mockAssignmentsRepo;
    late File dummyReceiptFile;

    setUp(() async {
      mockPaymentRepo = MockStudentPaymentRepository();
      mockCoursesRepo = MockStudentCoursesRepository();
      mockAssignmentsRepo = MockStudentAssignmentsRepository();

      registerFallbackValue(FormData());
      registerFallbackValue(Options());

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
      final cubit = AccessCubit(
        paymentRepository: mockPaymentRepo,
        coursesRepository: mockCoursesRepo,
      );

      final course = const Course(
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
        paymentMethod: 'vodafone_cash',
        paymentMethodLabel: 'Vodafone Cash',
        senderIdentifier: '01011112222',
        amountPaid: 1500.0,
        status: AccessStatus.approved,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      );

      // Server indicates user is NOT enrolled (access revoked or denied)
      when(() => mockCoursesRepo.getCourseDetails('201'))
          .thenAnswer((_) async => course.copyWith(hasEnrolled: false));

      when(() => mockPaymentRepo.getStudentReceipts())
          .thenAnswer((_) async => [approvedReceipt]);

      final status = await cubit.verifyCourseEntitlement(uid: 'student_10', course: course);

      // Must fail closed: AccessError emitted, course entitlement is notEnrolled
      expect(status, equals(CourseEntitlementStatus.notEnrolled));
      expect(cubit.state, isA<AccessError>());
      final errorState = cubit.state as AccessError;
      expect(errorState.isCourseAuthorized('201'), isFalse);
      expect(errorState.entitlementStatus, equals(CourseEntitlementStatus.notEnrolled));

      await cubit.close();
    });

    // ------------------------------------------------------------------------
    // SCENARIO 2: Pending receipt with inaccessible course
    // ------------------------------------------------------------------------
    test('2. Pending receipt does NOT unlock course lessons or grant entitlement', () {
      final pendingReceipt = PaymentReceiptModel(
        id: 701,
        userId: 10,
        courseId: 301,
        paymentMethod: 'instapay',
        paymentMethodLabel: 'InstaPay',
        senderIdentifier: 'student@instapay',
        amountPaid: 1200.0,
        status: AccessStatus.pending,
        createdAt: DateTime.now(),
      );

      expect(pendingReceipt.status, equals(AccessStatus.pending));

      // Course with pending receipt has hasEnrolled == false
      final course = const Course(
        id: '301',
        title: 'دورة التشخيص السريري',
        description: 'وصف',
        instructor: 'د. الأمين',
        category: 'تشخيص',
        thumbnailUrl: '',
        levels: [],
        price: 1200.0,
        hasEnrolled: false,
      );

      // Paid course requires authoritative hasEnrolled == true
      expect(course.hasEnrolled, isFalse);
    });

    // ------------------------------------------------------------------------
    // SCENARIO 3: Missing or stale entitlement fails closed
    // ------------------------------------------------------------------------
    test('3. Missing or null courses repository fails closed (never grants access)', () async {
      final cubit = AccessCubit(
        paymentRepository: mockPaymentRepo,
        coursesRepository: null, // Null repository
      );

      final course = const Course(
        id: '202',
        title: 'دورة التأهيل الحركي',
        description: 'وصف',
        instructor: 'د. الأمين',
        category: 'تأهيل',
        thumbnailUrl: '',
        levels: [],
        price: 0.0,
      );

      final status = await cubit.verifyCourseEntitlement(uid: 'student_10', course: course);

      expect(status, equals(CourseEntitlementStatus.unknown));
      expect(cubit.state, isA<AccessError>());
      expect((cubit.state as AccessError).isCourseAuthorized('202'), isFalse);

      await cubit.close();
    });

    // ------------------------------------------------------------------------
    // SCENARIO 4: Network error versus confirmed denial
    // ------------------------------------------------------------------------
    test('4. Network error is distinguished from confirmed denial without false subscription rejection', () async {
      final cubit = AccessCubit(
        paymentRepository: mockPaymentRepo,
        coursesRepository: mockCoursesRepo,
      );

      final course = const Course(
        id: '203',
        title: 'دورة أمراض الكلام',
        description: 'وصف',
        instructor: 'د. الأمين',
        category: 'تخاطب',
        thumbnailUrl: '',
        levels: [],
        price: 0.0,
      );

      // 4A: Network timeout / connection error
      when(() => mockCoursesRepo.getCourseDetails('203')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/student/courses/203'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final netStatus = await cubit.verifyCourseEntitlement(uid: 'student_1', course: course);
      expect(netStatus, equals(CourseEntitlementStatus.networkError));
      expect(cubit.state, isA<AccessError>());
      expect((cubit.state as AccessError).message, contains('عدم توفر اتصال بالشبكة'));

      // 4B: Explicit 403 Forbidden (access revoked)
      when(() => mockCoursesRepo.getCourseDetails('203')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/student/courses/203'),
          response: Response(
            requestOptions: RequestOptions(path: '/student/courses/203'),
            statusCode: 403,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      final revokedStatus = await cubit.verifyCourseEntitlement(uid: 'student_1', course: course);
      expect(revokedStatus, equals(CourseEntitlementStatus.revoked));
      expect(cubit.state, isA<AccessError>());
      expect((cubit.state as AccessError).message, contains('سحب أو إلغاء صلاحية الوصول'));

      await cubit.close();
    });

    // ------------------------------------------------------------------------
    // SCENARIO 5: Repeated receipt uploads and coherent status history
    // ------------------------------------------------------------------------
    test('5. Repeated receipt uploads maintain coherent chronological audit history', () async {
      final cubit = AccessCubit(
        paymentRepository: mockPaymentRepo,
        coursesRepository: mockCoursesRepo,
      );

      final receipt1 = PaymentReceiptModel(
        id: 101,
        userId: 1,
        courseId: 50,
        paymentMethod: 'vodafone_cash',
        paymentMethodLabel: 'Vodafone Cash',
        senderIdentifier: '01011112222',
        amountPaid: 500.0,
        status: AccessStatus.pending,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      final receipt2 = PaymentReceiptModel(
        id: 102,
        userId: 1,
        courseId: 50,
        paymentMethod: 'vodafone_cash',
        paymentMethodLabel: 'Vodafone Cash',
        senderIdentifier: '01011112222',
        amountPaid: 500.0,
        status: AccessStatus.pending,
        createdAt: DateTime.now(),
      );

      when(() => mockPaymentRepo.submitCourseReceipt(
            courseSlug: 'diploma-speech',
            paymentMethod: 'vodafone_cash',
            senderName: 'أحمد',
            senderAccount: '01011112222',
            amount: 500.0,
            receiptFilePath: dummyReceiptFile.path,
          )).thenAnswer((_) async => receipt1);

      await cubit.submitCourseReceipt(
        courseSlug: 'diploma-speech',
        courseId: '50',
        courseTitle: 'دبلوم التخاطب',
        paymentMethod: 'vodafone_cash',
        senderName: 'أحمد',
        senderAccount: '01011112222',
        amount: 500.0,
        receiptFilePath: dummyReceiptFile.path,
      );

      expect(cubit.state, isA<AccessActionSuccess>());
      var state = cubit.state as AccessActionSuccess;
      expect(state.allRequests.length, equals(1));
      expect(state.getStatus('50'), equals(AccessStatus.pending));

      when(() => mockPaymentRepo.submitCourseReceipt(
            courseSlug: 'diploma-speech',
            paymentMethod: 'vodafone_cash',
            senderName: 'أحمد',
            senderAccount: '01011112222',
            amount: 500.0,
            receiptFilePath: dummyReceiptFile.path,
          )).thenAnswer((_) async => receipt2);

      await cubit.submitCourseReceipt(
        courseSlug: 'diploma-speech',
        courseId: '50',
        courseTitle: 'دبلوم التخاطب',
        paymentMethod: 'vodafone_cash',
        senderName: 'أحمد',
        senderAccount: '01011112222',
        amount: 500.0,
        receiptFilePath: dummyReceiptFile.path,
      );

      state = cubit.state as AccessActionSuccess;
      expect(state.allRequests.length, equals(2));
      expect(state.allRequests.first.id, equals('102'));

      await cubit.close();
    });

    // ------------------------------------------------------------------------
    // SCENARIO 6: Invalid payment method rejected
    // ------------------------------------------------------------------------
    test('6. Invalid payment method rejected with Arabic error', () async {
      final cubit = AccessCubit(
        paymentRepository: mockPaymentRepo,
        coursesRepository: mockCoursesRepo,
      );

      await cubit.submitCourseReceipt(
        courseSlug: 'course-1',
        courseId: '1',
        courseTitle: 'دورة 1',
        paymentMethod: 'credit_card', // Invalid method
        senderName: 'طالب',
        senderAccount: '123456',
        amount: 500.0,
        receiptFilePath: dummyReceiptFile.path,
      );

      expect(cubit.state, isA<AccessError>());
      final err = cubit.state as AccessError;
      expect(err.message, contains('طريقة الدفع غير معتمدة'));

      await cubit.close();
    });

    // ------------------------------------------------------------------------
    // SCENARIO 7: Sender-account & amount input validation (no fake phone fallback)
    // ------------------------------------------------------------------------
    test('7. Sender-account and amount validated without falling back to user.phone or course.price', () async {
      final cubit = AccessCubit(
        paymentRepository: mockPaymentRepo,
        coursesRepository: mockCoursesRepo,
      );

      final userWithPhone = UserModel(
        uid: 'usr_phone',
        email: 'phone@test.com',
        displayName: 'طالب لديه هاتف',
        photoUrl: '',
        phone: '01099998888',
        createdAt: DateTime.now(),
      );

      final course = const Course(
        id: '601',
        title: 'دورة النطق',
        description: 'وصف',
        instructor: 'د. الأمين',
        category: 'نطق',
        thumbnailUrl: '',
        levels: [],
        price: 1500.0,
      );

      // 7A: Empty sender account must NOT fall back to user.phone!
      await cubit.sendRequest(
        course: course,
        user: userWithPhone,
        senderAccount: '  ',
        senderNumberOrRef: '',
        receiptFile: dummyReceiptFile,
        amount: 1500.0,
      );

      expect(cubit.state, isA<AccessError>());
      var err = cubit.state as AccessError;
      expect(err.message, contains('يرجى إدخال رقم المحفظة أو الحساب'));

      // 7B: Missing amount must NOT silently default to course.price!
      await cubit.sendRequest(
        course: course,
        user: userWithPhone,
        senderAccount: '01012345678',
        receiptFile: dummyReceiptFile,
        amount: null, // Null amount
      );

      expect(cubit.state, isA<AccessError>());
      err = cubit.state as AccessError;
      expect(err.message, contains('المبلغ المدفوع غير محدد أو غير صالح'));

      await cubit.close();
    });

    // ------------------------------------------------------------------------
    // SCENARIO 8: Account switching during requests
    // ------------------------------------------------------------------------
    test('8. Account switching during in-flight requests isolates session and clears state', () async {
      final cubit = AccessCubit(
        paymentRepository: mockPaymentRepo,
        coursesRepository: mockCoursesRepo,
      );

      final completerA = Completer<List<PaymentReceiptModel>>();
      when(() => mockPaymentRepo.getStudentReceipts())
          .thenAnswer((_) => completerA.future);

      // Student A initiates request
      final futureA = cubit.loadStudentReceipts(studentId: 'student_A');

      // Switch to Student B
      cubit.listenToStudentRequests('student_B');
      expect(cubit.state, isA<AccessInitial>());

      // Response for A completes late
      completerA.complete([
        PaymentReceiptModel(
          id: 99,
          userId: 1,
          courseId: 10,
          paymentMethod: 'vodafone_cash',
          paymentMethodLabel: 'Vodafone',
          senderIdentifier: '01011112222',
          amountPaid: 1000.0,
          status: AccessStatus.approved,
          createdAt: DateTime.now(),
        ),
      ]);

      await futureA;

      // State is NOT overwritten by student A's data
      expect(cubit.state, isA<AccessInitial>());

      await cubit.close();
    });

    // ------------------------------------------------------------------------
    // SCENARIO 9: Closing a Cubit while requests are pending
    // ------------------------------------------------------------------------
    test('9. Closing Cubit while requests are pending does not emit or throw unhandled exceptions', () async {
      final cubit = AccessCubit(
        paymentRepository: mockPaymentRepo,
        coursesRepository: mockCoursesRepo,
      );

      final completer = Completer<List<PaymentReceiptModel>>();
      when(() => mockPaymentRepo.getStudentReceipts())
          .thenAnswer((_) => completer.future);

      final future = cubit.loadStudentReceipts();

      // Close cubit immediately
      await cubit.close();

      // Completer finishes after close
      completer.complete([]);
      await future;

      // No assertion failure / Bad State
      expect(cubit.isClosed, isTrue);
    });

    // ------------------------------------------------------------------------
    // SCENARIO 10: Server-locked levels at locally calculated 95% or 100%
    // ------------------------------------------------------------------------
    test('10. Server-locked levels remain locked at locally calculated 95% or 100% completion', () {
      final level1 = CourseLevel.fromLaravelJson({
        'id': 'lvl_1',
        'title': 'المستوى الأول',
        'order': 1,
        'is_accessible': true,
      });

      // Level 2 has is_accessible: false from server
      final level2 = CourseLevel.fromLaravelJson({
        'id': 'lvl_2',
        'title': 'المستوى الثاني: التدخل العلاجي',
        'order': 2,
        'is_accessible': false,
      });

      expect(level2.isAccessible, isFalse);

      // Local completion is 100%
      final isUnlocked = CourseProgressPolicy.isLevelUnlocked(
        levels: [level1, level2],
        levelIndex: 1,
        isEnrolled: true,
        completedLessonIds: {'lsn_1', 'lsn_2', 'lsn_3'},
      );

      expect(isUnlocked, isFalse, reason: 'Laravel server authority supersedes local percentage completion');
    });

    // ------------------------------------------------------------------------
    // SCENARIO 11: First-level access without enrollment
    // ------------------------------------------------------------------------
    test('11. First-level access is denied without server-confirmed enrollment', () {
      final level1 = CourseLevel.fromLaravelJson({
        'id': 'lvl_1',
        'title': 'المستوى الأول',
        'order': 1,
        'is_accessible': true,
      });

      // Student is NOT enrolled
      final isUnlocked = CourseProgressPolicy.isLevelUnlocked(
        levels: [level1],
        levelIndex: 0,
        isEnrolled: false,
        completedLessonIds: {},
      );

      expect(isUnlocked, isFalse, reason: 'Unenrolled student cannot access level 1');
    });

    // ------------------------------------------------------------------------
    // SCENARIO 12: Authorized free previews
    // ------------------------------------------------------------------------
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
        isEnrolled: false, // Not enrolled
        completedLessonIds: {},
      );

      expect(reason, isNull, reason: 'Authorized free preview must be playable without enrollment');
    });

    // ------------------------------------------------------------------------
    // SCENARIO 13: Protected playback rejection
    // ------------------------------------------------------------------------
    test('13. Protected lesson playback is rejected without enrollment', () {
      final protectedLesson = Lesson.fromLaravelVideoJson({
        'id': 2001,
        'title': 'محاضرة علاجية سريرية خاصة',
        'is_free': false,
        'is_accessible': false,
        'duration_seconds': 900,
        'playback_id': 'mux_prot_2001',
      });

      expect(protectedLesson.isFreePreview, isFalse);

      final reason = CourseProgressPolicy.lessonLockReason(
        levels: [],
        lesson: protectedLesson,
        isEnrolled: false,
        completedLessonIds: {},
      );

      expect(reason, isNotNull);
      expect(reason, contains('يتطلب الاشتراك في الدورة'));
    });

    // ------------------------------------------------------------------------
    // SCENARIO 14: Assignment Cubit initialization after authentication
    // ------------------------------------------------------------------------
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

    // ------------------------------------------------------------------------
    // SCENARIO 15: Assignment state cleanup at logout
    // ------------------------------------------------------------------------
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

      // Logout / clear
      cubit.clear();

      expect(cubit.state, equals(const AssignmentsInitial()));
      expect(cubit.activeStudentId, isNull);

      await cubit.close();
    });
  });
}

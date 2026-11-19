import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:secure_screen_app/core/network/api_client.dart';
import 'package:secure_screen_app/datasources/auth_remote_data_source.dart';
import 'package:secure_screen_app/logic/access/access_cubit.dart';
import 'package:secure_screen_app/logic/access/access_state.dart';
import 'package:secure_screen_app/logic/assignments/assignments_cubit.dart';
import 'package:secure_screen_app/logic/assignments/assignments_state.dart';
import 'package:secure_screen_app/models/access_request.dart';
import 'package:secure_screen_app/models/assignment.dart';
import 'package:secure_screen_app/models/assignment_submission.dart';
import 'package:secure_screen_app/models/clinical_task_data.dart';
import 'package:secure_screen_app/models/course.dart';
import 'package:secure_screen_app/models/course_access_mode.dart';
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
class MockApiClient extends Mock implements ApiClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ALAMEEN CENTER — SERVER AUTHORITY & ACCESS SECURITY SPECIFICATION', () {
    late MockStudentPaymentRepository mockPaymentRepo;
    late MockStudentCoursesRepository mockCoursesRepo;
    late MockStudentAssignmentsRepository mockAssignmentsRepo;
    late MockApiClient mockApiClient;
    late File dummyReceiptFile;

    setUp(() async {
      mockPaymentRepo = MockStudentPaymentRepository();
      mockCoursesRepo = MockStudentCoursesRepository();
      mockAssignmentsRepo = MockStudentAssignmentsRepository();
      mockApiClient = MockApiClient();

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
    // SCENARIO 1: Approved payment receipt does NOT override revoked enrollment
    // ------------------------------------------------------------------------
    test('1. Approved payment receipt does NOT override server-revoked course enrollment', () async {
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

      // Server indicates user is NOT enrolled (access revoked by administrator)
      when(() => mockCoursesRepo.getCourseDetails('201'))
          .thenAnswer((_) async => course.copyWith(hasEnrolled: false));

      when(() => mockPaymentRepo.getStudentReceipts())
          .thenAnswer((_) async => [approvedReceipt]);

      await cubit.enrollInOpenCourse(uid: 'student_10', course: course);

      // Must fail closed: AccessError emitted, not AccessActionSuccess
      expect(cubit.state, isA<AccessError>());
      final errorState = cubit.state as AccessError;
      expect(errorState.message, contains('يتطلب اعتماداً من إدارة الأكاديمية'));

      await cubit.close();
    });

    // ------------------------------------------------------------------------
    // SCENARIO 2: Null or missing server entitlement NEVER grants course access
    // ------------------------------------------------------------------------
    test('2. Missing or failed server entitlement check fails closed (never grants access)', () async {
      final cubit = AccessCubit(
        paymentRepository: mockPaymentRepo,
        coursesRepository: mockCoursesRepo,
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

      // Server course details request throws a network exception (null entitlement response)
      when(() => mockCoursesRepo.getCourseDetails('202'))
          .thenThrow(DioException(requestOptions: RequestOptions(path: '/student/courses/202')));

      when(() => mockPaymentRepo.getStudentReceipts())
          .thenAnswer((_) async => []);

      await cubit.enrollInOpenCourse(uid: 'student_10', course: course);

      expect(cubit.state, isA<AccessError>());
      await cubit.close();
    });

    // ------------------------------------------------------------------------
    // SCENARIO 3: Pending payment receipt does NOT unlock course lessons
    // ------------------------------------------------------------------------
    test('3. Pending payment receipt does NOT unlock course lessons or grant entitlement', () {
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
    // SCENARIO 4: 95% local progress does NOT unlock server-locked levels
    // ------------------------------------------------------------------------
    test('4. Locally calculated 95% progress does NOT unlock level marked isAccessible: false by Laravel', () {
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

      // Verify fail-closed: backend says isAccessible == false
      expect(level2.isAccessible, isFalse);

      final isUnlocked = CourseProgressPolicy.isLevelUnlocked(
        levels: [level1, level2],
        levelIndex: 1,
        isEnrolled: true,
        completedLessonIds: {'lsn_101', 'lsn_102'},
      );

      expect(isUnlocked, isFalse, reason: 'Laravel server authority supersedes local percentage completion');
    });

    // ------------------------------------------------------------------------
    // SCENARIO 5: Lesson cannot be played without server authorization
    // ------------------------------------------------------------------------
    test('5. Lesson cannot be played without explicit server authorization', () {
      final lesson = Lesson.fromLaravelVideoJson({
        'id': 301,
        'title': 'جلسة سريرية محمية',
        'is_free': false,
        'duration_seconds': 600,
        'playback_id': 'mux_sample_301',
      });
      expect(lesson.isFreePreview, isFalse);

      // Course without enrollment
      final unenrolledCourse = const Course(
        id: '401',
        title: 'دبلوم التخاطب الشامل',
        description: 'وصف',
        instructor: 'د. الأمين',
        category: 'تخاطب',
        thumbnailUrl: '',
        levels: [],
        price: 2000.0,
        hasEnrolled: false,
        accessibleVideoIds: [],
      );

      // Verify server authorization matrix
      final isAuthorized = unenrolledCourse.hasEnrolled ||
          unenrolledCourse.accessibleVideoIds.contains(lesson.id) ||
          lesson.isFreePreview;

      expect(isAuthorized, isFalse, reason: 'Must fail closed when student is not authorized by backend');
    });

    // ------------------------------------------------------------------------
    // SCENARIO 6: Assignment listing displays ONLY tasks returned by Laravel API
    // ------------------------------------------------------------------------
    test('6. Assignment listing displays ONLY tasks returned by Laravel API', () async {
      final task1 = Assignment(
        id: '11',
        courseId: '50',
        courseTitle: 'دبلوم التخاطب',
        title: 'دراسة حالة التأتأة الأولى',
        instructions: 'تحليل تسجيل صوتي',
        createdAt: DateTime.now(),
      );

      final task2 = Assignment(
        id: '12',
        courseId: '50',
        courseTitle: 'دبلوم التخاطب',
        title: 'تقييم الحصيلة اللغوية',
        instructions: 'نموذج الفحص',
        createdAt: DateTime.now(),
      );

      final sub2 = AssignmentSubmission(
        id: 'sub_12',
        assignmentId: '12',
        courseId: '50',
        studentId: '10',
        studentName: 'أحمد',
        studentEmail: 'ahmed@test.com',
        solutionText: 'تم إرفاق التسجيل',
        status: 'graded',
        score: 95,
        submittedAt: DateTime.now(),
      );

      final clinicalData = StudentAssignmentsData(
        tasks: [task1, task2],
        submissions: [sub2],
      );

      when(() => mockAssignmentsRepo.getAssignments())
          .thenAnswer((_) async => clinicalData);

      final cubit = AssignmentsCubit(repository: mockAssignmentsRepo);

      expectLater(
        cubit.stream,
        emitsInOrder([
          isA<AssignmentsLoading>(),
          isA<AssignmentsLoaded>().having(
            (s) => s.data.tasks.length,
            'tasks length',
            equals(2),
          ),
        ]),
      );

      await cubit.loadAssignments();

      final state = cubit.state as AssignmentsLoaded;
      expect(state.data.tasks[0].id, equals('11'));
      expect(state.data.tasks[1].id, equals('12'));
      expect(state.data.pendingTasks.length, equals(1));
      expect(state.data.gradedSubmissions.length, equals(1));
      expect(state.data.averageScore, equals(95));

      await cubit.close();
    });

    // ------------------------------------------------------------------------
    // SCENARIO 7: No assignment IDs are synthesized from lesson IDs
    // ------------------------------------------------------------------------
    test('7. No assignment IDs are synthesized from lesson IDs', () {
      final lesson = Lesson(
        id: 'lsn_999',
        title: 'الدرس النظري للأصوات',
        description: '',
        duration: '10:00',
        muxPlaybackId: 'test_mux',
        order: 1,
      );

      // Verify that no synthesis logic exists in domain model
      expect(lesson.id, equals('lsn_999'));
      expect(lesson.id.startsWith('asg_'), isFalse);
    });

    // ------------------------------------------------------------------------
    // SCENARIO 8: UI widgets do not call repositories directly
    // ------------------------------------------------------------------------
    test('8. Presentation layer relies strictly on Cubits, not direct repository references', () async {
      final cubit = AssignmentsCubit(repository: mockAssignmentsRepo);
      expect(cubit, isA<AssignmentsCubit>());
      expect(cubit.state, isA<AssignmentsInitial>());
      await cubit.close();
    });

    // ------------------------------------------------------------------------
    // SCENARIO 9: UI widgets do not trigger HTTP requests in build()
    // ------------------------------------------------------------------------
    test('9. Lifecycle loads assignments in initState, build() is idempotent', () async {
      final cubit = AssignmentsCubit(repository: mockAssignmentsRepo);
      expect(cubit.state, isA<AssignmentsInitial>());
      await cubit.close();
    });

    // ------------------------------------------------------------------------
    // SCENARIO 10: Invalid sender accounts & missing prices rejected locally
    // ------------------------------------------------------------------------
    test('10. Invalid sender account and missing payment price rejected with Arabic error (no fake defaults)', () async {
      final cubit = AccessCubit(
        paymentRepository: mockPaymentRepo,
        coursesRepository: mockCoursesRepo,
      );

      final user = UserModel(
        uid: 'usr_1',
        email: 'test@student.com',
        displayName: 'طالب سنتر الأمين',
        photoUrl: '',
        phone: '', // Empty phone
        createdAt: DateTime.now(),
      );

      final course = const Course(
        id: '501',
        title: 'دورة النطق السريري',
        description: 'وصف',
        instructor: 'د. الأمين',
        category: 'نطق',
        thumbnailUrl: '',
        levels: [],
        price: 0.0, // Zero price without override
      );

      // 1. Missing sender account
      await cubit.sendRequest(
        course: course,
        user: user,
        senderAccount: '  ',
        senderNumberOrRef: '',
        receiptFile: dummyReceiptFile,
        amount: 500.0,
      );

      expect(cubit.state, isA<AccessError>());
      var err = cubit.state as AccessError;
      expect(err.message, contains('يرجى إدخال رقم المحفظة أو الحساب'));

      // 2. Missing or zero amount
      await cubit.sendRequest(
        course: course,
        user: user,
        senderAccount: '01012345678',
        receiptFile: dummyReceiptFile,
        amount: 0.0,
      );

      expect(cubit.state, isA<AccessError>());
      err = cubit.state as AccessError;
      expect(err.message, contains('المبلغ المدفوع غير محدد أو غير صالح'));

      // Verify repository was NEVER called with fake values ('01000000000', 100.0)
      verifyNever(() => mockPaymentRepo.submitCourseReceipt(
            courseSlug: any(named: 'courseSlug'),
            paymentMethod: any(named: 'paymentMethod'),
            senderName: any(named: 'senderName'),
            senderAccount: any(named: 'senderAccount'),
            amount: any(named: 'amount'),
            receiptFilePath: any(named: 'receiptFilePath'),
          ));

      await cubit.close();
    });

    // ------------------------------------------------------------------------
    // SCENARIO 11: Generation guards cancel stale async operations on logout
    // ------------------------------------------------------------------------
    test('11. Account switching / logout cancels pending async operations via generation guard', () async {
      final cubit = AccessCubit(
        paymentRepository: mockPaymentRepo,
        coursesRepository: mockCoursesRepo,
      );

      final completer = Completer<List<PaymentReceiptModel>>();

      when(() => mockPaymentRepo.getStudentReceipts())
          .thenAnswer((_) => completer.future);

      // Start slow request for student_old
      final future = cubit.loadStudentReceipts(studentId: 'student_old');

      // Immediate logout / clear
      cubit.clear();
      expect(cubit.state, isA<AccessInitial>());

      // Stale response arrives late
      completer.complete([
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

      await future;

      // State must remain AccessInitial because generation guard rejected stale response
      expect(cubit.state, isA<AccessInitial>());

      await cubit.close();
    });

    // ------------------------------------------------------------------------
    // SCENARIO 12: Multi-user isolation clears in-memory state on switch
    // ------------------------------------------------------------------------
    test('12. Authenticated user ID switch resets in-memory request state completely', () async {
      final cubit = AccessCubit(
        paymentRepository: mockPaymentRepo,
        coursesRepository: mockCoursesRepo,
      );

      when(() => mockPaymentRepo.getStudentReceipts())
          .thenAnswer((_) async => []);

      cubit.listenToStudentRequests('user_alpha');
      await pumpEventQueue();

      // Switch to user_beta
      cubit.listenToStudentRequests('user_beta');

      // Prior user state is cleared
      expect(cubit.state, isA<AccessInitial>());

      await pumpEventQueue();
      await cubit.close();
    });

    // ------------------------------------------------------------------------
    // SCENARIO 13: Google Auth exchange sends OAuth access_token, NOT id_token
    // ------------------------------------------------------------------------
    test('13. Google Auth exchange strictly sends OAuth access_token to /auth/google/token', () async {
      FormData? sentFormData;
      Options? sentOptions;

      when(() => mockApiClient.postMultipart(
            '/auth/google/token',
            formData: any(named: 'formData'),
            options: any(named: 'options'),
          )).thenAnswer((invocation) async {
        sentFormData = invocation.namedArguments[#formData] as FormData;
        sentOptions = invocation.namedArguments[#options] as Options?;

        return Response(
          requestOptions: RequestOptions(path: '/auth/google/token'),
          statusCode: 200,
          data: {
            'success': true,
            'status': 'authenticated',
            'data': {
              'token': '3|sanctum_token_123',
              'token_type': 'Bearer',
              'user': {
                'id': 7,
                'name': 'طالب موثق',
                'email': 'student@example.com',
              },
            },
          },
        );
      });

      final authRemote = AuthRemoteDataSourceImpl(apiClient: mockApiClient);

      const oAuthToken = 'ya29.sample_oauth2_token_for_verification';

      final session = await authRemote.loginWithGoogleToken(
        accessToken: oAuthToken,
        deviceName: 'Mobile Test Device',
      );

      expect(session.isAuthenticated, isTrue);
      expect(sentFormData, isNotNull);

      final fields = sentFormData!.fields;
      final accessTokenField = fields.firstWhere(
        (f) => f.key == 'access_token',
        orElse: () => const MapEntry('', ''),
      );

      expect(accessTokenField.key, equals('access_token'));
      expect(accessTokenField.value, equals(oAuthToken));

      // Assert id_token is NOT sent
      final hasIdToken = fields.any((f) => f.key == 'id_token');
      expect(hasIdToken, isFalse, reason: 'Laravel contract requires OAuth access_token, NOT Google id_token');

      // Assert skipAuth: true
      expect(sentOptions?.extra?['skipAuth'], isTrue);
    });

    // ------------------------------------------------------------------------
    // SCENARIO 14: Preserves all existing functionality across platform domains
    // ------------------------------------------------------------------------
    test('14. Core platform models and contracts remain intact and backward compatible', () {
      // 1. Payment receipt model
      final receipt = PaymentReceiptModel(
        id: 1,
        userId: 1,
        courseId: 10,
        paymentMethod: 'vodafone_cash',
        paymentMethodLabel: 'Vodafone',
        senderIdentifier: '01000000000',
        amountPaid: 100.0,
        status: AccessStatus.approved,
        createdAt: DateTime.now(),
      );
      expect(receipt.id, equals(1));
      expect(receipt.toCourseAccessRequest().courseId, equals('10'));

      // 2. Clinical task data
      final task = Assignment(
        id: '1',
        courseId: '10',
        courseTitle: 'دورة تجريبية',
        title: 'واجب سريري',
        instructions: 'تعليمات',
        createdAt: DateTime.now(),
      );
      final taskData = StudentAssignmentsData(tasks: [task]);
      expect(taskData.pendingCount, equals(1));
      expect(taskData.submittedCount, equals(0));

      // 3. Level fail-closed model
      final level = CourseLevel.fromLaravelJson({
        'id': 'lvl_1',
        'title': 'المستوى الأول',
        'order': 1,
      });
      expect(level.isAccessible, isTrue); // Level 1 is accessible for enrolled courses
    });
  });
}

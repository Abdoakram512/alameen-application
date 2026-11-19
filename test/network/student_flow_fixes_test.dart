import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secure_screen_app/repositories/student_payment_repository.dart';
import 'package:secure_screen_app/features/payments/domain/entities/receipt_submission_input.dart';
import 'package:secure_screen_app/features/payments/domain/entities/payment_method.dart';
import 'package:secure_screen_app/features/payments/presentation/cubits/receipt_submission/receipt_submission_cubit.dart';
import 'package:secure_screen_app/features/payments/presentation/cubits/receipt_submission/receipt_submission_state.dart';
import 'package:secure_screen_app/datasources/assignments_remote_data_source.dart';
import 'package:secure_screen_app/core/network/api_exceptions.dart';
import 'package:secure_screen_app/core/network/safe_http_logger.dart';
import 'package:secure_screen_app/models/course_level.dart';
import 'package:secure_screen_app/models/lesson.dart';
import 'package:secure_screen_app/models/course_progress_policy.dart';
import 'package:secure_screen_app/repositories/impl/student_assignments_repository_impl.dart';

class MockPayments extends Mock implements StudentPaymentRepository {}

class MockAssignmentsRemote extends Mock
    implements AssignmentsRemoteDataSource {}

class HandledError extends ErrorInterceptorHandler {
  @override
  void next(DioException error) {}
}

void main() {
  const lesson = Lesson(
    id: '10',
    title: 'L',
    description: '',
    duration: '1:00',
  );
  CourseLevel level(String id, bool access) => CourseLevel(
    id: id,
    title: id,
    description: '',
    order: 1,
    lessons: const [lesson],
    isAccessible: access,
  );
  test('Laravel allows later levels despite zero local completion', () {
    expect(
      CourseProgressPolicy.isLevelUnlocked(
        levels: [level('1', true), level('2', true)],
        levelIndex: 1,
        isEnrolled: true,
        completedLessonIds: {},
      ),
      isTrue,
    );
  });
  test('Local completion cannot override Laravel denial', () {
    expect(
      CourseProgressPolicy.isLevelUnlocked(
        levels: [level('1', true), level('2', false)],
        levelIndex: 1,
        isEnrolled: true,
        completedLessonIds: {'10'},
      ),
      isFalse,
    );
    expect(
      CourseProgressPolicy.lessonLockReason(
        levels: [],
        lesson: lesson,
        isEnrolled: true,
        completedLessonIds: {},
        enforceServerAccessibleList: true,
        accessibleVideoIds: [],
      ),
      isNotNull,
    );
  });
  test('Invalid task IDs fail before any request or task-1 fallback', () async {
    final repository = StudentAssignmentsRepositoryImpl();
    for (final id in ['task_12', 'legacy', '0', '-1']) {
      await expectLater(repository.getAssignment(id), throwsArgumentError);
    }
  });
  test(
    'Task detail authorization failures propagate instead of cached fallback',
    () async {
      final remote = MockAssignmentsRemote();
      when(
        () => remote.getAssignmentDetails(12),
      ).thenThrow(const ForbiddenException('Access denied'));
      final repository = StudentAssignmentsRepositoryImpl(
        remoteDataSource: remote,
      );
      await expectLater(
        repository.getAssignment('12'),
        throwsA(isA<ForbiddenException>()),
      );
      await expectLater(
        repository.submitClinicalTask(taskId: 0),
        throwsArgumentError,
      );
      verifyNever(() => remote.submitAssignment(taskId: 0));
    },
  );
  test(
    'Repeated missing-receipt submission remains visibly retryable',
    () async {
      final cubit = ReceiptSubmissionCubit(repository: MockPayments());
      final states = <ReceiptSubmissionState>[];
      final subscription = cubit.stream.listen(states.add);
      const input = ReceiptSubmissionInput(
        courseSlug: 'course',
        courseId: '1',
        courseTitle: 'Course',
        paymentMethod: PaymentMethod.instapay,
        senderName: 'Student',
        senderAccount: 'account',
        amount: 10,
        receiptFilePath: '',
      );
      await cubit.submit(input);
      await cubit.submit(input);
      await Future<void>.delayed(Duration.zero);
      expect(states.whereType<ReceiptSubmissionInProgress>(), hasLength(2));
      expect(
        states.whereType<ReceiptSubmissionValidationFailure>(),
        hasLength(2),
      );
      await subscription.cancel();
      await cubit.close();
    },
  );
  test('Logger colors, status, timing and privacy across all events', () {
    final lines = <String>[];
    final logger = SafeHttpLogger(output: lines.add);
    final request = RequestOptions(
      path: '/student/courses/private-name/receipt?email=secret@example.com',
      method: 'POST',
      headers: {'Authorization': 'Bearer secret-token'},
      data: FormData.fromMap({
        'sender_name': 'Private Person',
        'receipt_image': MultipartFile.fromString(
          'private file',
          filename: 'secret.png',
        ),
      }),
    );
    logger.onRequest(request, RequestInterceptorHandler());
    logger.onResponse(
      Response(
        requestOptions: request,
        statusCode: 201,
        data: {'email': 'private@example.com'},
      ),
      ResponseInterceptorHandler(),
    );
    logger.onError(
      DioException(
        requestOptions: request,
        message: 'secret-token',
        response: Response(
          requestOptions: request,
          statusCode: 422,
          data: {'message': 'Private Person'},
        ),
      ),
      HandledError(),
    );
    expect(lines[0], contains('\x1B[36m'));
    expect(lines[1], contains('\x1B[32m'));
    expect(lines[2], contains('\x1B[31m'));
    expect(lines[1], contains('status=201'));
    expect(lines[2], contains('status=422'));
    expect(lines.join(), contains('ms'));
    for (final secret in [
      'secret-token',
      'private-name',
      'Private Person',
      'secret.png',
      'example.com',
      'private file',
    ]) {
      expect(lines.join(), isNot(contains(secret)));
    }
  });
}

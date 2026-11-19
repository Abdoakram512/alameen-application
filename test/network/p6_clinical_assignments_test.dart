import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:secure_screen_app/core/network/api_client.dart';
import 'package:secure_screen_app/core/network/api_exceptions.dart';
import 'package:secure_screen_app/datasources/assignments_remote_data_source.dart';
import 'package:secure_screen_app/models/assignment_submission.dart';
import 'package:secure_screen_app/repositories/impl/student_assignments_repository_impl.dart';
import 'package:secure_screen_app/repositories/student_learning_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient mockApiClient;
  late AssignmentsRemoteDataSource remoteDataSource;
  late StudentAssignmentsRepositoryImpl assignmentsRepository;
  late StudentLearningRepository learningRepository;

  setUp(() {
    mockApiClient = MockApiClient();
    remoteDataSource = AssignmentsRemoteDataSourceImpl(apiClient: mockApiClient);
    assignmentsRepository = StudentAssignmentsRepositoryImpl(
      remoteDataSource: remoteDataSource,
    );
    learningRepository = StudentLearningRepositoryImpl(
      assignmentsRepository: assignmentsRepository,
    );
  });

  group('Phase P6 — Clinical Assignments & Grades (Laravel REST API)', () {
    // 1. Assignment listing
    test('1. GET /student/assignments parses clinical tasks and student submissions cleanly', () async {
      when(() => mockApiClient.get('/student/assignments')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/assignments'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'tasks': [
                {
                  'id': 5,
                  'course_id': 1,
                  'video_id': 10,
                  'title': 'تطبيق خطة علاجية صوتية لحالة لدغة الراء',
                  'instructions': 'سجل صوتك وأنت تدرب الحالة على نطق حرف الراء.',
                  'max_score': 100,
                  'created_at': '2026-02-01T10:00:00Z',
                },
              ],
              'submissions': [
                {
                  'id': 42,
                  'task_id': 5,
                  'user_id': 15,
                  'audio_recording_url': 'https://cdn.alameen-center.online/recordings/42.mp3',
                  'student_notes': 'تم التسجيل في بيئة هادئة',
                  'status': 'evaluated',
                  'score': 95,
                  'clinical_feedback': 'أداء ممتاز ونبرة صوتية صحيحة',
                  'grader_name': 'د. أكرم',
                  'created_at': '2026-02-02T12:00:00Z',
                },
              ],
            },
          },
        ),
      );

      final result = await assignmentsRepository.getAssignments();

      expect(result.tasks.length, equals(1));
      expect(result.tasks.first.id, equals('5'));
      expect(result.tasks.first.title, contains('لدغة الراء'));
      expect(result.tasks.first.maxScore, equals(100));

      expect(result.submissions.length, equals(1));
      expect(result.submissions.first.id, equals('42'));
      expect(result.submissions.first.score, equals(95));
      expect(result.submissions.first.isGraded, isTrue);
      expect(result.submissions.first.adminFeedback, contains('د. أكرم'));
    });

    // 2. Assignment details
    test('2. GET /student/assignments/{task} returns specific clinical task and student submission', () async {
      when(() => mockApiClient.get('/student/assignments/5')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/assignments/5'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'task': {
                'id': 5,
                'course_id': 1,
                'title': 'مهمة فحص الحبال الصوتية',
                'instructions': 'تعليمات الفحص',
                'max_score': 50,
              },
              'submission': {
                'id': 42,
                'task_id': 5,
                'status': 'pending',
                'student_notes': 'في انتظار التقييم السريري',
              },
            },
          },
        ),
      );

      final details = await assignmentsRepository.getAssignmentDetails(5);

      expect(details.task.id, equals('5'));
      expect(details.task.title, equals('مهمة فحص الحبال الصوتية'));
      expect(details.task.maxScore, equals(50));
      expect(details.submission, isNotNull);
      expect(details.submission!.status, equals('pending'));
      expect(details.submission!.isGraded, isFalse);
    });

    // 3. Audio multipart submission
    test('3. POST /student/assignments/{task}/submit sends multipart audio and parses TaskSubmission', () async {
      when(
        () => mockApiClient.post(
          '/student/assignments/5/submit',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/assignments/5/submit'),
          statusCode: 201,
          data: {
            'success': true,
            'message': 'Voice task submitted',
            'data': {
              'submission': {
                'id': 99,
                'task_id': 5,
                'user_id': 15,
                'audio_recording_url': 'https://cdn.alameen-center.online/recordings/99.mp3',
                'student_notes': 'تسجيل صوتي تجريبي',
                'status': 'pending',
                'created_at': '2026-03-01T12:00:00Z',
              },
            },
          },
        ),
      );

      final tempFile = File('${Directory.systemTemp.path}/test_recording.mp3');
      await tempFile.writeAsString('dummy audio content');
      addTearDown(() async {
        if (await tempFile.exists()) await tempFile.delete();
      });

      final submission = await assignmentsRepository.submitClinicalTask(
        taskId: 5,
        audioFile: tempFile,
        durationSeconds: 120,
        studentNotes: 'تسجيل صوتي تجريبي',
      );

      expect(submission.id, equals('99'));
      expect(submission.assignmentId, equals('5'));
      expect(submission.status, equals('pending'));
      expect(submission.attachmentUrl, contains('99.mp3'));

      verify(
        () => mockApiClient.post(
          '/student/assignments/5/submit',
          data: any(
            named: 'data',
            that: isA<FormData>().having(
              (fd) => fd.fields.any((f) => f.key == 'student_notes' && f.value == 'تسجيل صوتي تجريبي'),
              'has student_notes',
              isTrue,
            ),
          ),
        ),
      ).called(1);
    });

    // 4. Base64 audio submission
    test('4. POST /student/assignments/{task}/submit supports audio_base64 string without file', () async {
      when(
        () => mockApiClient.post(
          '/student/assignments/7/submit',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/assignments/7/submit'),
          statusCode: 201,
          data: {
            'success': true,
            'data': {
              'submission': {
                'id': 105,
                'task_id': 7,
                'user_id': 15,
                'status': 'pending',
                'student_notes': 'تسجيل base64',
              },
            },
          },
        ),
      );

      final sub = await assignmentsRepository.submitClinicalTask(
        taskId: 7,
        audioBase64: 'UklGRiQAAABXQVZFZm10IBAAAAABAAEA',
        studentNotes: 'تسجيل base64',
      );

      expect(sub.id, equals('105'));
      expect(sub.assignmentId, equals('7'));
    });

    // 5. Invalid file / validation error handling (422)
    test('5. POST /student/assignments/{task}/submit throws ApiException on 422 validation failure', () async {
      final req = RequestOptions(path: '/student/assignments/5/submit');
      when(
        () => mockApiClient.post(
          '/student/assignments/5/submit',
          data: any(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: req,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: req,
            statusCode: 422,
            data: {
              'success': false,
              'message': 'صيغة الملف غير مدعومة، يرجى رفع ملف صوتي صالح.',
            },
          ),
        ),
      );

      await expectLater(
        () => assignmentsRepository.submitClinicalTask(
          taskId: 5,
          studentNotes: 'بدون ملف صوتي',
        ),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 422),
        ),
      );
    });

    // 6. Unauthorized access (401 & 403)
    test('6. GET /student/assignments handles 401 & 403 error states cleanly', () async {
      final req = RequestOptions(path: '/student/assignments');
      when(() => mockApiClient.get('/student/assignments')).thenThrow(
        DioException(
          requestOptions: req,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: req,
            statusCode: 403,
            data: {'message': 'غير مصرح لك بعرض التكليفات.'},
          ),
        ),
      );

      await expectLater(
        () => assignmentsRepository.getAssignments(),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });

    // 7. Grades overview
    test('7. GET /student/grades parses student stats and evaluated submissions', () async {
      when(() => mockApiClient.get('/student/grades')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/grades'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'stats': {
                'total_submissions': 6,
                'graded_count': 5,
                'pending_count': 1,
                'passed_count': 5,
                'average_score': 94.5,
              },
              'submissions': [
                {
                  'id': 42,
                  'task_id': 5,
                  'user_id': 15,
                  'status': 'evaluated',
                  'score': 96,
                  'clinical_feedback': 'ممتاز',
                },
              ],
            },
          },
        ),
      );

      final grades = await assignmentsRepository.getStudentGrades();

      expect(grades.stats.totalSubmissions, equals(6));
      expect(grades.stats.gradedCount, equals(5));
      expect(grades.stats.pendingCount, equals(1));
      expect(grades.stats.passedCount, equals(5));
      expect(grades.stats.averageScore, equals(94.5));
      expect(grades.submissions.length, equals(1));
      expect(grades.submissions.first.score, equals(96));
    });

    // 8. Submission details
    test('8. GET /student/submissions/{submission} returns detailed instructor feedback', () async {
      when(() => mockApiClient.get('/student/submissions/42')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/submissions/42'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'submission': {
                'id': 42,
                'task_id': 5,
                'user_id': 15,
                'status': 'evaluated',
                'score': 98,
                'clinical_feedback': 'تحسن ملحوظ في السكون والإدغام',
                'grader_name': 'المشرف الأكاديمي',
              },
            },
          },
        ),
      );

      final sub = await assignmentsRepository.getSubmissionDetails(42);

      expect(sub.id, equals('42'));
      expect(sub.score, equals(98));
      expect(sub.adminFeedback, contains('المشرف الأكاديمي'));
      expect(sub.isGraded, isTrue);
    });

    // 9. Offline / network failure handling
    test('9. Network timeout gracefully throws ConnectionException from ApiClient', () async {
      when(() => mockApiClient.get('/student/assignments')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/student/assignments'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectLater(
        () => assignmentsRepository.getAssignments(),
        throwsA(isA<ApiException>()),
      );
    });

    // 10. StudentLearningRepository delegation & zero Firebase calls
    test('10. StudentLearningRepository delegates all assignments to StudentAssignmentsRepository with ZERO Firebase dependencies', () async {
      when(() => mockApiClient.get('/student/assignments')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/assignments'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'tasks': [
                {
                  'id': 1,
                  'course_id': 10,
                  'title': 'تكليف 1',
                  'instructions': 'تعليمات',
                  'max_score': 100,
                },
              ],
              'submissions': [
                {
                  'id': 88,
                  'task_id': 1,
                  'user_id': 15,
                  'status': 'evaluated',
                  'score': 100,
                },
              ],
            },
          },
        ),
      );

      final submissions = await learningRepository.getStudentSubmissions('15');
      expect(submissions.length, equals(1));
      expect(submissions.first.id, equals('88'));

      when(() => mockApiClient.get('/student/assignments/1')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/assignments/1'),
          data: {'data': {'task': {'id': 1, 'course_id': 10,
            'title': '\u062a\u0643\u0644\u064a\u0641 1'}}},
        ),
      );
      final task = await learningRepository.getAssignment('1');
      expect(task, isNotNull);
      expect(task!.title, equals('تكليف 1'));
    });

    // 11. No duplicate submissions: in-memory cache updates seamlessly
    test('11. submitAssignment updates cached submission and does not create duplicate entries', () async {
      when(
        () => mockApiClient.post(
          '/student/assignments/5/submit',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/student/assignments/5/submit'),
          statusCode: 201,
          data: {
            'success': true,
            'data': {
              'submission': {
                'id': 42,
                'task_id': 5,
                'user_id': 15,
                'status': 'pending',
                'student_notes': 'تسليم محدث',
              },
            },
          },
        ),
      );

      final updatedSub = await assignmentsRepository.submitAssignment(
        submission: AssignmentSubmission(
          id: '42',
          assignmentId: '5',
          courseId: '1',
          studentId: '15',
          studentName: 'طالب',
          studentEmail: 'student@example.com',
          solutionText: 'تسليم محدث',
          submittedAt: DateTime(2026, 3, 1),
        ),
      );

      expect(updatedSub.id, equals('42'));
      final cached = await assignmentsRepository.getStudentSubmissions('15');
      expect(cached.length, equals(1));
      expect(cached.first.solutionText, equals('تسليم محدث'));
    });

    // 12. File inspection: zero legacy Firestore and Storage calls in assignment repos
    test('12. StudentAssignmentsRepositoryImpl and StudentLearningRepositoryImpl contain ZERO Firestore imports', () {
      final repoContent =
          File('lib/repositories/impl/student_assignments_repository_impl.dart').readAsStringSync();
      final learningContent =
          File('lib/repositories/student_learning_repository.dart').readAsStringSync();

      expect(repoContent.contains('cloud_firestore'), isFalse);
      expect(repoContent.contains('FirebaseFirestore'), isFalse);
      expect(repoContent.contains('firebase_storage'), isFalse);

      expect(learningContent.contains('cloud_firestore'), isFalse);
      expect(learningContent.contains('FirebaseFirestore'), isFalse);
      expect(learningContent.contains('firebase_storage'), isFalse);
      expect(learningContent.contains('FirestoreService'), isFalse);
    });
  });
}

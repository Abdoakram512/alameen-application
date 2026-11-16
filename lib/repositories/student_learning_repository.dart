import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/assignment.dart';
import '../models/assignment_submission.dart';
import '../models/lesson.dart';
import '../models/watch_log_entry.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

/// نتيجة تحليل رابط البث الآمن للمحاضرة (يدعم الروابط الموقعة JWT ومجموعة الدروس المحمية).
class ResolvedLessonPlayback {
  final String streamUrl;
  final String thumbnailUrl;

  const ResolvedLessonPlayback({
    required this.streamUrl,
    required this.thumbnailUrl,
  });
}

/// واجهة نظيفة تفصل طبقة العرض (UI Widgets) عن تفاصيل Firestore و Storage و Cloud Functions.
abstract class StudentLearningRepository {
  Stream<List<Assignment>> streamCourseAssignments(String courseId);
  Stream<List<AssignmentSubmission>> streamStudentSubmissions(String studentId);
  Stream<List<WatchLogEntry>> streamStudentWatchLogs(String studentId);

  Future<void> toggleLessonCompletion({
    required String uid,
    required String lessonId,
    required bool isCompleted,
  });

  Future<void> submitAssignment({
    required AssignmentSubmission submission,
    File? attachmentFile,
  });

  Future<void> recordWatchEvent(Map<String, dynamic> event);

  Future<ResolvedLessonPlayback> resolveLessonPlayback({
    required String courseId,
    required Lesson lesson,
  });
}

class StudentLearningRepositoryImpl implements StudentLearningRepository {
  final FirestoreService _firestoreService;
  final StorageService _storageService;

  static const String _functionsBaseUrl = String.fromEnvironment(
    'FUNCTIONS_BASE_URL',
    defaultValue: 'https://us-central1-elameen.cloudfunctions.net',
  );
  static bool _cloudPlaybackUnavailable = false;

  StudentLearningRepositoryImpl({
    FirestoreService? firestoreService,
    StorageService? storageService,
  })  : _firestoreService = firestoreService ?? FirestoreService(),
        _storageService = storageService ?? StorageService();

  @override
  Stream<List<Assignment>> streamCourseAssignments(String courseId) {
    return _firestoreService.streamCourseAssignments(courseId);
  }

  @override
  Stream<List<AssignmentSubmission>> streamStudentSubmissions(
    String studentId,
  ) {
    return _firestoreService.streamStudentSubmissions(studentId);
  }

  @override
  Stream<List<WatchLogEntry>> streamStudentWatchLogs(String studentId) {
    return _firestoreService.streamStudentWatchLogs(studentId);
  }

  @override
  Future<void> toggleLessonCompletion({
    required String uid,
    required String lessonId,
    required bool isCompleted,
  }) {
    return _firestoreService.toggleLessonCompletion(uid, lessonId, isCompleted);
  }

  @override
  Future<void> submitAssignment({
    required AssignmentSubmission submission,
    File? attachmentFile,
  }) async {
    var finalSubmission = submission;
    if (attachmentFile != null) {
      final uploadedUrl = await _storageService
          .uploadAssignmentAttachment(
            studentId: submission.studentId,
            assignmentId: submission.assignmentId,
            file: attachmentFile,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('استغرق رفع المرفق وقتاً طويلاً. تأكد من سرعة اتصالك بالإنترنت.'),
          );
      finalSubmission = AssignmentSubmission(
        id: submission.id,
        assignmentId: submission.assignmentId,
        assignmentTitle: submission.assignmentTitle,
        courseId: submission.courseId,
        studentId: submission.studentId,
        studentName: submission.studentName,
        studentEmail: submission.studentEmail,
        solutionText: submission.solutionText,
        attachmentUrl: uploadedUrl,
        status: submission.status,
        score: submission.score,
        maxScore: submission.maxScore,
        adminFeedback: submission.adminFeedback,
        submittedAt: submission.submittedAt,
        gradedAt: submission.gradedAt,
      );
    }
    await _firestoreService
        .submitAssignment(finalSubmission)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('استغرق حفظ بيانات التكليف وقتاً طويلاً. تأكد من اتصالك بالإنترنت.'),
        );
  }

  @override
  Future<void> recordWatchEvent(Map<String, dynamic> event) {
    return _firestoreService.recordWatchEvent(event);
  }

  @override
  Future<ResolvedLessonPlayback> resolveLessonPlayback({
    required String courseId,
    required Lesson lesson,
  }) async {
    // 1. محاولة الحصول على رابط بث موقع قصير الصلاحية (Signed JWT) من Cloud Functions إن وجدت
    if (_functionsBaseUrl.isNotEmpty && !_cloudPlaybackUnavailable) {
      try {
        final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
        final headers = <String, String>{
          'Content-Type': 'application/json',
          if (idToken != null) 'Authorization': 'Bearer $idToken',
        };
        final resp = await http
            .post(
              Uri.parse('$_functionsBaseUrl/getSignedPlaybackUrl'),
              headers: headers,
              body: jsonEncode({
                'courseId': courseId,
                'lessonId': lesson.id,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (resp.statusCode == 404) {
          _cloudPlaybackUnavailable = true;
        } else if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          final signedStream = (body['streamUrl'] as String?)?.trim() ?? '';
          final signedThumb = (body['thumbnailUrl'] as String?)?.trim() ?? '';
          if (signedStream.isNotEmpty) {
            return ResolvedLessonPlayback(
              streamUrl: signedStream,
              thumbnailUrl: signedThumb,
            );
          }
        }
      } catch (_) {
        // التراجع السلس لـ Firestore protected_lessons عند عدم نشر دوال السحابة بعد
      }
    }

    if (lesson.isVideoProcessing) {
      throw StateError('المحاضرة قيد التجهيز والمعالجة السحابية في Mux وستكون متاحة للمشاهدة فور اكتمالها.');
    }

    // 2. إذا كان الدرس مدفوعاً ومعزولاً في protected_lessons، يُجلب بصلاحية الطالب المشترك
    var playbackId = lesson.muxPlaybackId.trim();
    if (playbackId.isEmpty && !lesson.isFreePreview) {
      playbackId = (await _firestoreService.fetchProtectedLessonPlaybackId(
            courseId: courseId,
            lessonId: lesson.id,
          )) ??
          '';
    }

    if (playbackId.isEmpty) {
      throw StateError('تعذر العثور على رابط البث المحمي لهذه المحاضرة.');
    }

    return ResolvedLessonPlayback(
      streamUrl: 'https://stream.mux.com/$playbackId.m3u8',
      thumbnailUrl: lesson.thumbnailUrl.isNotEmpty
          ? lesson.thumbnailUrl
          : 'https://image.mux.com/$playbackId/thumbnail.jpg?width=600&height=340&fit_mode=smart',
    );
  }
}

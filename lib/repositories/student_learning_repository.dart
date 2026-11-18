import 'dart:async';
import 'dart:io';
import '../core/di/injection_container.dart';
import '../models/assignment.dart';
import '../models/assignment_submission.dart';
import '../models/lesson.dart';
import '../models/lesson_playback_data.dart';
import '../repositories/student_watch_repository.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

export '../models/lesson_playback_data.dart' show ResolvedLessonPlayback;
export '../repositories/student_watch_repository.dart'
    show PlaybackAuthorizationException, PlaybackProviderIncompatibleException;

/// واجهة موحدة تفصل طبقة العرض (UI Widgets) عن تفاصيل التشغيل والتقدم (Laravel) والتكليفات (P6).
abstract class StudentLearningRepository {
  // --- P6 Assignments (retained until P6 migration) ---
  Stream<List<Assignment>> streamCourseAssignments(String courseId);
  Stream<List<AssignmentSubmission>> streamStudentSubmissions(String studentId);
  Future<List<AssignmentSubmission>> getStudentSubmissions(String studentId);
  Future<Assignment?> getAssignment(String assignmentId);
  Future<void> submitAssignment({
    required AssignmentSubmission submission,
    File? attachmentFile,
  });

  // --- P5 Video Playback & Progress (Laravel REST API) ---
  Future<ResolvedLessonPlayback> resolveLessonPlayback({
    required String courseId,
    required Lesson lesson,
  });

  Future<PlaybackTokenResponse> refreshPlaybackToken({
    required String courseSlugOrId,
    required String lessonSlugOrId,
  });

  Future<WatchProgressResult> recordLessonProgress({
    required String courseSlugOrId,
    required String lessonSlugOrId,
    required int watchedSeconds,
    required int positionSeconds,
    bool? isCompleted,
  });

  Future<void> toggleLessonCompletion({
    required String courseSlugOrId,
    required Lesson lesson,
    required bool isCompleted,
  });
}

class StudentLearningRepositoryImpl implements StudentLearningRepository {
  final FirestoreService _firestoreService;
  final StorageService _storageService;
  final StudentWatchRepository? _watchRepository;
  final Map<String, Stream<List<AssignmentSubmission>>> _submissionStreams = {};

  StudentLearningRepositoryImpl({
    FirestoreService? firestoreService,
    StorageService? storageService,
    StudentWatchRepository? watchRepository,
  })  : _firestoreService = firestoreService ?? FirestoreService(),
        _storageService = storageService ?? StorageService(),
        _watchRepository = watchRepository;

  StudentWatchRepository get _watchRepo {
    if (_watchRepository != null) return _watchRepository;
    if (sl.isRegistered<StudentWatchRepository>()) {
      return sl<StudentWatchRepository>();
    }
    throw StateError('StudentWatchRepository is not registered in GetIt.');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // P6 ASSIGNMENTS (retained cleanly until P6)
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Stream<List<Assignment>> streamCourseAssignments(String courseId) {
    return _firestoreService.streamCourseAssignments(courseId);
  }

  @override
  Stream<List<AssignmentSubmission>> streamStudentSubmissions(
    String studentId,
  ) {
    return _submissionStreams.putIfAbsent(studentId, () {
      return _firestoreService
          .streamStudentSubmissions(studentId)
          .asBroadcastStream(onCancel: (sub) {
        _submissionStreams.remove(studentId);
        sub.cancel();
      });
    });
  }

  @override
  Future<List<AssignmentSubmission>> getStudentSubmissions(String studentId) {
    return _firestoreService.getStudentSubmissions(studentId);
  }

  @override
  Future<Assignment?> getAssignment(String assignmentId) {
    return _firestoreService.getAssignment(assignmentId);
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
            onTimeout: () => throw TimeoutException(
              'استغرق رفع المرفق وقتاً طويلاً. تأكد من سرعة اتصالك بالإنترنت.',
            ),
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
          onTimeout: () => throw TimeoutException(
            'استغرق حفظ بيانات التكليف وقتاً طويلاً. تأكد من اتصالك بالإنترنت.',
          ),
        );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // P5 PROTECTED PLAYBACK & PROGRESS (Laravel REST API ONLY — ZERO FIREBASE)
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Future<ResolvedLessonPlayback> resolveLessonPlayback({
    required String courseId,
    required Lesson lesson,
  }) async {
    return await _watchRepo.resolveLessonPlayback(
      courseSlugOrId: courseId,
      lesson: lesson,
    );
  }

  @override
  Future<PlaybackTokenResponse> refreshPlaybackToken({
    required String courseSlugOrId,
    required String lessonSlugOrId,
  }) async {
    return await _watchRepo.refreshPlaybackToken(
      courseSlugOrId: courseSlugOrId,
      lessonSlugOrId: lessonSlugOrId,
    );
  }

  @override
  Future<WatchProgressResult> recordLessonProgress({
    required String courseSlugOrId,
    required String lessonSlugOrId,
    required int watchedSeconds,
    required int positionSeconds,
    bool? isCompleted,
  }) async {
    return await _watchRepo.recordLessonProgress(
      courseSlugOrId: courseSlugOrId,
      lessonSlugOrId: lessonSlugOrId,
      watchedSeconds: watchedSeconds,
      positionSeconds: positionSeconds,
      isCompleted: isCompleted,
    );
  }

  @override
  Future<void> toggleLessonCompletion({
    required String courseSlugOrId,
    required Lesson lesson,
    required bool isCompleted,
  }) async {
    final lessonKey = (lesson.slug != null && lesson.slug!.trim().isNotEmpty)
        ? lesson.slug!.trim()
        : lesson.id;
    final durSec = lesson.durationInSeconds;
    await _watchRepo.recordLessonProgress(
      courseSlugOrId: courseSlugOrId,
      lessonSlugOrId: lessonKey,
      watchedSeconds: lesson.watchedSeconds > 0 ? lesson.watchedSeconds : durSec,
      positionSeconds: durSec,
      isCompleted: isCompleted,
    );
  }
}

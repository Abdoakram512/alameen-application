import 'dart:async';
import 'dart:io';
import '../core/di/injection_container.dart';
import '../models/assignment.dart';
import '../models/assignment_submission.dart';
import '../models/lesson.dart';
import '../models/lesson_playback_data.dart';
import '../repositories/impl/student_assignments_repository_impl.dart';
import '../repositories/student_assignments_repository.dart';
import '../repositories/student_watch_repository.dart';

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
  final StudentAssignmentsRepository? _assignmentsRepository;
  final StudentWatchRepository? _watchRepository;

  StudentLearningRepositoryImpl({
    StudentAssignmentsRepository? assignmentsRepository,
    StudentWatchRepository? watchRepository,
    dynamic firestoreService,
    dynamic storageService,
  })  : _assignmentsRepository = assignmentsRepository,
        _watchRepository = watchRepository;

  StudentAssignmentsRepository get _assignmentsRepo {
    if (_assignmentsRepository != null) return _assignmentsRepository;
    if (sl.isRegistered<StudentAssignmentsRepository>()) {
      return sl<StudentAssignmentsRepository>();
    }
    return StudentAssignmentsRepositoryImpl();
  }

  StudentWatchRepository get _watchRepo {
    if (_watchRepository != null) return _watchRepository;
    if (sl.isRegistered<StudentWatchRepository>()) {
      return sl<StudentWatchRepository>();
    }
    throw StateError('StudentWatchRepository is not registered in GetIt.');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // P6 ASSIGNMENTS (Laravel REST API ONLY — ZERO FIREBASE)
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Stream<List<Assignment>> streamCourseAssignments(String courseId) {
    return _assignmentsRepo.streamCourseAssignments(courseId);
  }

  @override
  Stream<List<AssignmentSubmission>> streamStudentSubmissions(
    String studentId,
  ) {
    return _assignmentsRepo.streamStudentSubmissions(studentId);
  }

  @override
  Future<List<AssignmentSubmission>> getStudentSubmissions(String studentId) {
    return _assignmentsRepo.getStudentSubmissions(studentId);
  }

  @override
  Future<Assignment?> getAssignment(String assignmentId) {
    return _assignmentsRepo.getAssignment(assignmentId);
  }

  @override
  Future<void> submitAssignment({
    required AssignmentSubmission submission,
    File? attachmentFile,
  }) async {
    await _assignmentsRepo.submitAssignment(
      submission: submission,
      attachmentFile: attachmentFile,
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

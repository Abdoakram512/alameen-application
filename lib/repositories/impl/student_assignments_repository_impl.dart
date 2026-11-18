import 'dart:async';
import 'dart:io';
import '../../core/di/injection_container.dart';
import '../../datasources/assignments_remote_data_source.dart';
import '../../models/assignment.dart';
import '../../models/assignment_submission.dart';
import '../../models/clinical_task_data.dart';
import '../student_assignments_repository.dart';

class StudentAssignmentsRepositoryImpl implements StudentAssignmentsRepository {
  final AssignmentsRemoteDataSource? _remoteDataSource;

  final StreamController<List<Assignment>> _assignmentsStreamController =
      StreamController<List<Assignment>>.broadcast();
  final StreamController<List<AssignmentSubmission>> _submissionsStreamController =
      StreamController<List<AssignmentSubmission>>.broadcast();

  List<Assignment> _cachedTasks = const [];
  List<AssignmentSubmission> _cachedSubmissions = const [];

  StudentAssignmentsRepositoryImpl({
    AssignmentsRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  AssignmentsRemoteDataSource get _remote {
    if (_remoteDataSource != null) return _remoteDataSource;
    if (sl.isRegistered<AssignmentsRemoteDataSource>()) {
      return sl<AssignmentsRemoteDataSource>();
    }
    throw StateError('AssignmentsRemoteDataSource is not registered in GetIt.');
  }

  int _parseTaskId(String rawId) {
    final direct = int.tryParse(rawId.trim());
    if (direct != null && direct > 0) return direct;
    final match = RegExp(r'(\d+)').firstMatch(rawId);
    if (match != null) {
      final parsed = int.tryParse(match.group(1)!);
      if (parsed != null && parsed > 0) return parsed;
    }
    return 1;
  }

  @override
  Future<StudentAssignmentsData> getAssignments() async {
    final data = await _remote.getAssignments();
    _cachedTasks = data.tasks;
    _cachedSubmissions = data.submissions;
    if (!_assignmentsStreamController.isClosed) {
      _assignmentsStreamController.add(_cachedTasks);
    }
    if (!_submissionsStreamController.isClosed) {
      _submissionsStreamController.add(_cachedSubmissions);
    }
    return data;
  }

  @override
  Future<ClinicalTaskDetails> getAssignmentDetails(int taskId) async {
    return await _remote.getAssignmentDetails(taskId);
  }

  @override
  Future<AssignmentSubmission> submitClinicalTask({
    required int taskId,
    File? audioFile,
    String? audioBase64,
    int? durationSeconds,
    String? studentNotes,
  }) async {
    final submission = await _remote.submitAssignment(
      taskId: taskId,
      audioFile: audioFile,
      audioBase64: audioBase64,
      durationSeconds: durationSeconds,
      studentNotes: studentNotes,
    );

    // تحديث الذاكرة المؤقتة والبث الحي
    final updated = List<AssignmentSubmission>.from(_cachedSubmissions);
    final existingIdx = updated.indexWhere(
      (s) => s.id == submission.id || s.assignmentId == submission.assignmentId,
    );
    if (existingIdx >= 0) {
      updated[existingIdx] = submission;
    } else {
      updated.insert(0, submission);
    }
    _cachedSubmissions = updated;
    if (!_submissionsStreamController.isClosed) {
      _submissionsStreamController.add(_cachedSubmissions);
    }

    return submission;
  }

  @override
  Future<StudentGradesData> getStudentGrades() async {
    final grades = await _remote.getStudentGrades();
    if (grades.submissions.isNotEmpty) {
      _cachedSubmissions = grades.submissions;
      if (!_submissionsStreamController.isClosed) {
        _submissionsStreamController.add(_cachedSubmissions);
      }
    }
    return grades;
  }

  @override
  Future<AssignmentSubmission> getSubmissionDetails(int submissionId) async {
    return await _remote.getSubmissionDetails(submissionId);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // توافق الواجهات مع شاشات التطبيق الحالية (Laravel REST API حصراً - صفر Firebase)
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Stream<List<Assignment>> streamCourseAssignments(String courseId) {
    if (_cachedTasks.isEmpty) {
      getAssignments().catchError((_) => const StudentAssignmentsData());
    }
    return _assignmentsStreamController.stream.map((tasks) {
      if (courseId.trim().isEmpty) return tasks;
      return tasks.where((t) => t.courseId == courseId).toList();
    });
  }

  @override
  Future<Assignment?> getAssignment(String assignmentId) async {
    final taskId = _parseTaskId(assignmentId);
    try {
      final details = await getAssignmentDetails(taskId);
      return details.task;
    } catch (_) {
      for (final t in _cachedTasks) {
        if (t.id == assignmentId || t.id == taskId.toString()) {
          return t;
        }
      }
      return null;
    }
  }

  @override
  Stream<List<AssignmentSubmission>> streamStudentSubmissions(String studentId) {
    if (_cachedSubmissions.isEmpty) {
      getAssignments().catchError((_) => const StudentAssignmentsData());
    }
    return _submissionsStreamController.stream;
  }

  @override
  Future<List<AssignmentSubmission>> getStudentSubmissions(String studentId) async {
    if (_cachedSubmissions.isNotEmpty) {
      return _cachedSubmissions;
    }
    try {
      final data = await getAssignments();
      return data.submissions;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<AssignmentSubmission> submitAssignment({
    required AssignmentSubmission submission,
    File? attachmentFile,
  }) async {
    final taskId = _parseTaskId(submission.assignmentId);
    return await submitClinicalTask(
      taskId: taskId,
      audioFile: attachmentFile,
      studentNotes: submission.solutionText.isNotEmpty
          ? submission.solutionText
          : submission.attachmentUrl,
    );
  }
}

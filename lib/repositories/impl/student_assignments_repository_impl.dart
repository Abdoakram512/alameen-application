import 'dart:async';
import 'dart:io';
import '../../core/di/injection_container.dart';
import '../../datasources/assignments_remote_data_source.dart';
import '../../models/assignment.dart';
import '../../models/assignment_submission.dart';
import '../../models/clinical_task_data.dart';
import '../student_assignments_repository.dart';

class UnsupportedFileAttachmentException implements Exception {
  final String message;
  final String fileName;
  const UnsupportedFileAttachmentException(this.message, {this.fileName = ''});

  @override
  String toString() => message;
}

class StudentAssignmentsRepositoryImpl implements StudentAssignmentsRepository {
  final AssignmentsRemoteDataSource? _remoteDataSource;

  // ملاحظة معمارية هامة:
  // هذه التدفقات (StreamControllers) توفر تحديثات تفاعلية محلية للواجهة (Reactive UI Updates)
  // عقب إتمام استدعاءات REST والتحديث المحلي في الذاكرة، وليست بثاً خادمياً لحظياً (Server Push).
  final StreamController<List<Assignment>> _assignmentsStreamController =
      StreamController<List<Assignment>>.broadcast();
  final StreamController<List<AssignmentSubmission>>
  _submissionsStreamController =
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
    throw ArgumentError.value(
      rawId,
      'taskId',
      'Expected a positive Laravel task ID',
    );
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
    if (taskId <= 0) throw ArgumentError.value(taskId, 'taskId');
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
    if (taskId <= 0) throw ArgumentError.value(taskId, 'taskId');
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
    final details = await getAssignmentDetails(taskId);
    return details.task;
  }

  @override
  Stream<List<AssignmentSubmission>> streamStudentSubmissions(
    String studentId,
  ) {
    if (_cachedSubmissions.isEmpty) {
      getAssignments().catchError((_) => const StudentAssignmentsData());
    }
    return _submissionsStreamController.stream;
  }

  @override
  Future<List<AssignmentSubmission>> getStudentSubmissions(
    String studentId,
  ) async {
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

    File? audioFile;
    if (attachmentFile != null) {
      final ext = attachmentFile.path.split('.').last.toLowerCase();
      const supportedAudioExts = {'m4a', 'mp3', 'wav', 'ogg', 'webm', 'aac'};
      if (supportedAudioExts.contains(ext)) {
        audioFile = attachmentFile;
      } else {
        throw UnsupportedFileAttachmentException(
          'رفع ملفات الصور والمستندات ($ext) غير مدعوم حالياً في واجهة خادم المنصة؛ حيث تقبل المهام السريرية ملفات التسجيل الصوتي فقط (m4a, mp3, wav). يرجى إدراج رابط الملف الخارجي (مثل Google Drive) أو إرسال تسجيل صوتي.',
          fileName: attachmentFile.path.split(Platform.pathSeparator).last,
        );
      }
    }

    final notesBuffer = StringBuffer();
    if (submission.solutionText.trim().isNotEmpty) {
      notesBuffer.write(submission.solutionText.trim());
    }
    if (submission.attachmentUrl.trim().isNotEmpty) {
      if (notesBuffer.isNotEmpty) notesBuffer.write('\n\n');
      notesBuffer.write(
        'رابط المرفق الخارجي: ${submission.attachmentUrl.trim()}',
      );
    }

    return await submitClinicalTask(
      taskId: taskId,
      audioFile: audioFile,
      studentNotes: notesBuffer.isNotEmpty ? notesBuffer.toString() : null,
    );
  }
}

import 'dart:io';
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../models/assignment_submission.dart';
import '../models/clinical_task_data.dart';

/// واجهة مصدر البيانات البعيد للتكليفات السريرية والواجبات الصوتية وتقييمات الطلاب عبر Laravel REST API.
abstract class AssignmentsRemoteDataSource {
  /// GET /student/assignments
  Future<StudentAssignmentsData> getAssignments();

  /// GET /student/assignments/{task}
  Future<ClinicalTaskDetails> getAssignmentDetails(int taskId);

  /// POST /student/assignments/{task}/submit
  Future<AssignmentSubmission> submitAssignment({
    required int taskId,
    File? audioFile,
    String? audioBase64,
    int? durationSeconds,
    String? studentNotes,
  });

  /// GET /student/grades
  Future<StudentGradesData> getStudentGrades();

  /// GET /student/submissions/{submission}
  Future<AssignmentSubmission> getSubmissionDetails(int submissionId);
}

class AssignmentsRemoteDataSourceImpl implements AssignmentsRemoteDataSource {
  final ApiClient _apiClient;

  AssignmentsRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<StudentAssignmentsData> getAssignments() async {
    try {
      final response = await _apiClient.get('/student/assignments');
      final raw = response.data;
      if (raw is Map<String, dynamic>) {
        return StudentAssignmentsData.fromJson(raw);
      }
      throw const ApiException(
        'تعذر قراءة قائمة التكليفات من الخادم.',
        statusCode: 500,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<ClinicalTaskDetails> getAssignmentDetails(int taskId) async {
    try {
      final response = await _apiClient.get('/student/assignments/$taskId');
      final raw = response.data;
      if (raw is Map<String, dynamic>) {
        return ClinicalTaskDetails.fromJson(raw);
      }
      throw const ApiException(
        'تعذر قراءة تفاصيل التكليف من الخادم.',
        statusCode: 500,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<AssignmentSubmission> submitAssignment({
    required int taskId,
    File? audioFile,
    String? audioBase64,
    int? durationSeconds,
    String? studentNotes,
  }) async {
    try {
      final formMap = <String, dynamic>{};

      if (audioFile != null && await audioFile.exists()) {
        final fileName = audioFile.path.split(Platform.pathSeparator).last;
        formMap['audio_file'] = await MultipartFile.fromFile(
          audioFile.path,
          filename: fileName,
        );
      } else if (audioBase64 != null && audioBase64.trim().isNotEmpty) {
        formMap['audio_base64'] = audioBase64.trim();
      }

      if (durationSeconds != null && durationSeconds > 0) {
        formMap['duration_seconds'] = durationSeconds;
      }

      if (studentNotes != null && studentNotes.trim().isNotEmpty) {
        formMap['student_notes'] = studentNotes.trim();
      }

      final formData = FormData.fromMap(formMap);
      final response = await _apiClient.post(
        '/student/assignments/$taskId/submit',
        data: formData,
      );

      final raw = response.data;
      if (raw is Map<String, dynamic>) {
        final data = raw['data'] is Map ? raw['data'] as Map : raw;
        final subMap = data['submission'] is Map
            ? Map<String, dynamic>.from(data['submission'] as Map)
            : Map<String, dynamic>.from(data);
        return AssignmentSubmission.fromLaravelJson(subMap);
      }

      throw const ApiException(
        'تعذر تسجيل تسليم التكليف على الخادم.',
        statusCode: 500,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<StudentGradesData> getStudentGrades() async {
    try {
      final response = await _apiClient.get('/student/grades');
      final raw = response.data;
      if (raw is Map<String, dynamic>) {
        return StudentGradesData.fromJson(raw);
      }
      throw const ApiException(
        'تعذر قراءة سجل تقييمات الطالب من الخادم.',
        statusCode: 500,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<AssignmentSubmission> getSubmissionDetails(int submissionId) async {
    try {
      final response = await _apiClient.get('/student/submissions/$submissionId');
      final raw = response.data;
      if (raw is Map<String, dynamic>) {
        final data = raw['data'] is Map ? raw['data'] as Map : raw;
        final subMap = data['submission'] is Map
            ? Map<String, dynamic>.from(data['submission'] as Map)
            : Map<String, dynamic>.from(data);
        return AssignmentSubmission.fromLaravelJson(subMap);
      }
      throw const ApiException(
        'تعذر قراءة تفاصيل التقييم من الخادم.',
        statusCode: 500,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

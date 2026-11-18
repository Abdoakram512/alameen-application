import 'dart:io';
import '../models/assignment.dart';
import '../models/assignment_submission.dart';
import '../models/clinical_task_data.dart';

abstract class StudentAssignmentsRepository {
  /// جلب كافة التكليفات السريرية والتسليمات الخاصة بالطالب عبر Laravel REST API.
  /// GET /student/assignments
  Future<StudentAssignmentsData> getAssignments();

  /// جلب تفاصيل تكليف سريري محدد وأحدث تسليم له عبر Laravel REST API.
  /// GET /student/assignments/{task}
  Future<ClinicalTaskDetails> getAssignmentDetails(int taskId);

  /// إرسال تسليم المهمة السريرية (ملف صوتي multipart أو نصي) عبر Laravel REST API.
  /// POST /student/assignments/{task}/submit
  Future<AssignmentSubmission> submitClinicalTask({
    required int taskId,
    File? audioFile,
    String? audioBase64,
    int? durationSeconds,
    String? studentNotes,
  });

  /// جلب ملخص تقييمات الطالب ودرجاته عبر Laravel REST API.
  /// GET /student/grades
  Future<StudentGradesData> getStudentGrades();

  /// جلب تفاصيل تقييم تسليم محدد وملاحظات المشرف السريري عبر Laravel REST API.
  /// GET /student/submissions/{submission}
  Future<AssignmentSubmission> getSubmissionDetails(int submissionId);

  // --- واجهات التوافق مع الشاشات الحالية (دون أي اعتماد على Firestore) ---
  Stream<List<Assignment>> streamCourseAssignments(String courseId);
  Future<Assignment?> getAssignment(String assignmentId);
  Stream<List<AssignmentSubmission>> streamStudentSubmissions(String studentId);
  Future<List<AssignmentSubmission>> getStudentSubmissions(String studentId);
  Future<AssignmentSubmission> submitAssignment({
    required AssignmentSubmission submission,
    File? attachmentFile,
  });
}

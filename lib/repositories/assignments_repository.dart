import '../models/assignment.dart';
import '../models/assignment_submission.dart';

abstract class AssignmentsRepository {
  Stream<List<Assignment>> streamAllAssignments();
  Stream<List<Assignment>> streamCourseAssignments(String courseId);
  Stream<List<AssignmentSubmission>> streamAllSubmissions();
  Stream<List<AssignmentSubmission>> streamPendingSubmissions();
  Stream<List<AssignmentSubmission>> streamStudentSubmissions(String studentId);
  Future<List<AssignmentSubmission>> getCourseSubmissions(String courseId);
  Future<void> saveAssignment(Assignment assignment);
  Future<void> deleteAssignment(String assignmentId);
  Future<void> sendSubmissionFeedback({
    required String submissionId,
    required String feedback,
  });
  Future<void> gradeSubmission({
    required String submissionId,
    required double grade,
    String? feedback,
  });
}

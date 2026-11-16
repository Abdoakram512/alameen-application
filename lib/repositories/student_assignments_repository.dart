import '../models/assignment.dart';
import '../models/assignment_submission.dart';

abstract class StudentAssignmentsRepository {
  Stream<List<Assignment>> streamCourseAssignments(String courseId);
  Future<Assignment?> getAssignment(String assignmentId);
  Stream<List<AssignmentSubmission>> streamStudentSubmissions(String studentId);
  Future<List<AssignmentSubmission>> getStudentSubmissions(String studentId);
  Future<void> submitAssignment(AssignmentSubmission submission);
}

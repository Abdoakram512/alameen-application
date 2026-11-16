import '../models/access_request.dart';

abstract class RequestsRepository {
  Stream<List<CourseAccessRequest>> streamRequests();
  Stream<List<CourseAccessRequest>> streamStudentRequests(String studentId);
  Future<void> approveRequest(String requestId, String studentId, String courseId, {String? levelId});
  Future<void> rejectRequest(String requestId, {String adminNotes = ''});
}


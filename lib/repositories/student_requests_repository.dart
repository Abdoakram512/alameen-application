import '../models/access_request.dart';

abstract class StudentRequestsRepository {
  Stream<List<CourseAccessRequest>> streamStudentRequests(String studentId);
  Future<void> sendAccessRequest(CourseAccessRequest request);
}

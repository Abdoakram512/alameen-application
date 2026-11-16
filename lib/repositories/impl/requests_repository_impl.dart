import '../../models/access_request.dart';
import '../../services/firestore_service.dart';
import '../requests_repository.dart';

class RequestsRepositoryImpl implements RequestsRepository {
  final FirestoreService _firestoreService;

  RequestsRepositoryImpl({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  @override
  Stream<List<CourseAccessRequest>> streamRequests() {
    return _firestoreService.streamRequests();
  }

  @override
  Stream<List<CourseAccessRequest>> streamStudentRequests(String studentId) {
    return _firestoreService.streamStudentRequests(studentId);
  }

  @override
  Future<void> approveRequest(String requestId, String studentId, String courseId) {
    return _firestoreService.approveRequest(requestId, studentId, courseId);
  }

  @override
  Future<void> rejectRequest(String requestId, {String adminNotes = ''}) {
    return _firestoreService.rejectRequest(requestId, adminNotes: adminNotes);
  }
}


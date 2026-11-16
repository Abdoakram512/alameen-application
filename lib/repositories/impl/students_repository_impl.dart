import '../../models/registered_student.dart';
import '../../services/firestore_service.dart';
import '../students_repository.dart';

class StudentsRepositoryImpl implements StudentsRepository {
  final FirestoreService _firestoreService;

  StudentsRepositoryImpl({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  @override
  Stream<List<RegisteredStudent>> streamStudents() {
    return _firestoreService.streamStudents();
  }

  @override
  Future<void> toggleStudentCourse(String studentId, String courseId, bool grant) {
    return _firestoreService.toggleStudentCourse(studentId, courseId, grant);
  }

  @override
  Future<void> toggleStudentSuspension(String studentId, {required bool suspend, String? reason}) {
    return _firestoreService.toggleStudentSuspension(studentId, suspend: suspend, reason: reason);
  }

  @override
  Future<void> deleteStudentAccount(String studentId) {
    return _firestoreService.deleteStudentAccount(studentId);
  }
}


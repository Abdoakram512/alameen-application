import '../models/registered_student.dart';

abstract class StudentsRepository {
  Stream<List<RegisteredStudent>> streamStudents();
  Future<void> toggleStudentCourse(String studentId, String courseId, bool grant);
  Future<void> toggleStudentSuspension(String studentId, {required bool suspend, String? reason});
  Future<void> deleteStudentAccount(String studentId);
}


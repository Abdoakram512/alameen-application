import '../models/registered_student.dart';

abstract class StudentsRepository {
  Stream<List<RegisteredStudent>> streamStudents();
  Future<List<RegisteredStudent>> getStudents({bool forceRefresh = false});
  Future<int> getStudentsCount();
  Future<void> toggleStudentCourse(String studentId, String courseId, bool grant);
  Future<void> toggleStudentSuspension(String studentId, {required bool suspend, String? reason});
  Future<void> deleteStudentAccount(String studentId);

  Future<int> assignStudentsToCourse({
    required String courseId,
    required List<String> studentIds,
    required bool grant,
  });

  Future<int> extendCourseValidityForAll({
    required String courseId,
    required int additionalDays,
  });

  Future<void> extendStudentCourseValidity({
    required String studentId,
    required String courseId,
    required int additionalDays,
  });

  Future<int> revokeCourseAccessForAll(String courseId);

  Future<void> bulkSuspendStudents({
    required List<String> studentIds,
    required bool suspend,
    String? reason,
  });

  Future<void> bulkDeleteStudents(List<String> studentIds);
}

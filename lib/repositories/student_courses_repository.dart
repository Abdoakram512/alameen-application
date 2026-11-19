import '../models/course.dart';
import '../models/student_courses_data.dart';
import '../models/student_dashboard_data.dart';

abstract class StudentCoursesRepository {
  /// Stream of courses for UI real-time binding
  Stream<List<Course>> streamCourses();

  /// Retrieve all available courses
  Future<List<Course>> getCourses();

  /// Retrieve public catalog courses from REST API
  Future<List<Course>> getPublicCourses({String? search, bool forceRefresh = false});

  /// Retrieve detailed course curriculum and structure by slug or id
  Future<Course> getCourseDetails(String slugOrId);

  /// Retrieve strictly server-authenticated course entitlement details without public or cache fallback.
  Future<Course> verifyStudentCourseDetails(String slugOrId);

  /// Retrieve student personalized learning dashboard
  Future<StudentDashboardData> getStudentDashboard();

  /// Retrieve student enrolled courses and progress
  Future<StudentCoursesData> getStudentCourses();
}

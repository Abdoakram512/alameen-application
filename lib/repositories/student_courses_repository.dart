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

  /// Retrieve student personalized learning dashboard
  Future<StudentDashboardData> getStudentDashboard();

  /// Retrieve student enrolled courses and progress
  Future<StudentCoursesData> getStudentCourses();

  /// Fetch protected lesson playback ID (legacy Firestore vault or future REST endpoint)
  Future<String?> fetchProtectedLessonPlaybackId({
    required String courseId,
    required String lessonId,
  });

  /// Direct open course enrollment
  Future<void> enrollInOpenCourse(String uid, String courseId);
}

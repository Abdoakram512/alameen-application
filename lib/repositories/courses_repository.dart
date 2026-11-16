import '../models/assignment.dart';
import '../models/course.dart';
import '../models/course_access_mode.dart';
import '../models/course_level.dart';
import '../models/lesson.dart';

abstract class CoursesRepository {
  Stream<List<Course>> streamCourses();
  Future<void> saveCourse(Course course);
  Future<void> deleteCourse(String courseId);
  Future<void> addLevelToCourse(String courseId, CourseLevel level);
  Future<void> deleteLevelFromCourse(String courseId, String levelId);

  /// إضافة درس، مع إمكانية إرفاق تكليف يُحفظ معه ذرّياً.
  Future<void> addLessonToLevel(
    String courseId,
    String levelId,
    Lesson lesson, {
    Assignment? assignment,
  });
  Future<void> deleteLessonFromLevel(String courseId, String levelId, String lessonId);

  Future<void> updateLessonVideoStatus(
    String courseId,
    String levelId,
    String lessonId, {
    required String videoStatus,
    double? videoProgress,
    String? duration,
    String? videoErrorMessage,
  });

  Future<void> updateLessonPublishStatus(
    String courseId,
    String levelId,
    String lessonId, {
    required bool isPublished,
    DateTime? scheduledPublishAt,
  });

  Future<void> setCourseAccessMode(String courseId, CourseAccessMode mode);

  /// تعيين/إلغاء تعيين طلاب لكورس. يعيد عدد من تغيّرت حالته فعلاً.
  Future<int> assignStudents({
    required String courseId,
    required List<String> studentIds,
    required bool grant,
  });
}

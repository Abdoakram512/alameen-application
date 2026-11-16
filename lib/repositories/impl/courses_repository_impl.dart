import '../../models/assignment.dart';
import '../../models/course.dart';
import '../../models/course_access_mode.dart';
import '../../models/course_level.dart';
import '../../models/lesson.dart';
import '../../services/firestore_service.dart';
import '../courses_repository.dart';

class CoursesRepositoryImpl implements CoursesRepository {
  final FirestoreService _firestoreService;

  CoursesRepositoryImpl({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  @override
  Stream<List<Course>> streamCourses() {
    return _firestoreService.streamCourses();
  }

  @override
  Future<void> saveCourse(Course course) {
    return _firestoreService.saveCourse(course);
  }

  @override
  Future<void> deleteCourse(String courseId) {
    return _firestoreService.deleteCourse(courseId);
  }

  @override
  Future<void> addLevelToCourse(String courseId, CourseLevel level) {
    return _firestoreService.addLevelToCourse(courseId, level);
  }

  @override
  Future<void> deleteLevelFromCourse(String courseId, String levelId) {
    return _firestoreService.deleteLevelFromCourse(courseId, levelId);
  }

  @override
  Future<void> addLessonToLevel(
    String courseId,
    String levelId,
    Lesson lesson, {
    Assignment? assignment,
  }) {
    return _firestoreService.addLessonToLevel(
      courseId,
      levelId,
      lesson,
      assignment: assignment,
    );
  }

  @override
  Future<void> deleteLessonFromLevel(String courseId, String levelId, String lessonId) {
    return _firestoreService.deleteLessonFromLevel(courseId, levelId, lessonId);
  }

  @override
  Future<void> updateLessonVideoStatus(
    String courseId,
    String levelId,
    String lessonId, {
    required String videoStatus,
    double? videoProgress,
    String? duration,
    String? videoErrorMessage,
  }) {
    return _firestoreService.updateLessonVideoStatus(
      courseId,
      levelId,
      lessonId,
      videoStatus: videoStatus,
      videoProgress: videoProgress,
      duration: duration,
      videoErrorMessage: videoErrorMessage,
    );
  }

  @override
  Future<void> updateLessonPublishStatus(
    String courseId,
    String levelId,
    String lessonId, {
    required bool isPublished,
    DateTime? scheduledPublishAt,
  }) {
    return _firestoreService.updateLessonPublishStatus(
      courseId,
      levelId,
      lessonId,
      isPublished: isPublished,
      scheduledPublishAt: scheduledPublishAt,
    );
  }

  @override
  Future<void> setCourseAccessMode(String courseId, CourseAccessMode mode) {
    return _firestoreService.setCourseAccessMode(courseId, mode);
  }

  @override
  Future<int> assignStudents({
    required String courseId,
    required List<String> studentIds,
    required bool grant,
  }) {
    return _firestoreService.assignStudentsToCourse(
      courseId: courseId,
      studentIds: studentIds,
      grant: grant,
    );
  }
}

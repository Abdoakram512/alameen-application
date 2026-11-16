import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course.dart';

abstract class StudentCoursesRepository {
  Stream<List<Course>> streamCourses();
  Future<List<Course>> getCourses({Source source = Source.serverAndCache});
  Future<String?> fetchProtectedLessonPlaybackId({
    required String courseId,
    required String lessonId,
  });
  Future<void> enrollInOpenCourse(String uid, String courseId);
}

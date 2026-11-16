import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/course.dart';
import '../../models/course_level.dart';
import '../../models/lesson.dart';
import '../student_courses_repository.dart';

class StudentCoursesRepositoryImpl implements StudentCoursesRepository {
  final FirebaseFirestore? _explicitFirestore;

  StudentCoursesRepositoryImpl({FirebaseFirestore? firestore})
      : _explicitFirestore = firestore;

  bool get isAvailable {
    try {
      final _ = db;
      return true;
    } catch (_) {
      return false;
    }
  }

  FirebaseFirestore get db => _explicitFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _coursesRef =>
      db.collection('courses');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      db.collection('users');

  @override
  Stream<List<Course>> streamCourses() {
    if (!isAvailable) return Stream.value(const <Course>[]);
    return _coursesRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        final course = Course.fromMap(data);

        // Strict ordering for levels and lessons
        final sortedLevels = List<CourseLevel>.from(course.levels)
          ..sort((a, b) => a.order.compareTo(b.order));
        final finalLevels = sortedLevels.map((lvl) {
          final sortedLessons = List<Lesson>.from(lvl.lessons)
            ..sort((a, b) => a.order.compareTo(b.order));
          return lvl.copyWith(lessons: sortedLessons);
        }).toList();

        return course.copyWith(levels: finalLevels);
      }).toList();
    });
  }

  @override
  Future<List<Course>> getCourses({
    Source source = Source.serverAndCache,
  }) async {
    if (!isAvailable) return const [];
    try {
      final snapshot = await _coursesRef.get(GetOptions(source: source));
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        final course = Course.fromMap(data);

        final sortedLevels = List<CourseLevel>.from(course.levels)
          ..sort((a, b) => a.order.compareTo(b.order));
        final finalLevels = sortedLevels.map((lvl) {
          final sortedLessons = List<Lesson>.from(lvl.lessons)
            ..sort((a, b) => a.order.compareTo(b.order));
          return lvl.copyWith(lessons: sortedLessons);
        }).toList();

        return course.copyWith(levels: finalLevels);
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<String?> fetchProtectedLessonPlaybackId({
    required String courseId,
    required String lessonId,
  }) async {
    if (!isAvailable) return null;
    try {
      final doc = await _coursesRef
          .doc(courseId)
          .collection('protected_lessons')
          .doc(lessonId)
          .get();
      final playbackId = (doc.data()?['muxPlaybackId'] as String?)?.trim();
      if (playbackId == null || playbackId.isEmpty) return null;
      return playbackId;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> enrollInOpenCourse(String uid, String courseId) async {
    if (!isAvailable) return;
    await _usersRef.doc(uid).set(
      {
        'enrolledCourseIds': FieldValue.arrayUnion([courseId]),
        'lastEnrolledCourseId': courseId,
      },
      SetOptions(merge: true),
    );
    try {
      await _coursesRef.doc(courseId).set(
        {
          'enrolledCount': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }
}

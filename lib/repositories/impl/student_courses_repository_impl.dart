import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/di/injection_container.dart';
import '../../datasources/courses_remote_data_source.dart';
import '../../models/course.dart';
import '../../models/course_level.dart';
import '../../models/lesson.dart';
import '../../models/student_courses_data.dart';
import '../../models/student_dashboard_data.dart';
import '../student_courses_repository.dart';

class StudentCoursesRepositoryImpl implements StudentCoursesRepository {
  final CoursesRemoteDataSource? _remoteDataSource;
  final FirebaseFirestore? _explicitFirestore;
  final StreamController<List<Course>> _coursesStreamController =
      StreamController<List<Course>>.broadcast();

  List<Course> _cachedCourses = const [];

  StudentCoursesRepositoryImpl({
    CoursesRemoteDataSource? remoteDataSource,
    FirebaseFirestore? firestore,
  })  : _remoteDataSource = remoteDataSource,
        _explicitFirestore = firestore;

  CoursesRemoteDataSource? get _remote {
    if (_remoteDataSource != null) return _remoteDataSource;
    if (sl.isRegistered<CoursesRemoteDataSource>()) {
      return sl<CoursesRemoteDataSource>();
    }
    return null;
  }

  bool get isFirestoreAvailable {
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
    // If we have cached courses, emit immediately
    if (_cachedCourses.isNotEmpty) {
      scheduleMicrotask(() {
        if (!_coursesStreamController.isClosed) {
          _coursesStreamController.add(_cachedCourses);
        }
      });
    }

    // Trigger async fetch from REST API to refresh stream
    getCourses().then((courses) {
      if (!_coursesStreamController.isClosed && courses.isNotEmpty) {
        _coursesStreamController.add(courses);
      }
    }).catchError((_) {});

    // If Firestore is available, also listen for real-time legacy changes
    if (isFirestoreAvailable) {
      _coursesRef.snapshots().listen(
        (snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final courses = snapshot.docs.map((doc) {
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

            _cachedCourses = courses;
            if (!_coursesStreamController.isClosed) {
              _coursesStreamController.add(courses);
            }
          }
        },
        onError: (_) {},
      );
    }

    return _coursesStreamController.stream;
  }

  @override
  Future<List<Course>> getCourses({
    Source source = Source.serverAndCache,
  }) async {
    // 1. Primary: Attempt to fetch from Laravel REST API
    final remote = _remote;
    if (remote != null) {
      try {
        final remoteCourses = await remote.getPublicCourses();
        if (remoteCourses.isNotEmpty) {
          _cachedCourses = remoteCourses;
          if (!_coursesStreamController.isClosed) {
            _coursesStreamController.add(remoteCourses);
          }
          return remoteCourses;
        }
      } catch (_) {
        // Fall back to Firestore or cached data
      }
    }

    // 2. Secondary fallback: Firestore
    if (isFirestoreAvailable) {
      try {
        final snapshot = await _coursesRef.get(GetOptions(source: source));
        final courses = snapshot.docs.map((doc) {
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

        if (courses.isNotEmpty) {
          _cachedCourses = courses;
        }
        return courses;
      } catch (_) {
        return _cachedCourses;
      }
    }

    return _cachedCourses;
  }

  @override
  Future<List<Course>> getPublicCourses({String? search, bool forceRefresh = false}) async {
    final remote = _remote;
    if (remote != null) {
      final courses = await remote.getPublicCourses(search: search);
      if (search == null || search.isEmpty) {
        _cachedCourses = courses;
        if (!_coursesStreamController.isClosed) {
          _coursesStreamController.add(courses);
        }
      }
      return courses;
    }
    return getCourses();
  }

  @override
  Future<Course> getCourseDetails(String slugOrId) async {
    final remote = _remote;
    if (remote != null) {
      try {
        // Attempt student details first (includes user progress & permissions)
        return await remote.getStudentCourseBySlug(slugOrId);
      } catch (_) {
        // Fall back to public course details
        return await remote.getPublicCourseBySlug(slugOrId);
      }
    }

    // Fallback: search in cached courses
    final found = _cachedCourses.firstWhere(
      (c) => c.id == slugOrId || c.slug == slugOrId,
      orElse: () => throw StateError('Course not found'),
    );
    return found;
  }

  @override
  Future<StudentDashboardData> getStudentDashboard() async {
    final remote = _remote;
    if (remote != null) {
      return await remote.getStudentDashboard();
    }
    return StudentDashboardData(enrolledCourses: _cachedCourses);
  }

  @override
  Future<StudentCoursesData> getStudentCourses() async {
    final remote = _remote;
    if (remote != null) {
      return await remote.getStudentCourses();
    }
    return const StudentCoursesData();
  }

  @override
  Future<String?> fetchProtectedLessonPlaybackId({
    required String courseId,
    required String lessonId,
  }) async {
    if (!isFirestoreAvailable) return null;
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
    if (!isFirestoreAvailable) return;
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

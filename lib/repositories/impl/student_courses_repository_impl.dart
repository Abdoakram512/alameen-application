import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/di/injection_container.dart';
import '../../core/storage/course_local_cache.dart';
import '../../core/storage/secure_token_storage.dart';
import '../../datasources/courses_remote_data_source.dart';
import '../../models/course.dart';
import '../../models/student_courses_data.dart';
import '../../models/student_dashboard_data.dart';
import '../student_courses_repository.dart';

class StudentCoursesRepositoryImpl implements StudentCoursesRepository {
  final CoursesRemoteDataSource? _remoteDataSource;
  final CourseLocalCache? _localCache;
  final SecureTokenStorage? _tokenStorage;
  final FirebaseFirestore? _explicitFirestore;
  final StreamController<List<Course>> _coursesStreamController =
      StreamController<List<Course>>.broadcast();

  List<Course> _cachedCourses = const [];

  StudentCoursesRepositoryImpl({
    CoursesRemoteDataSource? remoteDataSource,
    CourseLocalCache? localCache,
    SecureTokenStorage? tokenStorage,
    FirebaseFirestore? firestore,
  })  : _remoteDataSource = remoteDataSource,
        _localCache = localCache,
        _tokenStorage = tokenStorage,
        _explicitFirestore = firestore;

  CoursesRemoteDataSource? get _remote {
    if (_remoteDataSource != null) return _remoteDataSource;
    if (sl.isRegistered<CoursesRemoteDataSource>()) {
      return sl<CoursesRemoteDataSource>();
    }
    return null;
  }

  CourseLocalCache get _cache {
    if (_localCache != null) return _localCache;
    if (sl.isRegistered<CourseLocalCache>()) {
      return sl<CourseLocalCache>();
    }
    return CourseLocalCacheImpl();
  }

  SecureTokenStorage? get _tokens {
    if (_tokenStorage != null) return _tokenStorage;
    if (sl.isRegistered<SecureTokenStorage>()) {
      return sl<SecureTokenStorage>();
    }
    return null;
  }

  Future<String?> _resolveCurrentUserId() async {
    final tokens = _tokens;
    if (tokens != null) {
      final userData = await tokens.getUserData();
      final idVal = userData?['id'] ?? userData?['uid'];
      if (idVal != null) return idVal.toString();
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

  // ══════════════════════════════════════════════════════════════════════════
  // P3: STREAM & PUBLIC CATALOG (REST API + LOCAL CACHE ONLY)
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Stream<List<Course>> streamCourses() {
    // 1. Emit memory cache immediately if available
    if (_cachedCourses.isNotEmpty) {
      scheduleMicrotask(() {
        if (!_coursesStreamController.isClosed) {
          _coursesStreamController.add(_cachedCourses);
        }
      });
    } else {
      // 2. Read from persistent local cache if memory is empty
      _cache.getPublicCourses().then((cached) {
        if (cached != null && cached.isNotEmpty && _cachedCourses.isEmpty) {
          _cachedCourses = cached;
          if (!_coursesStreamController.isClosed) {
            _coursesStreamController.add(cached);
          }
        }
      }).catchError((_) {});
    }

    // 3. Trigger asynchronous background sync from Laravel REST API
    getCourses().then((courses) {
      if (!_coursesStreamController.isClosed && courses.isNotEmpty) {
        _coursesStreamController.add(courses);
      }
    }).catchError((_) {});

    return _coursesStreamController.stream;
  }

  @override
  Future<List<Course>> getCourses() async {
    return getPublicCourses();
  }

  @override
  Future<List<Course>> getPublicCourses({String? search, bool forceRefresh = false}) async {
    final remote = _remote;
    if (remote != null) {
      try {
        final courses = await remote.getPublicCourses(search: search);
        if (search == null || search.trim().isEmpty) {
          _cachedCourses = courses;
          await _cache.savePublicCourses(courses);
          if (!_coursesStreamController.isClosed) {
            _coursesStreamController.add(courses);
          }
        }
        return courses;
      } catch (e) {
        // Network/offline error: Fall back strictly to isolated local cache.
        // NEVER make direct Firestore requests when Laravel API fails!
        if (search == null || search.trim().isEmpty) {
          final cached = await _cache.getPublicCourses();
          if (cached != null && cached.isNotEmpty) {
            _cachedCourses = cached;
            if (!_coursesStreamController.isClosed) {
              _coursesStreamController.add(cached);
            }
            return cached;
          }
        }
        if (_cachedCourses.isNotEmpty) {
          return _cachedCourses;
        }
        rethrow;
      }
    }

    // If remote data source is not registered, read local cache
    final cached = await _cache.getPublicCourses();
    if (cached != null && cached.isNotEmpty) {
      _cachedCourses = cached;
      return cached;
    }
    return _cachedCourses;
  }

  @override
  Future<Course> getCourseDetails(String slugOrId) async {
    final remote = _remote;
    final userId = await _resolveCurrentUserId();

    if (remote != null) {
      try {
        // Attempt student-specific course details first (includes user progress & permissions)
        final course = await remote.getStudentCourseBySlug(slugOrId);
        await _cache.saveCourseDetails(slugOrId, course, userId: userId);
        return course;
      } catch (_) {
        try {
          // Fall back to public course details
          final course = await remote.getPublicCourseBySlug(slugOrId);
          await _cache.saveCourseDetails(slugOrId, course, userId: userId);
          return course;
        } catch (e) {
          // Offline / network failure: Attempt local cache retrieval
          final cached = await _cache.getCourseDetails(slugOrId, userId: userId);
          if (cached != null) return cached;
          rethrow;
        }
      }
    }

    // Local cache lookup when remote is unavailable
    final cached = await _cache.getCourseDetails(slugOrId, userId: userId);
    if (cached != null) return cached;

    // In-memory fallback
    final found = _cachedCourses.firstWhere(
      (c) => c.id == slugOrId || c.slug == slugOrId,
      orElse: () => throw StateError('Course not found in local cache'),
    );
    return found;
  }

  @override
  Future<StudentDashboardData> getStudentDashboard() async {
    final remote = _remote;
    final userId = await _resolveCurrentUserId() ?? 'anonymous';

    if (remote != null) {
      try {
        final dashboard = await remote.getStudentDashboard();
        await _cache.saveStudentDashboard(userId, dashboard);
        return dashboard;
      } catch (e) {
        // Fall back strictly to user-isolated offline cache
        final cached = await _cache.getStudentDashboard(userId);
        if (cached != null) return cached;
        if (_cachedCourses.isNotEmpty) {
          return StudentDashboardData(enrolledCourses: _cachedCourses);
        }
        rethrow;
      }
    }

    final cached = await _cache.getStudentDashboard(userId);
    if (cached != null) return cached;
    return StudentDashboardData(enrolledCourses: _cachedCourses);
  }

  @override
  Future<StudentCoursesData> getStudentCourses() async {
    final remote = _remote;
    final userId = await _resolveCurrentUserId() ?? 'anonymous';

    if (remote != null) {
      try {
        final studentCourses = await remote.getStudentCourses();
        await _cache.saveStudentCourses(userId, studentCourses);
        return studentCourses;
      } catch (e) {
        // Fall back strictly to user-isolated offline cache
        final cached = await _cache.getStudentCourses(userId);
        if (cached != null) return cached;
        rethrow;
      }
    }

    final cached = await _cache.getStudentCourses(userId);
    if (cached != null) return cached;
    return const StudentCoursesData();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UNMIGRATED P5 COMPATIBILITY: PROTECTED LESSON PLAYBACK ID
  // Retained strictly for Phase P5 (Video Player & Protected Vault)
  // ══════════════════════════════════════════════════════════════════════════

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
}

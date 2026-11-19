import 'dart:async';
import '../../core/di/injection_container.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/failure_mapper.dart';
import '../../core/network/api_exceptions.dart';
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
  final StreamController<List<Course>> _coursesStreamController =
      StreamController<List<Course>>.broadcast();

  List<Course> _cachedCourses = const [];
  final Map<String, Future<List<Course>>> _catalogRequests = {};
  final Map<String, Future<StudentCoursesData>> _enrollmentRequests = {};

  StudentCoursesRepositoryImpl({
    CoursesRemoteDataSource? remoteDataSource,
    CourseLocalCache? localCache,
    SecureTokenStorage? tokenStorage,
  }) : _remoteDataSource = remoteDataSource,
       _localCache = localCache,
       _tokenStorage = tokenStorage;

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

  // ══════════════════════════════════════════════════════════════════════════
  // STREAM & CATALOG (LARAVEL REST API + USER-ISOLATED LOCAL CACHE ONLY)
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
      _cache
          .getPublicCourses()
          .then((cached) {
            if (cached != null && cached.isNotEmpty && _cachedCourses.isEmpty) {
              _cachedCourses = cached;
              if (!_coursesStreamController.isClosed) {
                _coursesStreamController.add(cached);
              }
            }
          })
          .catchError((_) {});
    }

    // 3. Trigger asynchronous background sync from Laravel REST API
    // The fetch itself publishes once; do not echo it into the stream again.
    unawaited(getCourses().then<void>((_) {}).catchError((_) {}));

    return _coursesStreamController.stream;
  }

  @override
  Future<List<Course>> getCourses() async {
    return getPublicCourses();
  }

  @override
  Future<List<Course>> getPublicCourses({
    String? search,
    bool forceRefresh = false,
  }) async {
    final key = search?.trim() ?? '';
    final pending = _catalogRequests[key];
    if (pending != null) return pending;
    final request = _fetchPublicCourses(search: search);
    _catalogRequests[key] = request;
    try {
      return await request;
    } finally {
      if (identical(_catalogRequests[key], request)) {
        _catalogRequests.remove(key);
      }
    }
  }

  Future<List<Course>> _fetchPublicCourses({String? search}) async {
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

    final cached = await _cache.getPublicCourses();
    if (cached != null && cached.isNotEmpty) {
      _cachedCourses = cached;
      return cached;
    }
    return _cachedCourses;
  }

  Course _stripAuthorizationForOfflinePreview(Course cached) {
    return cached.copyWith(
      hasEnrolled: false,
      isDetailedFromAuthServer: false,
      accessibleVideoIds: const [],
    );
  }

  @override
  Future<Course> verifyStudentCourseDetails(String slugOrId) async {
    final remote = _remote;
    if (remote == null) {
      throw const NetworkFailure(
        'تعذر الاتصال بخادم المنصة للتحقق من الاشتراك.',
      );
    }
    final userId = await _resolveCurrentUserId();
    try {
      final course = await remote.getStudentCourseBySlug(slugOrId);
      unawaited(
        _cache
            .saveCourseDetails(slugOrId, course, userId: userId)
            .catchError((_) {}),
      );
      return course;
    } catch (e) {
      throw FailureMapper.fromException(
        e,
        fallbackMessage: 'تعذر التحقق من حالة التسجيل في الدورة من الخادم.',
      );
    }
  }

  @override
  Future<Course> getCourseDetails(String slugOrId) async {
    final remote = _remote;
    final userId = await _resolveCurrentUserId();

    if (remote != null) {
      try {
        // Primary: student-specific course details (includes has_enrolled, accessible_video_ids, progress)
        final course = await remote.getStudentCourseBySlug(slugOrId);
        unawaited(
          _cache
              .saveCourseDetails(slugOrId, course, userId: userId)
              .catchError((_) {}),
        );
        return course;
      } on UnauthorizedException catch (e) {
        throw FailureMapper.fromException(e);
      } on ForbiddenException catch (e) {
        throw FailureMapper.fromException(e);
      } catch (_) {
        try {
          // Secondary: public course details (read-only preview without enrollment authority)
          final course = _stripAuthorizationForOfflinePreview(
            await remote.getPublicCourseBySlug(slugOrId),
          );
          unawaited(
            _cache
                .saveCourseDetails(slugOrId, course, userId: userId)
                .catchError((_) {}),
          );
          return course;
        } catch (e) {
          // Offline fallback: sanitized curriculum preview ONLY (never grants access)
          final cached = await _cache.getCourseDetails(
            slugOrId,
            userId: userId,
          );
          if (cached != null) {
            return _stripAuthorizationForOfflinePreview(cached);
          }
          throw FailureMapper.fromException(e);
        }
      }
    }

    final cached = await _cache.getCourseDetails(slugOrId, userId: userId);
    if (cached != null) return _stripAuthorizationForOfflinePreview(cached);

    final found = _cachedCourses.firstWhere(
      (c) => c.id == slugOrId || c.slug == slugOrId,
      orElse: () =>
          throw const NotFoundFailure('الدورة المطلوبة غير متوفرة حالياً.'),
    );
    return _stripAuthorizationForOfflinePreview(found);
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
        final cached = await _cache.getStudentDashboard(userId);
        if (cached != null) return cached;
        if (_cachedCourses.isNotEmpty) {
          return StudentDashboardData(enrolledCourses: _cachedCourses);
        }
        throw FailureMapper.fromException(e);
      }
    }

    final cached = await _cache.getStudentDashboard(userId);
    if (cached != null) return cached;
    return StudentDashboardData(enrolledCourses: _cachedCourses);
  }

  @override
  Future<StudentCoursesData> getStudentCourses() async {
    // Share only concurrent requests in this authenticated session, never a TTL
    // authorization cache. A new token always starts a new request.
    final key = await _tokens?.getToken() ?? '';
    final pending = _enrollmentRequests[key];
    if (pending != null) return pending;
    final request = _fetchStudentCourses();
    _enrollmentRequests[key] = request;
    try {
      return await request;
    } finally {
      if (identical(_enrollmentRequests[key], request)) {
        _enrollmentRequests.remove(key);
      }
    }
  }

  Future<StudentCoursesData> _fetchStudentCourses() async {
    final remote = _remote;
    if (remote == null) {
      throw const NetworkFailure(
        'تعذر الاتصال بخادم المنصة للتحقق من الدورات المشترك بها.',
      );
    }

    try {
      return await remote.getStudentCourses();
    } catch (e) {
      throw FailureMapper.fromException(
        e,
        fallbackMessage: 'تعذر التحقق من اشتراكات الطالب من الخادم.',
      );
    }
  }
}

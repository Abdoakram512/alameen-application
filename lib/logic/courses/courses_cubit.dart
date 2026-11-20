import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/injection_container.dart';
import '../../models/course.dart';
import '../../models/course_level.dart';
import '../../models/lesson.dart';
import '../../models/student_courses_data.dart';
import '../../models/student_dashboard_data.dart';
import '../../repositories/impl/student_courses_repository_impl.dart';
import '../../repositories/student_courses_repository.dart';
import '../auth/auth_cubit.dart';
import 'courses_state.dart';

class CoursesCubit extends Cubit<CoursesState> {
  final StudentCoursesRepository _coursesRepository;
  StreamSubscription? _coursesSubscription;
  List<Course> _cachedCourses = [];
  final Map<String, Course> _detailedCoursesById = {};
  StudentCoursesData? _studentCourses;
  StudentDashboardData? _dashboardData;
  String _currentCategory = 'الكل';
  String _query = '';
  int _sessionGeneration = 0;
  final Map<String, Future<Course?>> _detailRequests = {};

  CoursesCubit({StudentCoursesRepository? coursesRepository})
    : _coursesRepository =
          coursesRepository ??
          (sl.isRegistered<StudentCoursesRepository>()
              ? sl<StudentCoursesRepository>()
              : StudentCoursesRepositoryImpl()),
      super(CoursesLoading()) {
    loadCourses();
  }

  void search(String value) {
    _query = value.trim().toLowerCase();
    _applyFilter();
  }

  void filterByCategory(String category) {
    _currentCategory = category;
    _applyFilter();
  }

  Future<void> loadCourses({bool forceRefresh = false}) async {
    _coursesSubscription?.cancel();

    // 1. استرجاع الكاش المحلي فوراً (Zero Latency) لمنع شاشة اللودينج المعطلة
    if (_cachedCourses.isEmpty && !forceRefresh) {
      try {
        final local = await _coursesRepository.getCachedCourses();
        if (local != null && local.isNotEmpty && _cachedCourses.isEmpty) {
          _updateCourses(local);
        } else if (_cachedCourses.isEmpty) {
          emit(CoursesLoading());
        }
      } catch (_) {
        if (_cachedCourses.isEmpty) {
          emit(CoursesLoading());
        }
      }
    } else if (_cachedCourses.isEmpty) {
      emit(CoursesLoading());
    }

    // 2. الاشتراك في تدفق التحديثات
    _coursesSubscription = _coursesRepository.streamCourses().listen(
      (courses) {
        if (courses.isNotEmpty) {
          _updateCourses(courses);
        }
      },
      onError: (e) {
        if (_cachedCourses.isEmpty) {
          emit(CoursesError('تعذر تحميل البرامج التدريبية حالياً: $e'));
        }
      },
    );

    // 3. جلب القائمة الحديثة من خادم Laravel في الخلفية وتحديث الكاش
    try {
      final courses = await _coursesRepository.getPublicCourses(
        forceRefresh: forceRefresh,
      );
      if (courses.isNotEmpty) {
        _updateCourses(courses);
      } else if (_cachedCourses.isEmpty) {
        final fallbackCourses = await _coursesRepository.getCourses();
        if (fallbackCourses.isNotEmpty) {
          _updateCourses(fallbackCourses);
        } else {
          _updateCourses(const []);
        }
      }
    } catch (e) {
      if (_cachedCourses.isEmpty) {
        emit(
          CoursesError(
            'تعذر تحميل البرامج التدريبية حالياً، تحقق من اتصالك بالإنترنت.',
          ),
        );
      }
    }
  }

  /// جلب التفاصيل الكاملة للدورة (المستويات، الدروس، has_enrolled، accessible_video_ids، التقدم)
  /// مباشرة من GET /student/courses/{slug} ومزامنة حالة الطالب.
  Future<Course?> loadCourseDetails(
    String slugOrId, {
    AuthCubit? authCubit,
  }) async {
    final existing = _detailRequests[slugOrId];
    if (existing != null) return existing;
    final request = _fetchCourseDetails(slugOrId, authCubit: authCubit);
    _detailRequests[slugOrId] = request;
    try {
      return await request;
    } finally {
      if (identical(_detailRequests[slugOrId], request)) {
        _detailRequests.remove(slugOrId);
      }
    }
  }

  Future<Course?> _fetchCourseDetails(
    String slugOrId, {
    AuthCubit? authCubit,
  }) async {
    final generation = _sessionGeneration;
    try {
      // البحث عن السلاج الفعلي إذا كانت المصفوفة تحتوي على معرف رقمي
      String targetSlug = slugOrId;
      for (final c in _cachedCourses) {
        if (c.id == slugOrId && c.slug != null && c.slug!.trim().isNotEmpty) {
          targetSlug = c.slug!;
          break;
        }
      }

      final detailed = await _coursesRepository.getCourseDetails(targetSlug);
      if (isClosed || generation != _sessionGeneration) return null;
      _detailedCoursesById[detailed.id] = detailed;
      if (detailed.slug != null && detailed.slug!.isNotEmpty) {
        _detailedCoursesById[detailed.slug!] = detailed;
      }

      final updatedList = List<Course>.from(_cachedCourses);
      final idx = updatedList.indexWhere(
        (c) =>
            c.id == detailed.id ||
            (detailed.slug != null && c.slug == detailed.slug),
      );
      if (idx >= 0) {
        updatedList[idx] = detailed;
      } else {
        updatedList.add(detailed);
      }
      _updateCourses(updatedList);

      authCubit?.markCourseDetailEntitlement(detailed);
      return detailed;
    } catch (_) {
      return null;
    }
  }

  /// مزامنة اشتراكات وإحصائيات الطالب المعتمدة من GET /student/courses و GET /student/dashboard.
  Future<void> syncStudentState({AuthCubit? authCubit}) async {
    final generation = _sessionGeneration;
    try {
      final results = await Future.wait([
        _coursesRepository.getStudentCourses().catchError(
          (_) => const StudentCoursesData(),
        ),
        _coursesRepository.getStudentDashboard().catchError(
          (_) => const StudentDashboardData(enrolledCourses: []),
        ),
      ]);

      if (isClosed || generation != _sessionGeneration) return;
      final studentCourses = results[0] as StudentCoursesData;
      final dashboard = results[1] as StudentDashboardData;

      _studentCourses = studentCourses;
      _dashboardData = dashboard;

      final activeIds = studentCourses.activeEnrolledCourseIdStrings.toSet();
      final updatedList = _cachedCourses.map((course) {
        final enrolledNow = activeIds.contains(course.id);
        final detailed = _detailedCoursesById[course.id];
        if (detailed != null) {
          final merged = detailed.copyWith(hasEnrolled: enrolledNow);
          _detailedCoursesById[course.id] = merged;
          return merged;
        }
        return course.copyWith(hasEnrolled: enrolledNow);
      }).toList();

      _updateCourses(updatedList);

      authCubit?.syncStudentEntitlements(studentCourses, dashboard: dashboard);
    } catch (_) {}
  }

  /// مسح حالة الطالب المخصصة عند تسجيل الخروج أو تبديل الحساب لمنع أي بقايا وصول.
  void clearStudentSession() {
    _sessionGeneration++;
    _detailRequests.clear();
    _studentCourses = null;
    _dashboardData = null;
    _detailedCoursesById.clear();
    if (_cachedCourses.isNotEmpty) {
      final sanitized = _cachedCourses
          .map(
            (c) => c.copyWith(
              hasEnrolled: false,
              accessibleVideoIds: const [],
              completedVideoIds: const [],
              isDetailedFromAuthServer: false,
            ),
          )
          .toList();
      _cachedCourses = sanitized;
      _applyFilter();
    }
  }

  Future<void> refresh({AuthCubit? authCubit}) async {
    await loadCourses(forceRefresh: true);
    await syncStudentState(authCubit: authCubit);
  }

  void _updateCourses(List<Course> courses) {
    final activeIds = _studentCourses?.activeEnrolledCourseIdStrings.toSet();

    final sortedCourses = courses.map((course) {
      final cachedDetailed = _detailedCoursesById[course.id];
      final source = (cachedDetailed != null && course.levels.isEmpty)
          ? cachedDetailed
          : course;

      final resolvedHasEnrolled =
          activeIds != null && !source.isDetailedFromAuthServer
          ? activeIds.contains(source.id)
          : source.hasEnrolled;

      final sortedLevels = List<CourseLevel>.from(source.levels)
        ..sort((a, b) => a.order.compareTo(b.order));
      final finalLevels = sortedLevels.map((lvl) {
        final sortedLessons = List<Lesson>.from(lvl.lessons)
          ..sort((a, b) => a.order.compareTo(b.order));
        return lvl.copyWith(lessons: sortedLessons);
      }).toList();

      return source.copyWith(
        levels: finalLevels,
        hasEnrolled: resolvedHasEnrolled,
      );
    }).toList();

    _cachedCourses = sortedCourses;
    _applyFilter();
  }

  void _applyFilter() {
    final filtered = _cachedCourses
        .where(
          (course) =>
              (_currentCategory == 'الكل' ||
                  course.category == _currentCategory) &&
              (_query.isEmpty ||
                  '${course.title} ${course.description} ${course.instructor}'
                      .toLowerCase()
                      .contains(_query)),
        )
        .toList();
    emit(
      CoursesLoaded(
        allCourses: _cachedCourses,
        filteredCourses: filtered,
        selectedCategory: _currentCategory,
        studentCourses: _studentCourses,
        dashboardData: _dashboardData,
      ),
    );
  }

  @override
  Future<void> close() {
    _coursesSubscription?.cancel();
    return super.close();
  }
}

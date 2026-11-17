import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/injection_container.dart';
import '../../models/course.dart';
import '../../models/course_level.dart';
import '../../models/lesson.dart';
import '../../repositories/impl/student_courses_repository_impl.dart';
import '../../repositories/student_courses_repository.dart';
import 'courses_state.dart';

class CoursesCubit extends Cubit<CoursesState> {
  final StudentCoursesRepository _coursesRepository;
  StreamSubscription? _coursesSubscription;
  List<Course> _cachedCourses = [];
  String _currentCategory = 'الكل';
  String _query = '';

  CoursesCubit({
    StudentCoursesRepository? coursesRepository,
  })  : _coursesRepository = coursesRepository ??
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
    if (_cachedCourses.isEmpty) {
      emit(CoursesLoading());
    }

    _coursesSubscription?.cancel();

    // 1. Subscribe to real-time / cached repository updates
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

    // 2. Explicitly fetch from REST API
    try {
      final courses = await _coursesRepository.getPublicCourses(forceRefresh: forceRefresh);
      if (courses.isNotEmpty) {
        _updateCourses(courses);
      } else if (_cachedCourses.isEmpty) {
        // Fallback to legacy getCourses()
        final fallbackCourses = await _coursesRepository.getCourses();
        if (fallbackCourses.isNotEmpty) {
          _updateCourses(fallbackCourses);
        } else {
          _updateCourses(const []);
        }
      }
    } catch (e) {
      if (_cachedCourses.isEmpty) {
        emit(CoursesError('تعذر تحميل البرامج التدريبية حالياً، تحقق من اتصالك بالإنترنت.'));
      }
    }
  }

  Future<void> refresh() async {
    await loadCourses(forceRefresh: true);
  }

  void _updateCourses(List<Course> courses) {
    final sortedCourses = courses.map((course) {
      final sortedLevels = List<CourseLevel>.from(course.levels)
        ..sort((a, b) => a.order.compareTo(b.order));
      final finalLevels = sortedLevels.map((lvl) {
        final sortedLessons = List<Lesson>.from(lvl.lessons)
          ..sort((a, b) => a.order.compareTo(b.order));
        return lvl.copyWith(lessons: sortedLessons);
      }).toList();

      return course.copyWith(levels: finalLevels);
    }).toList();

    _cachedCourses = sortedCourses;
    _applyFilter();
  }

  void _applyFilter() {
    final filtered = _cachedCourses.where((course) =>
      (_currentCategory == 'الكل' || course.category == _currentCategory) &&
      (_query.isEmpty || '${course.title} ${course.description} ${course.instructor}'.toLowerCase().contains(_query))).toList();
    emit(CoursesLoaded(allCourses: _cachedCourses, filteredCourses: filtered, selectedCategory: _currentCategory));
  }

  @override
  Future<void> close() {
    _coursesSubscription?.cancel();
    return super.close();
  }
}

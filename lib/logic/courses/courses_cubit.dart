import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/course.dart';
import '../../services/firestore_service.dart';
import 'courses_state.dart';

class CoursesCubit extends Cubit<CoursesState> {
  final FirestoreService _firestoreService;
  StreamSubscription? _coursesSubscription;
  List<Course> _cachedCourses = [];
  String _currentCategory = 'الكل';
  String _query = '';
  void search(String value) { _query = value.trim().toLowerCase(); _applyFilter(); }

  CoursesCubit({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService(),
        super(CoursesLoading()) {
    loadCourses();
  }

  void loadCourses() {
    emit(CoursesLoading());
    _coursesSubscription?.cancel();
    _coursesSubscription = _firestoreService.streamCourses().listen(
      (courses) {
        // ترتيب المستويات والدروس داخل كل كورس لضمان عدم اللخبطة
        final sortedCourses = courses.map((course) {
          final sortedLevels = List.from(course.levels)
            ..sort((a, b) => a.order.compareTo(b.order));
          return course.copyWith(levels: sortedLevels.cast());
        }).toList();

        _cachedCourses = sortedCourses;
        _applyFilter();
      },
      onError: (e) {
        emit(CoursesError('فشل تحميل الكورسات من Firestore: $e'));
      },
    );
  }

  void filterByCategory(String category) {
    _currentCategory = category;
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


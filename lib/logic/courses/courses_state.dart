import 'package:equatable/equatable.dart';
import '../../models/course.dart';

abstract class CoursesState extends Equatable {
  const CoursesState();
  @override
  List<Object?> get props => [];
}

class CoursesLoading extends CoursesState {}

class CoursesLoaded extends CoursesState {
  final List<Course> allCourses;
  final List<Course> filteredCourses;
  final String selectedCategory;

  const CoursesLoaded({
    required this.allCourses,
    required this.filteredCourses,
    this.selectedCategory = 'الكل',
  });

  @override
  List<Object?> get props => [allCourses, filteredCourses, selectedCategory];
}

class CoursesError extends CoursesState {
  final String message;
  const CoursesError(this.message);
  @override
  List<Object?> get props => [message];
}


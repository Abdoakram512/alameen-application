import 'package:equatable/equatable.dart';
import '../../models/course.dart';
import '../../models/student_courses_data.dart';
import '../../models/student_dashboard_data.dart';

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
  final StudentCoursesData? studentCourses;
  final StudentDashboardData? dashboardData;

  const CoursesLoaded({
    required this.allCourses,
    required this.filteredCourses,
    this.selectedCategory = 'الكل',
    this.studentCourses,
    this.dashboardData,
  });

  @override
  List<Object?> get props => [
        allCourses,
        filteredCourses,
        selectedCategory,
        studentCourses,
        dashboardData,
      ];
}

class CoursesError extends CoursesState {
  final String message;
  const CoursesError(this.message);
  @override
  List<Object?> get props => [message];
}

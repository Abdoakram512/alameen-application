import 'package:equatable/equatable.dart';
import '../../models/course.dart';

abstract class AdminCoursesState extends Equatable {
  final List<Course> courses;
  const AdminCoursesState([this.courses = const []]);

  int get totalLessonsCount =>
      courses.fold(0, (sum, c) => sum + c.totalLessonsCount);

  @override
  List<Object?> get props => [courses];
}

class AdminCoursesLoading extends AdminCoursesState {
  const AdminCoursesLoading([super.courses]);
}

class AdminCoursesLoaded extends AdminCoursesState {
  final String? actionMessage;
  const AdminCoursesLoaded(super.courses, {this.actionMessage});

  @override
  List<Object?> get props => [courses, actionMessage];
}

class AdminCoursesActionSuccess extends AdminCoursesState {
  final String message;
  const AdminCoursesActionSuccess(this.message, [super.courses]);

  @override
  List<Object?> get props => [message, courses];
}

class AdminCoursesError extends AdminCoursesState {
  final String message;
  const AdminCoursesError(this.message, [super.courses]);

  @override
  List<Object?> get props => [message, courses];
}

import 'package:equatable/equatable.dart';
import '../../models/registered_student.dart';

abstract class AdminStudentsState extends Equatable {
  const AdminStudentsState();
  @override
  List<Object?> get props => [];
}

class AdminStudentsLoading extends AdminStudentsState {}

class AdminStudentsLoaded extends AdminStudentsState {
  final List<RegisteredStudent> students;
  const AdminStudentsLoaded(this.students);
  @override
  List<Object?> get props => [students];
}

class AdminStudentsError extends AdminStudentsLoaded {
  final String message;
  const AdminStudentsError(
    this.message, {
    List<RegisteredStudent> students = const [],
  }) : super(students);
  @override
  List<Object?> get props => [message, students];
}

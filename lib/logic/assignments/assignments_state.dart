import 'package:equatable/equatable.dart';
import '../../models/clinical_task_data.dart';

abstract class AssignmentsState extends Equatable {
  const AssignmentsState();

  @override
  List<Object?> get props => [];
}

class AssignmentsInitial extends AssignmentsState {
  const AssignmentsInitial();
}

class AssignmentsLoading extends AssignmentsState {
  const AssignmentsLoading();
}

class AssignmentsLoaded extends AssignmentsState {
  final StudentAssignmentsData data;
  final bool isSubmitting;

  const AssignmentsLoaded({
    required this.data,
    this.isSubmitting = false,
  });

  AssignmentsLoaded copyWith({
    StudentAssignmentsData? data,
    bool? isSubmitting,
  }) {
    return AssignmentsLoaded(
      data: data ?? this.data,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  @override
  List<Object?> get props => [data, isSubmitting];
}

class AssignmentsError extends AssignmentsState {
  final String message;

  const AssignmentsError(this.message);

  @override
  List<Object?> get props => [message];
}

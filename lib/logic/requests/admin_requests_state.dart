import 'package:equatable/equatable.dart';
import '../../models/access_request.dart';

abstract class AdminRequestsState extends Equatable {
  const AdminRequestsState();
  @override
  List<Object?> get props => [];
}

class AdminRequestsLoading extends AdminRequestsState {}

class AdminRequestsLoaded extends AdminRequestsState {
  final List<CourseAccessRequest> requests;
  const AdminRequestsLoaded(this.requests);

  int get pendingCount =>
      requests.where((r) => r.status == AccessStatus.pending).length;

  @override
  List<Object?> get props => [requests];
}

class AdminRequestsActionSuccess extends AdminRequestsLoaded {
  final String message;
  const AdminRequestsActionSuccess(
    this.message, {
    List<CourseAccessRequest> requests = const [],
  }) : super(requests);
  @override
  List<Object?> get props => [message, requests];
}

class AdminRequestsError extends AdminRequestsLoaded {
  final String message;
  const AdminRequestsError(
    this.message, {
    List<CourseAccessRequest> requests = const [],
  }) : super(requests);
  @override
  List<Object?> get props => [message, requests];
}

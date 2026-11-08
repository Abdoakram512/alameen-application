import 'package:equatable/equatable.dart';
import '../../models/access_request.dart';

abstract class AccessState extends Equatable {
  const AccessState();
  @override
  List<Object?> get props => [];
}

class AccessInitial extends AccessState {}

class AccessLoading extends AccessState {
  final Map<String, AccessStatus> courseStatuses;
  final Map<String, CourseAccessRequest> requestsByCourse;

  const AccessLoading({
    this.courseStatuses = const {},
    this.requestsByCourse = const {},
  });

  @override
  List<Object?> get props => [courseStatuses, requestsByCourse];
}

class AccessLoaded extends AccessState {
  final Map<String, AccessStatus> courseStatuses;
  final Map<String, CourseAccessRequest> requestsByCourse;

  const AccessLoaded(
    this.courseStatuses, {
    this.requestsByCourse = const {},
  });

  AccessStatus? getStatus(String courseId) => courseStatuses[courseId];
  CourseAccessRequest? getRequest(String courseId) =>
      requestsByCourse[courseId];

  @override
  List<Object?> get props => [courseStatuses, requestsByCourse];
}

class AccessActionSuccess extends AccessLoaded {
  final String message;

  const AccessActionSuccess(
    this.message, {
    Map<String, AccessStatus> courseStatuses = const {},
    super.requestsByCourse = const {},
  }) : super(courseStatuses);

  @override
  List<Object?> get props => [message, courseStatuses, requestsByCourse];
}

class AccessError extends AccessLoaded {
  final String message;

  const AccessError(
    this.message, {
    Map<String, AccessStatus> courseStatuses = const {},
    super.requestsByCourse = const {},
  }) : super(courseStatuses);

  @override
  List<Object?> get props => [message, courseStatuses, requestsByCourse];
}

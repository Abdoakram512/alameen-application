import 'package:equatable/equatable.dart';

import '../../../../../core/errors/app_failure.dart';
import '../../../domain/entities/course_entitlement.dart';

class CourseEntitlementState extends Equatable {
  final Map<String, CourseEntitlement> entitlements;
  final String? activeStudentId;
  final bool isSyncingAll;
  final AppFailure? syncFailure;

  const CourseEntitlementState({
    this.entitlements = const {},
    this.activeStudentId,
    this.isSyncingAll = false,
    this.syncFailure,
  });

  CourseEntitlement entitlementFor(String courseId) =>
      entitlements[courseId] ?? CourseEntitlement.unknown(courseId);

  bool isCourseAuthorized(String courseId) =>
      entitlementFor(courseId).canAccessProtectedContent;

  Set<String> get authorizedCourseIds => entitlements.entries
      .where((e) => e.value.canAccessProtectedContent)
      .map((e) => e.key)
      .toSet();

  CourseEntitlementState copyWith({
    Map<String, CourseEntitlement>? entitlements,
    String? activeStudentId,
    bool clearActiveStudentId = false,
    bool? isSyncingAll,
    AppFailure? syncFailure,
    bool clearSyncFailure = false,
  }) {
    return CourseEntitlementState(
      entitlements: entitlements ?? this.entitlements,
      activeStudentId:
          clearActiveStudentId ? null : (activeStudentId ?? this.activeStudentId),
      isSyncingAll: isSyncingAll ?? this.isSyncingAll,
      syncFailure: clearSyncFailure ? null : (syncFailure ?? this.syncFailure),
    );
  }

  @override
  List<Object?> get props => [
        entitlements,
        activeStudentId,
        isSyncingAll,
        syncFailure,
      ];
}

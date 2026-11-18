import 'package:equatable/equatable.dart';
import 'course.dart';
import 'lesson.dart';

class EnrolledCourseItem extends Equatable {
  final Course course;
  final int completedCount;
  final int totalCount;
  final int percentage;
  final DateTime? lastWatchedAt;
  final String status;
  final DateTime? expiresAt;
  final bool isEligibleForCert;
  final Lesson? resumeVideo;

  const EnrolledCourseItem({
    required this.course,
    this.completedCount = 0,
    this.totalCount = 0,
    this.percentage = 0,
    this.lastWatchedAt,
    this.status = 'active',
    this.expiresAt,
    this.isEligibleForCert = false,
    this.resumeVideo,
  });

  bool get isActiveEnrollment {
    final normalized = status.trim().toLowerCase();
    if (normalized.isNotEmpty &&
        normalized != 'active' &&
        normalized != 'approved' &&
        normalized != 'enrolled') {
      return false;
    }
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) {
      return false;
    }
    return true;
  }

  factory EnrolledCourseItem.fromJson(Map<String, dynamic> json) {
    final course = Course.fromLaravelSummaryJson(
      Map<String, dynamic>.from(json['course'] as Map? ?? json),
    );

    int completed = 0;
    int total = course.videosCount ?? 0;
    int pct = 0;
    DateTime? lastWatched;

    if (json['progress'] is Map) {
      final progressMap = Map<String, dynamic>.from(json['progress'] as Map);
      completed = (progressMap['completed_count'] is num)
          ? (progressMap['completed_count'] as num).toInt()
          : ((json['completed_lessons'] is num)
              ? (json['completed_lessons'] as num).toInt()
              : 0);
      total = (progressMap['total_count'] is num)
          ? (progressMap['total_count'] as num).toInt()
          : ((json['total_lessons'] is num)
              ? (json['total_lessons'] as num).toInt()
              : (course.videosCount ?? 0));
      pct = (progressMap['percentage'] is num)
          ? (progressMap['percentage'] as num).toInt()
          : (total > 0 ? ((completed / total) * 100).round() : 0);
      if (progressMap['last_watched_at'] is String) {
        lastWatched = DateTime.tryParse(progressMap['last_watched_at'] as String);
      }
    } else {
      completed = (json['completed_lessons'] is num)
          ? (json['completed_lessons'] as num).toInt()
          : ((json['completed_count'] is num)
              ? (json['completed_count'] as num).toInt()
              : 0);
      total = (json['total_lessons'] is num)
          ? (json['total_lessons'] as num).toInt()
          : ((json['total_count'] is num)
              ? (json['total_count'] as num).toInt()
              : (course.videosCount ?? 0));
      pct = (json['progress'] is num)
          ? (json['progress'] as num).toInt()
          : (total > 0 ? ((completed / total) * 100).round() : 0);
      if (json['last_watched_at'] is String) {
        lastWatched = DateTime.tryParse(json['last_watched_at'] as String);
      }
    }

    DateTime? expiresAt;
    if (json['expires_at'] != null) {
      expiresAt = DateTime.tryParse(json['expires_at'].toString());
    }

    Lesson? resume;
    if (json['resume_video'] is Map) {
      resume = Lesson.fromLaravelVideoJson(
        Map<String, dynamic>.from(json['resume_video'] as Map),
      );
    }

    return EnrolledCourseItem(
      course: course.copyWith(hasEnrolled: true),
      completedCount: completed,
      totalCount: total,
      percentage: pct,
      lastWatchedAt: lastWatched,
      status: json['status']?.toString() ?? 'active',
      expiresAt: expiresAt,
      isEligibleForCert: json['is_eligible_for_cert'] == true,
      resumeVideo: resume,
    );
  }

  @override
  List<Object?> get props => [
        course,
        completedCount,
        totalCount,
        percentage,
        lastWatchedAt,
        status,
        expiresAt,
        isEligibleForCert,
        resumeVideo,
      ];
}

/// DTO representing the response from GET /student/courses
class StudentCoursesData extends Equatable {
  final int enrolledCount;
  final int completedCount;
  final int inProgressCount;
  final int certificatesCount;
  final List<int> enrolledCourseIds;
  final List<EnrolledCourseItem> enrolledCourses;

  const StudentCoursesData({
    this.enrolledCount = 0,
    this.completedCount = 0,
    this.inProgressCount = 0,
    this.certificatesCount = 0,
    this.enrolledCourseIds = const [],
    this.enrolledCourses = const [],
  });

  /// المعرّفات النشطة فقط بعد استبعاد الاشتراكات المنتهية أو الملغاة
  List<String> get activeEnrolledCourseIdStrings {
    final result = <String>{};
    final inactiveIds = <String>{};
    for (final item in enrolledCourses) {
      if (item.isActiveEnrollment) {
        result.add(item.course.id);
      } else {
        inactiveIds.add(item.course.id);
      }
    }
    for (final id in enrolledCourseIds) {
      final str = id.toString();
      if (!inactiveIds.contains(str)) {
        result.add(str);
      }
    }
    return result.toList();
  }

  Map<String, DateTime> get expiryDatesByCourseId {
    final map = <String, DateTime>{};
    for (final item in enrolledCourses) {
      if (item.expiresAt != null) {
        map[item.course.id] = item.expiresAt!;
      }
    }
    return map;
  }

  factory StudentCoursesData.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map? ?? {};
    final enrolledCnt = (stats['enrolled_count'] is num)
        ? (stats['enrolled_count'] as num).toInt()
        : 0;
    final completedCnt = (stats['completed_count'] is num)
        ? (stats['completed_count'] as num).toInt()
        : 0;
    final inProgressCnt = (stats['in_progress_count'] is num)
        ? (stats['in_progress_count'] as num).toInt()
        : 0;
    final certificatesCnt = (stats['certificates_count'] is num)
        ? (stats['certificates_count'] as num).toInt()
        : 0;

    final rawIds = json['enrolled_course_ids'] as List? ?? [];
    final ids = rawIds
        .map((e) => (e is num) ? e.toInt() : (int.tryParse(e.toString()) ?? 0))
        .where((id) => id > 0)
        .toList();

    final rawCourses = json['enrolled_courses'] as List? ?? [];
    final items = rawCourses
        .map((e) => EnrolledCourseItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return StudentCoursesData(
      enrolledCount: enrolledCnt,
      completedCount: completedCnt,
      inProgressCount: inProgressCnt,
      certificatesCount: certificatesCnt,
      enrolledCourseIds: ids,
      enrolledCourses: items,
    );
  }

  @override
  List<Object?> get props => [
        enrolledCount,
        completedCount,
        inProgressCount,
        certificatesCount,
        enrolledCourseIds,
        enrolledCourses,
      ];
}

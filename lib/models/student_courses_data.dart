import 'package:equatable/equatable.dart';
import 'course.dart';

class EnrolledCourseItem extends Equatable {
  final Course course;
  final int completedCount;
  final int totalCount;
  final int percentage;
  final DateTime? lastWatchedAt;

  const EnrolledCourseItem({
    required this.course,
    this.completedCount = 0,
    this.totalCount = 0,
    this.percentage = 0,
    this.lastWatchedAt,
  });

  factory EnrolledCourseItem.fromJson(Map<String, dynamic> json) {
    final course = Course.fromLaravelSummaryJson(
      Map<String, dynamic>.from(json['course'] as Map? ?? json),
    );
    final progressMap = json['progress'] as Map? ?? {};
    final completed = (progressMap['completed_count'] is num)
        ? (progressMap['completed_count'] as num).toInt()
        : 0;
    final total = (progressMap['total_count'] is num)
        ? (progressMap['total_count'] as num).toInt()
        : (course.videosCount ?? 0);
    final pct = (progressMap['percentage'] is num)
        ? (progressMap['percentage'] as num).toInt()
        : (total > 0 ? ((completed / total) * 100).round() : 0);

    DateTime? lastWatched;
    if (progressMap['last_watched_at'] is String) {
      lastWatched = DateTime.tryParse(progressMap['last_watched_at'] as String);
    }

    return EnrolledCourseItem(
      course: course,
      completedCount: completed,
      totalCount: total,
      percentage: pct,
      lastWatchedAt: lastWatched,
    );
  }

  @override
  List<Object?> get props => [course, completedCount, totalCount, percentage, lastWatchedAt];
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

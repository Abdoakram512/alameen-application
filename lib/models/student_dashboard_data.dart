import 'package:equatable/equatable.dart';
import 'course.dart';
import 'lesson.dart';

/// DTO representing the response from GET /student/dashboard
class StudentDashboardData extends Equatable {
  final List<Course> enrolledCourses;
  final List<Course> pendingCourses;
  final List<Course> availableCourses;
  final int totalWatchedVideos;
  final int totalWatchSeconds;
  final double totalWatchHours;
  final int averageProgress;
  final Course? resumeCourse;
  final Lesson? resumeVideo;

  const StudentDashboardData({
    required this.enrolledCourses,
    this.pendingCourses = const [],
    this.availableCourses = const [],
    this.totalWatchedVideos = 0,
    this.totalWatchSeconds = 0,
    this.totalWatchHours = 0.0,
    this.averageProgress = 0,
    this.resumeCourse,
    this.resumeVideo,
  });

  factory StudentDashboardData.fromJson(Map<String, dynamic> json) {
    List<Course> parseCourses(dynamic list) {
      if (list is! List) return const [];
      return list
          .map((item) => Course.fromLaravelSummaryJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }

    final enrolled = parseCourses(json['enrolled_courses']);
    final pending = parseCourses(json['pending_courses']);
    final available = parseCourses(json['available_courses']);

    Course? resumeCourse;
    if (json['resume_course'] is Map) {
      resumeCourse = Course.fromLaravelSummaryJson(
        Map<String, dynamic>.from(json['resume_course'] as Map),
      );
    }

    Lesson? resumeVideo;
    if (json['resume_video'] is Map) {
      resumeVideo = Lesson.fromLaravelVideoJson(
        Map<String, dynamic>.from(json['resume_video'] as Map),
      );
    }

    final watchedVideos = (json['total_watched_videos'] is num)
        ? (json['total_watched_videos'] as num).toInt()
        : 0;
    final watchSec = (json['total_watch_seconds'] is num)
        ? (json['total_watch_seconds'] as num).toInt()
        : 0;
    final watchHrs = (json['total_watch_hours'] is num)
        ? (json['total_watch_hours'] as num).toDouble()
        : (watchSec / 3600);
    final avgProgress = (json['average_progress'] is num)
        ? (json['average_progress'] as num).toInt()
        : 0;

    return StudentDashboardData(
      enrolledCourses: enrolled,
      pendingCourses: pending,
      availableCourses: available,
      totalWatchedVideos: watchedVideos,
      totalWatchSeconds: watchSec,
      totalWatchHours: watchHrs,
      averageProgress: avgProgress,
      resumeCourse: resumeCourse,
      resumeVideo: resumeVideo,
    );
  }

  @override
  List<Object?> get props => [
        enrolledCourses,
        pendingCourses,
        availableCourses,
        totalWatchedVideos,
        totalWatchSeconds,
        totalWatchHours,
        averageProgress,
        resumeCourse,
        resumeVideo,
      ];
}

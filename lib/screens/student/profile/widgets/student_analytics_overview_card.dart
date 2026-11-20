import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/di/injection_container.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/assignment_submission.dart';
import '../../../../models/course.dart';
import '../../../../models/user_profile.dart';
import '../../../../models/watch_log_entry.dart';
import '../../../../repositories/student_assignments_repository.dart';
import 'course_time_breakdown_card.dart';
import 'learning_mastery_gauge_card.dart';
import 'student_weekly_activity_card.dart';

/// لوحة التحليل التدريبي الشخصي للمتدرب (Bento Analytics Studio):
/// تقرأ إحصائيات المشاهدة من نماذج Laravel المعتمدة (`Course`/`Lesson.progress`) دون الاعتماد على Firestore `watch_logs`.
class StudentAnalyticsOverviewCard extends StatefulWidget {
  final UserModel? currentUser;
  final List<Course> enrolledCourses;

  const StudentAnalyticsOverviewCard({
    super.key,
    required this.currentUser,
    required this.enrolledCourses,
  });

  @override
  State<StudentAnalyticsOverviewCard> createState() =>
      _StudentAnalyticsOverviewCardState();
}

class _StudentAnalyticsOverviewCardState
    extends State<StudentAnalyticsOverviewCard> {
  Future<List<AssignmentSubmission>>? _submissionsFuture;

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  @override
  void didUpdateWidget(covariant StudentAnalyticsOverviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser?.uid != widget.currentUser?.uid) {
      _loadSubmissions();
    }
  }

  void _loadSubmissions() {
    final uid = widget.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      _submissionsFuture = sl<StudentAssignmentsRepository>()
          .getAssignments()
          .then((data) => data.submissions);
    } else {
      _submissionsFuture = null;
    }
  }

  /// اشتقاق سجلات المشاهدة التحليلية مباشرة من بيانات التقدم القادمة من خادم Laravel.
  List<WatchLogEntry> _deriveLaravelWatchEntries(UserModel user) {
    final entries = <WatchLogEntry>[];
    for (final course in widget.enrolledCourses) {
      for (final level in course.levels) {
        for (final lesson in level.lessons) {
          if (lesson.watchedSeconds <= 0 && !lesson.isCompleted) continue;
          entries.add(
            WatchLogEntry(
              id: 'laravel_${user.uid}_${course.id}_${lesson.id}',
              studentId: user.uid,
              courseId: course.id,
              lessonId: lesson.id,
              lessonTitle: lesson.title,
              durationSeconds: lesson.watchedSeconds,
              totalDurationSeconds: lesson.durationInSeconds,
              completionPercentage: lesson.serverCompletionPercentage,
              isCompleted: lesson.isCompleted,
              recordedAt: lesson.lastWatchedAt ?? DateTime.now(),
            ),
          );
        }
      }
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.currentUser;
    if (user == null) return const SizedBox.shrink();

    final logs = _deriveLaravelWatchEntries(user);

    return FutureBuilder<List<AssignmentSubmission>>(
      key: ValueKey(user.uid),
      future: _submissionsFuture,
      builder: (context, subSnap) {
        final submissions = subSnap.data ?? const <AssignmentSubmission>[];

        return _buildAnalyticsBento(
          context: context,
          user: user,
          logs: logs,
          submissions: submissions,
        );
      },
    );
  }

  Widget _buildAnalyticsBento({
    required BuildContext context,
    required UserModel user,
    required List<WatchLogEntry> logs,
    required List<AssignmentSubmission> submissions,
  }) {
    final allEnrolledLessonIds = <String>{
      for (final c in widget.enrolledCourses) ...c.allLessonIds,
    };
    final completedInEnrolled = allEnrolledLessonIds
        .where((id) => user.completedLessonIds.contains(id))
        .length;
    final overallMastery = allEnrolledLessonIds.isEmpty
        ? 0.0
        : (completedInEnrolled / allEnrolledLessonIds.length).clamp(0.0, 1.0);

    final gradedSubmissions = submissions
        .where((s) => s.isGraded && s.score != null && s.maxScore > 0)
        .toList();
    double? avgGradeRatio;
    if (gradedSubmissions.isNotEmpty) {
      final sumRatio = gradedSubmissions.fold<double>(
        0.0,
        (acc, s) => acc + ((s.score ?? 0) / s.maxScore).clamp(0.0, 1.0),
      );
      avgGradeRatio = sumRatio / gradedSubmissions.length;
    }

    final weeklyBuckets = StudentAnalyticsCalculator.buildLast7DaysBuckets(
      logs,
    );
    final activeDaysCount = weeklyBuckets.where((b) => b.minutes > 0).length;
    final weeklyTotalMinutes = weeklyBuckets
        .fold<double>(0.0, (sum, b) => sum + b.minutes)
        .round();
    final minutesByCourse = StudentAnalyticsCalculator.watchMinutesByCourse(
      logs,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                PhosphorIconsRegular.chartPolar,
                color: AppColors.primary,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تحليل الأداء والتقدم الشخصي',
                    style: AppTextStyles.heading2,
                  ),
                  Text(
                    'قراءة لمعدل إنجازك ونشاطك وتقييماتك العملية المعتمدة من المنصة',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 660;
            final masteryCard = LearningMasteryGaugeCard(
              overallMastery: overallMastery,
              completedLessons: completedInEnrolled,
              totalLessons: allEnrolledLessonIds.length,
              avgGradeRatio: avgGradeRatio,
              gradedCount: gradedSubmissions.length,
              activeDaysCount: activeDaysCount,
            );
            final weeklyCard = StudentWeeklyActivityCard(
              buckets: weeklyBuckets,
              weeklyTotalMinutes: weeklyTotalMinutes,
            );

            if (isWide) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 5, child: masteryCard),
                    const SizedBox(width: 14),
                    Expanded(flex: 6, child: weeklyCard),
                  ],
                ),
              );
            }
            return Column(
              children: [masteryCard, const SizedBox(height: 12), weeklyCard],
            );
          },
        ),
        if (widget.enrolledCourses.isNotEmpty) ...[
          const SizedBox(height: 12),
          CourseTimeBreakdownCard(
            enrolledCourses: widget.enrolledCourses,
            currentUser: user,
            minutesByCourse: minutesByCourse,
          ),
        ],
      ],
    );
  }
}

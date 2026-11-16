import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/assignment_submission.dart';
import '../../../../models/course.dart';
import '../../../../models/user_profile.dart';
import '../../../../models/watch_log_entry.dart';
import '../../../../repositories/student_learning_repository.dart';
import 'course_time_breakdown_card.dart';
import 'learning_mastery_gauge_card.dart';
import 'student_analytics_painters.dart';
import 'student_weekly_activity_card.dart';

/// لوحة التحليل التدريبي الشخصي للمتدرب (Bento Analytics Studio):
/// تجمع بين مؤشر الإتقان الدائري المرسوم بـ [LearningRadialGaugePainter]
/// ومخطط نشاط آخر 7 أيام المرسوم بـ [WeeklyActivityChartPainter] مع حركات انسيابية.
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
  Stream<List<WatchLogEntry>>? _watchLogsStream;
  Stream<List<AssignmentSubmission>>? _submissionsStream;

  StudentLearningRepository get _repository =>
      sl.isRegistered<StudentLearningRepository>()
          ? sl<StudentLearningRepository>()
          : StudentLearningRepositoryImpl();

  @override
  void initState() {
    super.initState();
    _bindStreams();
  }

  @override
  void didUpdateWidget(covariant StudentAnalyticsOverviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser?.uid != widget.currentUser?.uid) {
      _bindStreams();
    }
  }

  void _bindStreams() {
    final uid = widget.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      _watchLogsStream = _repository.streamStudentWatchLogs(uid);
      _submissionsStream = _repository.streamStudentSubmissions(uid);
    } else {
      _watchLogsStream = null;
      _submissionsStream = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<List<WatchLogEntry>>(
      stream: _watchLogsStream,
      builder: (context, watchSnap) {
        return StreamBuilder<List<AssignmentSubmission>>(
          stream: _submissionsStream,
          builder: (context, subSnap) {
            final logs = watchSnap.data ?? const <WatchLogEntry>[];
            final submissions = subSnap.data ?? const <AssignmentSubmission>[];

            return _buildAnalyticsBento(
              context: context,
              user: user,
              logs: logs,
              submissions: submissions,
            );
          },
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
    // 1. حساب نسبة إنجاز المحاضرات الفعلية في الدورات المشترك بها
    final allEnrolledLessonIds = <String>{
      for (final c in widget.enrolledCourses) ...c.allLessonIds,
    };
    final completedInEnrolled = allEnrolledLessonIds
        .where((id) => user.completedLessonIds.contains(id))
        .length;
    final overallMastery = allEnrolledLessonIds.isEmpty
        ? 0.0
        : (completedInEnrolled / allEnrolledLessonIds.length).clamp(0.0, 1.0);

    // 2. حساب متوسط درجات التكليفات المقيمة
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

    // 3. حساب نشاط آخر 7 أيام وتوزيع وقت المشاهدة على الدورات
    final weeklyBuckets = StudentAnalyticsCalculator.buildLast7DaysBuckets(logs);
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
                  Text('تحليل الأداء والتقدم الشخصي',
                      style: AppTextStyles.heading2),
                  Text(
                    'قراءة حية لمعدل إنجازك ونشاطك الأسبوعي وتقييماتك العملية',
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
              children: [
                masteryCard,
                const SizedBox(height: 12),
                weeklyCard,
              ],
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

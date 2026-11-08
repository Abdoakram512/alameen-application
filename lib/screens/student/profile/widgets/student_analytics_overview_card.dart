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
import 'student_analytics_painters.dart';

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
    final activeDaysCount =
        weeklyBuckets.where((b) => b.minutes > 0).length;
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
                  Text('تحليل الأداء والتقدم الشخصي', style: AppTextStyles.heading2),
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
            final masteryCard = _MasteryGaugeCard(
              overallMastery: overallMastery,
              completedLessons: completedInEnrolled,
              totalLessons: allEnrolledLessonIds.length,
              avgGradeRatio: avgGradeRatio,
              gradedCount: gradedSubmissions.length,
              activeDaysCount: activeDaysCount,
            );
            final weeklyCard = _WeeklyActivityCard(
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
          _CourseTimeBreakdownCard(
            enrolledCourses: widget.enrolledCourses,
            currentUser: user,
            minutesByCourse: minutesByCourse,
          ),
        ],
      ],
    );
  }
}

class _MasteryGaugeCard extends StatelessWidget {
  final double overallMastery;
  final int completedLessons;
  final int totalLessons;
  final double? avgGradeRatio;
  final int gradedCount;
  final int activeDaysCount;

  const _MasteryGaugeCard({
    required this.overallMastery,
    required this.completedLessons,
    required this.totalLessons,
    required this.avgGradeRatio,
    required this.gradedCount,
    required this.activeDaysCount,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 370;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderHairline),
        boxShadow: AppColors.cardShadow,
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: overallMastery),
        duration: const Duration(milliseconds: 850),
        curve: Curves.easeOutCubic,
        builder: (context, animatedProgress, _) {
          final gaugeWidget = SizedBox(
            width: compact ? 114 : 128,
            height: compact ? 114 : 128,
            child: CustomPaint(
              painter: LearningRadialGaugePainter(progress: animatedProgress),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(animatedProgress * 100).round()}%',
                      style: AppTextStyles.heading2.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'إنجاز المنهج',
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          );

          final metricsColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MiniMetricRow(
                icon: PhosphorIconsRegular.playCircle,
                iconColor: AppColors.primary,
                label: 'المحاضرات المنجزة',
                value: '$completedLessons من $totalLessons',
              ),
              const SizedBox(height: 10),
              _MiniMetricRow(
                icon: PhosphorIconsRegular.medal,
                iconColor: AppColors.success,
                label: 'متوسط التقييم العملي',
                value: avgGradeRatio != null
                    ? '${(avgGradeRatio! * 100).round()}% ($gradedCount)'
                    : 'لا توجد تقييمات بعد',
              ),
              const SizedBox(height: 10),
              _MiniMetricRow(
                icon: PhosphorIconsRegular.flame,
                iconColor: AppColors.warning,
                label: 'أيام النشاط هذا الأسبوع',
                value: '$activeDaysCount من 7 أيام',
              ),
            ],
          );

          if (compact) {
            return Column(
              children: [
                gaugeWidget,
                const SizedBox(height: 14),
                metricsColumn,
              ],
            );
          }

          return Row(
            children: [
              gaugeWidget,
              const SizedBox(width: 16),
              Expanded(child: metricsColumn),
            ],
          );
        },
      ),
    );
  }
}

class _MiniMetricRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _MiniMetricRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: iconColor),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(fontSize: 11),
              ),
              Text(
                value,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeeklyActivityCard extends StatelessWidget {
  final List<DailyStudyBucket> buckets;
  final int weeklyTotalMinutes;

  const _WeeklyActivityCard({
    required this.buckets,
    required this.weeklyTotalMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final values = buckets.map((b) => b.minutes).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderHairline),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نشاط التعلم (آخر 7 أيام)',
                      style: AppTextStyles.heading3.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      weeklyTotalMinutes > 0
                          ? 'إجمالي $weeklyTotalMinutes دقيقة مشاهدة مسجلة هذا الأسبوع'
                          : 'ابدأ مشاهدة محاضراتك ليظهر منحنى تقدمك اليومي هنا',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      PhosphorIconsRegular.trendUp,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$weeklyTotalMinutes د',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 104,
            width: double.infinity,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, animVal, _) {
                return CustomPaint(
                  painter: WeeklyActivityChartPainter(
                    values: values,
                    highlightedIndex: buckets.length - 1,
                    animationValue: animVal,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final bucket in buckets)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        bucket.shortLabel,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 10.5,
                          fontWeight: bucket.isToday
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: bucket.isToday
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                      ),
                      if (bucket.minutes > 0)
                        Text(
                          '${bucket.minutes.round()}د',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 9.5,
                            color: AppColors.textSecondary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CourseTimeBreakdownCard extends StatelessWidget {
  final List<Course> enrolledCourses;
  final UserModel currentUser;
  final Map<String, int> minutesByCourse;

  const _CourseTimeBreakdownCard({
    required this.enrolledCourses,
    required this.currentUser,
    required this.minutesByCourse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                PhosphorIconsRegular.chartBarHorizontal,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'تفصيل التقدم ووقت التعلم لكل دورة',
                style: AppTextStyles.heading3.copyWith(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < enrolledCourses.length; i++) ...[
            _buildCourseAnalyticsRow(enrolledCourses[i]),
            if (i < enrolledCourses.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCourseAnalyticsRow(Course course) {
    final lessonIds = course.allLessonIds;
    final doneCount = lessonIds
        .where((id) => currentUser.completedLessonIds.contains(id))
        .length;
    final progress = currentUser.calculateCourseProgress(lessonIds);
    final watchedMins = minutesByCourse[course.id] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                course.title,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              watchedMins > 0 ? '$watchedMins د مشاهدة' : 'لم تبدأ المشاهدة',
              style: AppTextStyles.caption.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: progress >= 1.0
                    ? AppColors.successLight
                    : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${(progress * 100).round()}%',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  color: progress >= 1.0
                      ? AppColors.successDark
                      : AppColors.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, val, _) => LinearProgressIndicator(
                    value: val,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceLevel2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1.0 ? AppColors.success : AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$doneCount/${lessonIds.length} محاضرة',
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}


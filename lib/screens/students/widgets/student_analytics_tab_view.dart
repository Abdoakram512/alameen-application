import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/responsive/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../logic/courses/admin_courses_cubit.dart';
import '../../../logic/courses/admin_courses_state.dart';
import '../../../models/assignment_submission.dart';
import '../../../models/course.dart';
import '../../../models/registered_student.dart';
import '../../../models/watch_log_entry.dart';
import '../../../services/firestore_service.dart';
import '../../dashboard/tabs/analytics_widgets/admin_analytics_painters.dart';
import '../../dashboard/tabs/analytics_widgets/grade_submission_dialog.dart';

/// تبويب التحليل الفردي الشامل للمتدرب داخل شاشة تفاصيل الطالب للإدارة.
class StudentAnalyticsTabView extends StatefulWidget {
  final RegisteredStudent student;

  const StudentAnalyticsTabView({super.key, required this.student});

  @override
  State<StudentAnalyticsTabView> createState() =>
      _StudentAnalyticsTabViewState();
}

class _StudentAnalyticsTabViewState extends State<StudentAnalyticsTabView> {
  Stream<List<WatchLogEntry>>? _watchStream;
  Stream<List<AssignmentSubmission>>? _submissionsStream;

  @override
  void initState() {
    super.initState();
    _bindStreams();
  }

  @override
  void didUpdateWidget(covariant StudentAnalyticsTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student.id != widget.student.id) {
      _bindStreams();
    }
  }

  void _bindStreams() {
    final fs = FirestoreService();
    if (fs.isAvailable) {
      _watchStream = fs.streamStudentWatchLogs(widget.student.id);
      _submissionsStream = fs.streamStudentSubmissions(widget.student.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminCoursesCubit, AdminCoursesState>(
      builder: (context, coursesState) {
        final enrolledCourses = coursesState.courses
            .where((c) => widget.student.isEnrolled(c.id))
            .toList();

        return StreamBuilder<List<WatchLogEntry>>(
          stream: _watchStream,
          builder: (context, watchSnap) {
            return StreamBuilder<List<AssignmentSubmission>>(
              stream: _submissionsStream,
              builder: (context, subSnap) {
                final logs = watchSnap.data ?? const <WatchLogEntry>[];
                final submissions =
                    subSnap.data ?? const <AssignmentSubmission>[];

                return _buildAnalyticsList(
                  context: context,
                  enrolledCourses: enrolledCourses,
                  logs: logs,
                  submissions: submissions,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAnalyticsList({
    required BuildContext context,
    required List<Course> enrolledCourses,
    required List<WatchLogEntry> logs,
    required List<AssignmentSubmission> submissions,
  }) {
    final allLessonIds = <String>{
      for (final c in enrolledCourses) ...c.allLessonIds,
    };
    final completedInEnrolled = allLessonIds
        .where((id) => widget.student.completedLessonIds.contains(id))
        .length;
    final masteryRatio = allLessonIds.isEmpty
        ? 0.0
        : (completedInEnrolled / allLessonIds.length).clamp(0.0, 1.0);

    final graded = submissions
        .where((s) => s.isGraded && s.score != null && s.maxScore > 0)
        .toList();
    final avgGrade = graded.isEmpty
        ? null
        : graded.fold<double>(
                0.0,
                (acc, s) => acc + ((s.score ?? 0) / s.maxScore),
              ) /
              graded.length;

    final weeklyPoints = AdminAnalyticsCalculator.build7DayWatchMinutes(logs);
    final weeklyValues = weeklyPoints.map((p) => p.value).toList();
    final activeDays = weeklyPoints.where((p) => p.value > 0).length;
    final weeklySum = weeklyValues.fold<double>(0, (a, b) => a + b).round();

    final watchSecsByCourse = <String, int>{};
    for (final l in logs) {
      if (l.courseId.isEmpty || l.durationSeconds <= 0) continue;
      watchSecsByCourse[l.courseId] =
          (watchSecsByCourse[l.courseId] ?? 0) + l.durationSeconds;
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        ResponsiveCenter(
          maxWidth: 920,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 660;
                  final gaugeCard = Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderHairline),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 116,
                          height: 116,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: masteryRatio),
                            duration: const Duration(milliseconds: 850),
                            curve: Curves.easeOutCubic,
                            builder: (context, val, _) => CustomPaint(
                              painter: StudentMasteryRingPainter(progress: val),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${(val * 100).round()}%',
                                      style: AppTextStyles.heading2.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      'إنجاز المنهج',
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _MetricLine(
                                icon: PhosphorIconsRegular.checkCircle,
                                label: 'المحاضرات المنجزة',
                                value:
                                    '$completedInEnrolled من ${allLessonIds.length}',
                              ),
                              const SizedBox(height: 8),
                              _MetricLine(
                                icon: PhosphorIconsRegular.clockCountdown,
                                label: 'إجمالي وقت التعلم',
                                value: widget.student.watchTimeFormatted,
                              ),
                              const SizedBox(height: 8),
                              _MetricLine(
                                icon: PhosphorIconsRegular.medal,
                                label: 'متوسط التكليفات',
                                value: avgGrade != null
                                    ? '${(avgGrade * 100).round()}% (${graded.length})'
                                    : 'لا توجد درجات بعد',
                              ),
                              const SizedBox(height: 8),
                              _MetricLine(
                                icon: PhosphorIconsRegular.flame,
                                label: 'أيام النشاط الأسبوعي',
                                value: '$activeDays من 7 أيام',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );

                  final trendCard = Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderHairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'نشاط المشاهدة (آخر 7 أيام)',
                              style: AppTextStyles.heading3.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '$weeklySum دقيقة',
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 102,
                          width: double.infinity,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 850),
                            curve: Curves.easeOutCubic,
                            builder: (context, anim, _) => CustomPaint(
                              painter: AdminTrendAreaPainter(
                                values: weeklyValues,
                                highlightedIndex: weeklyPoints.length - 1,
                                animationValue: anim,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            for (final p in weeklyPoints)
                              Expanded(
                                child: Text(
                                  p.shortLabel,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 10.5,
                                    fontWeight: p.isToday
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: p.isToday
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );

                  if (wide) {
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 5, child: gaugeCard),
                          const SizedBox(width: 14),
                          Expanded(flex: 5, child: trendCard),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: [
                      gaugeCard,
                      const SizedBox(height: 12),
                      trendCard,
                    ],
                  );
                },
              ),
              if (enrolledCourses.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderHairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تقدم المتدرب في كل كورس مفعّل',
                        style: AppTextStyles.heading3.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < enrolledCourses.length; i++) ...[
                        _buildCourseProgressLine(
                          enrolledCourses[i],
                          ((watchSecsByCourse[enrolledCourses[i].id] ?? 0) / 60)
                              .ceil(),
                        ),
                        if (i < enrolledCourses.length - 1)
                          const Divider(height: 18),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderHairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التكليفات المرسلة من المتدرب (${submissions.length})',
                      style: AppTextStyles.heading3.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (submissions.isEmpty)
                      const Text(
                        'لم يرسل المتدرب أي تكليفات عملية حتى الآن.',
                        style: AppTextStyles.bodyMedium,
                      )
                    else
                      for (var i = 0; i < submissions.length; i++) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    submissions[i].assignmentTitle.isNotEmpty
                                        ? submissions[i].assignmentTitle
                                        : 'تكليف عملي',
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (submissions[i]
                                      .solutionText
                                      .trim()
                                      .isNotEmpty)
                                    Text(
                                      submissions[i].solutionText,
                                      
                                      style: AppTextStyles.caption,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => GradeSubmissionDialog.show(
                                context,
                                submission: submissions[i],
                              ),
                              child: Text(
                                submissions[i].isGraded
                                    ? '${submissions[i].score}/${submissions[i].maxScore}'
                                    : 'تقييم',
                              ),
                            ),
                          ],
                        ),
                        if (i < submissions.length - 1)
                          const Divider(height: 16),
                      ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCourseProgressLine(Course course, int watchedMinutes) {
    final ids = course.allLessonIds;
    final done = ids
        .where((id) => widget.student.completedLessonIds.contains(id))
        .length;
    final ratio = widget.student.calculateCourseProgress(ids);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                course.title,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$done/${ids.length} محاضرة • $watchedMinutes د',
              style: AppTextStyles.caption,
            ),
            const SizedBox(width: 8),
            Text(
              '${(ratio * 100).round()}%',
              style: AppTextStyles.label.copyWith(color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: AppColors.surfaceLevel2,
            valueColor: AlwaysStoppedAnimation<Color>(
              ratio >= 1.0 ? AppColors.success : AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            '$label: ',
            
            style: AppTextStyles.caption,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.label.copyWith(color: AppColors.textPrimary),
        ),
      ],
    );
  }
}


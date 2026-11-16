import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/responsive/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/student_avatar.dart';
import '../../../logic/courses/admin_courses_cubit.dart';
import '../../../logic/courses/admin_courses_state.dart';
import '../../../logic/requests/admin_requests_cubit.dart';
import '../../../logic/requests/admin_requests_state.dart';
import '../../../logic/students/admin_students_cubit.dart';
import '../../../logic/students/admin_students_state.dart';
import '../../../models/access_request.dart';
import '../../../models/assignment_submission.dart';
import '../../../models/course.dart';
import '../../../models/registered_student.dart';
import '../../../models/watch_log_entry.dart';
import '../../../services/firestore_service.dart';
import '../../students/student_detail_screen.dart';
import '../../analytics/widgets/video_monitoring_radar_card.dart';
import 'analytics_widgets/admin_analytics_painters.dart';
import 'analytics_widgets/analytics_kpi_bento_grid.dart';
import 'analytics_widgets/pending_submissions_grading_card.dart';

/// لوحة الإحصائيات والتحليلات العامة للمنصة (Admin Analytics Studio).
class AnalyticsTab extends StatefulWidget {
  final ValueChanged<int>? onSelectTab;

  const AnalyticsTab({super.key, this.onSelectTab});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  Stream<List<WatchLogEntry>>? _watchLogsStream;
  Stream<List<AssignmentSubmission>>? _submissionsStream;

  @override
  void initState() {
    super.initState();
    _bindRealtimeStreams();
  }

  void _bindRealtimeStreams() {
    final fs = FirestoreService();
    if (fs.isAvailable) {
      _watchLogsStream = fs.streamAllWatchLogs();
      _submissionsStream = fs.streamAllSubmissions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminCoursesCubit, AdminCoursesState>(
      builder: (context, coursesState) {
        return BlocBuilder<AdminStudentsCubit, AdminStudentsState>(
          builder: (context, studentsState) {
            return BlocBuilder<AdminRequestsCubit, AdminRequestsState>(
              builder: (context, requestsState) {
                final courses = coursesState.courses;
                final students = studentsState is AdminStudentsLoaded
                    ? studentsState.students
                    : const <RegisteredStudent>[];
                final requests = requestsState is AdminRequestsLoaded
                    ? requestsState.requests
                    : const <CourseAccessRequest>[];
                final pendingRequests = requestsState is AdminRequestsLoaded
                    ? requestsState.pendingCount
                    : 0;

                return StreamBuilder<List<WatchLogEntry>>(
                  stream: _watchLogsStream,
                  builder: (context, watchSnap) {
                    return StreamBuilder<List<AssignmentSubmission>>(
                      stream: _submissionsStream,
                      builder: (context, subSnap) {
                        final logs = watchSnap.data ?? const <WatchLogEntry>[];
                        final submissions =
                            subSnap.data ?? const <AssignmentSubmission>[];

                        return _buildAnalyticsBody(
                          context: context,
                          courses: courses,
                          students: students,
                          requests: requests,
                          pendingRequests: pendingRequests,
                          logs: logs,
                          submissions: submissions,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAnalyticsBody({
    required BuildContext context,
    required List<Course> courses,
    required List<RegisteredStudent> students,
    required List<CourseAccessRequest> requests,
    required int pendingRequests,
    required List<WatchLogEntry> logs,
    required List<AssignmentSubmission> submissions,
  }) {
    final estimatedRevenue =
        AdminAnalyticsCalculator.calculateActiveEnrollmentsValue(
          courses: courses,
          students: students,
        );
    final totalWatchMinutes = students.fold<int>(
      0,
      (sum, s) => sum + s.watchTimeMinutes,
    );
    final activeStudentsCount = students
        .where((s) => s.enrolledCourseIds.isNotEmpty)
        .length;
    final ungradedCount = submissions.where((s) => !s.isGraded).length;

    final weeklyWatch = AdminAnalyticsCalculator.build7DayWatchMinutes(logs);
    final donutSegments =
        AdminAnalyticsCalculator.buildCourseEnrollmentDistribution(
          courses: courses,
          students: students,
        );
    final paymentBreakdown = AdminAnalyticsCalculator.countPaymentMethods(
      requests,
    );

    final topStudents = List<RegisteredStudent>.from(students)
      ..sort((a, b) {
        final byWatch = b.totalWatchSeconds.compareTo(a.totalWatchSeconds);
        if (byWatch != 0) return byWatch;
        return b.completedLessonIds.length.compareTo(
          a.completedLessonIds.length,
        );
      });

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        context.read<AdminCoursesCubit>().loadCourses();
        context.read<AdminStudentsCubit>().loadStudents();
        context.read<AdminRequestsCubit>().loadRequests();
        setState(_bindRealtimeStreams);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          ResponsiveCenter(
            maxWidth: 1200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        PhosphorIconsRegular.chartPolar,
                        color: AppColors.primary,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'analytics.title'.tr(),
                            style: AppTextStyles.heading2,
                          ),
                          Text(
                            'analytics.subtitle'.tr(),
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AnalyticsKpiBentoGrid(
                  estimatedRevenueEgp: estimatedRevenue,
                  totalWatchMinutes: totalWatchMinutes,
                  activeStudentsCount: activeStudentsCount,
                  totalStudentsCount: students.length,
                  pendingActionCount: pendingRequests + ungradedCount,
                  onTapPendingActions: pendingRequests > 0
                      ? () => widget.onSelectTab?.call(3)
                      : null,
                ),
                const SizedBox(height: 16),
                VideoMonitoringRadarCard(
                  courses: courses,
                  students: students,
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 760;
                    final trendCard = _WeeklyPlatformTrendCard(
                      points: weeklyWatch,
                    );
                    final donutCard = _CourseDistributionCard(
                      segments: donutSegments,
                      paymentBreakdown: paymentBreakdown,
                    );
                    if (wide) {
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 6, child: trendCard),
                            const SizedBox(width: 14),
                            Expanded(flex: 5, child: donutCard),
                          ],
                        ),
                      );
                    }
                    return Column(
                      children: [
                        trendCard,
                        const SizedBox(height: 14),
                        donutCard,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _TopActiveStudentsCard(
                  topStudents: topStudents.take(5).toList(),
                ),
                const SizedBox(height: 16),
                PendingSubmissionsGradingCard(submissions: submissions),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyPlatformTrendCard extends StatelessWidget {
  final List<DailyMetricPoint> points;

  const _WeeklyPlatformTrendCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final values = points.map((p) => p.value).toList();
    final sumMinutes = values.fold<double>(0, (s, v) => s + v).round();

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
                      'منحنى نشاط المشاهدة (آخر 7 أيام)',
                      style: AppTextStyles.heading3.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'إجمالي دقائق التعلم الفعلية المسجلة يومياً عبر المنصة',
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
                child: Text(
                  '$sumMinutes د أسبوعياً',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 136,
            width: double.infinity,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, anim, _) => CustomPaint(
                painter: AdminTrendAreaPainter(
                  values: values,
                  highlightedIndex: points.length - 1,
                  animationValue: anim,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final p in points)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        p.shortLabel,
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: p.isToday
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: p.isToday
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                      ),
                      if (p.value > 0)
                        Text(
                          '${p.value.round()}د',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10,
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

class _CourseDistributionCard extends StatelessWidget {
  final List<DonutSegmentData> segments;
  final Map<String, int> paymentBreakdown;

  const _CourseDistributionCard({
    required this.segments,
    required this.paymentBreakdown,
  });

  @override
  Widget build(BuildContext context) {
    final totalEnrollments = segments
        .fold<double>(0, (s, item) => s + item.value)
        .round();

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
          Text(
            'توزيع الاشتراكات ووسائل السداد',
            style: AppTextStyles.heading3.copyWith(fontWeight: FontWeight.w800),
          ),
          const Text(
            'حصة الدورات الأعلى إقبالاً بين المتدربين المفعّلين',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 118,
                height: 118,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, anim, _) => CustomPaint(
                    painter: DistributionDonutPainter(
                      segments: segments,
                      animationValue: anim,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$totalEnrollments',
                            style: AppTextStyles.heading2.copyWith(
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          Text(
                            'اشتراك مفعّل',
                            style: AppTextStyles.caption.copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: segments.isEmpty
                    ? const Text(
                        'ستظهر نسب توزيع الدورات فور تفعيل اشتراكات المتدربين.',
                        style: AppTextStyles.bodyMedium,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final seg in segments)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 7),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: Color(seg.colorHex),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      seg.label,
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${seg.value.round()}',
                                    style: AppTextStyles.caption.copyWith(
                                      fontWeight: FontWeight.w800,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
          if (paymentBreakdown.isNotEmpty) ...[
            const Divider(height: 22),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final entry in paymentBreakdown.entries)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.scaffoldBackground,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.borderHairline),
                    ),
                    child: Text(
                      '${entry.key}: ${entry.value}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TopActiveStudentsCard extends StatelessWidget {
  final List<RegisteredStudent> topStudents;

  const _TopActiveStudentsCard({required this.topStudents});

  @override
  Widget build(BuildContext context) {
    if (topStudents.isEmpty) return const SizedBox.shrink();

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
              const Icon(
                PhosphorIconsRegular.trophy,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'أبرز المتدربين تفاعلاً والتزاماً (اضغط لعرض التحليل الكامل)',
                  style: AppTextStyles.heading3.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < topStudents.length; i++) ...[
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BlocProvider.value(
                      value: context.read<AdminStudentsCubit>(),
                      child: BlocProvider.value(
                        value: context.read<AdminCoursesCubit>(),
                        child: StudentDetailScreen(student: topStudents[i]),
                      ),
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == 0
                            ? AppColors.primary
                            : AppColors.surfaceLevel2,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: i == 0 ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    StudentAvatar(
                      name: topStudents[i].name,
                      photoUrl: topStudents[i].avatarUrl,
                      radius: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topStudents[i].name,
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${topStudents[i].enrolledCourseIds.length} دورات • ${topStudents[i].completedLessonIds.length} محاضرة منجزة',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        topStudents[i].watchTimeFormatted,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      PhosphorIconsRegular.caretLeft,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            if (i < topStudents.length - 1) const Divider(height: 6),
          ],
        ],
      ),
    );
  }
}

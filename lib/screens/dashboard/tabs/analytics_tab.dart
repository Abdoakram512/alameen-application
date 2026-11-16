import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/responsive/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
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
import '../../analytics/widgets/video_monitoring_radar_card.dart';
import 'analytics_widgets/analytics_kpi_bento_grid.dart';
import 'analytics_widgets/course_distribution_card.dart';
import 'analytics_widgets/pending_submissions_grading_card.dart';
import 'analytics_widgets/top_active_students_card.dart';
import 'analytics_widgets/weekly_platform_trend_card.dart';

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
      _submissionsStream = fs.streamPendingSubmissions();
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
    final activeStudentsCount =
        students.where((s) => s.enrolledCourseIds.isNotEmpty).length;
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
        context.read<AdminRequestsCubit>().loadRequests();
        await context.read<AdminStudentsCubit>().loadStudents();
        if (mounted) setState(_bindRealtimeStreams);
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
                    final trendCard = WeeklyPlatformTrendCard(
                      points: weeklyWatch,
                    );
                    final donutCard = CourseDistributionCard(
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
                TopActiveStudentsCard(
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

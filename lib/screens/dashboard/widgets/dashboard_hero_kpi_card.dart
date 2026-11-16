import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/painters/geometric_background_painter.dart';
import '../../../core/theme/app_colors.dart';

/// Alameen Center Clean Executive KPI Overview Card
/// Real human layout with intentional whitespace, clean typography, and purposeful alerts.
class DashboardHeroKpiCard extends StatelessWidget {
  final int totalCourses;
  final int totalLessons;
  final int totalStudents;
  final int enrolledStudents;
  final int pendingRequestsCount;
  final VoidCallback onReviewRequests;

  const DashboardHeroKpiCard({
    super.key,
    required this.totalCourses,
    required this.totalLessons,
    required this.totalStudents,
    required this.enrolledStudents,
    required this.pendingRequestsCount,
    required this.onReviewRequests,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.royalNavy,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.heroShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: const GeometricBackgroundPainter(
            strokeColor: Color(0x18FFFFFF),
            spacing: 28,
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'dashboard.executive_overview'.tr(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: pendingRequestsCount > 0
                        ? AppColors.warningAmber.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    pendingRequestsCount > 0
                        ? '$pendingRequestsCount ${'dashboard.pending_triage_alert'.tr()}'
                        : 'dashboard.system_stable'.tr(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: pendingRequestsCount > 0 ? AppColors.warningAmber : Colors.white70,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Triage Alert Banner (Clean human alert component)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onReviewRequests,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: pendingRequestsCount > 0
                        ? AppColors.warningAmber.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: pendingRequestsCount > 0
                          ? AppColors.warningAmber.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        pendingRequestsCount > 0
                            ? PhosphorIconsFill.bellRinging
                            : PhosphorIconsFill.sealCheck,
                        color: pendingRequestsCount > 0 ? AppColors.warningAmber : Colors.white70,
                        size: 19,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          pendingRequestsCount > 0
                              ? 'dashboard.pending_triage_msg'.tr(args: ['$pendingRequestsCount'])
                              : 'dashboard.all_reviewed'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? PhosphorIconsRegular.caretLeft
                            : PhosphorIconsRegular.caretRight,
                        color: Colors.white70,
                        size: 15,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 3 Clean Metric Tiles
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      label: 'dashboard.total_courses_label'.tr(),
                      value: '$totalCourses',
                    ),
                  ),
                  Container(width: 1, height: 28, color: Colors.white12),
                  Expanded(
                    child: _buildMetricItem(
                      label: 'dashboard.published_lessons_label'.tr(),
                      value: '$totalLessons',
                    ),
                  ),
                  Container(width: 1, height: 28, color: Colors.white12),
                  Expanded(
                    child: _buildMetricItem(
                      label: 'dashboard.enrolled_students_label'.tr(),
                      value: '$enrolledStudents',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildMetricItem({required String label, required String value}) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

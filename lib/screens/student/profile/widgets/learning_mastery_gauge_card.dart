import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'student_analytics_painters.dart';

/// بطاقة مقياس إتقان المنهج الدائري وإحصائيات الإنجاز السريعة.
class LearningMasteryGaugeCard extends StatelessWidget {
  final double overallMastery;
  final int completedLessons;
  final int totalLessons;
  final double? avgGradeRatio;
  final int gradedCount;
  final int activeDaysCount;

  const LearningMasteryGaugeCard({
    super.key,
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

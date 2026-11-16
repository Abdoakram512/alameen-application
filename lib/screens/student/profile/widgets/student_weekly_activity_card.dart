import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/watch_log_entry.dart';
import 'student_analytics_painters.dart';

/// بطاقة رسم بياني لنشاط التعلم اليومي للمتدرب خلال آخر 7 أيام.
class StudentWeeklyActivityCard extends StatelessWidget {
  final List<DailyStudyBucket> buckets;
  final int weeklyTotalMinutes;

  const StudentWeeklyActivityCard({
    super.key,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

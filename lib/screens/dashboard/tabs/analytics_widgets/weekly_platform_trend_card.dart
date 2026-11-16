import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/watch_log_entry.dart';
import 'admin_analytics_painters.dart';

/// بطاقة رسم منحنى نشاط المشاهدة خلال آخر 7 أيام على المنصة.
class WeeklyPlatformTrendCard extends StatelessWidget {
  final List<DailyMetricPoint> points;

  const WeeklyPlatformTrendCard({super.key, required this.points});

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                          fontWeight:
                              p.isToday ? FontWeight.w800 : FontWeight.w600,
                          color:
                              p.isToday ? AppColors.primary : AppColors.textMuted,
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

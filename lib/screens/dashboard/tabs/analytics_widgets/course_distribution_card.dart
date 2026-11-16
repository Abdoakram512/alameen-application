import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/watch_log_entry.dart';
import 'admin_analytics_painters.dart';

/// بطاقة توزيع اشتراكات الدورات التدريبية ومصادر السداد.
class CourseDistributionCard extends StatelessWidget {
  final List<DonutSegmentData> segments;
  final Map<String, int> paymentBreakdown;

  const CourseDistributionCard({
    super.key,
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

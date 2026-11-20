import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// بطاقة ترحيبية مؤسسية واضحة تعرض ملخص البرامج التدريبية المتاحة والمشترك بها.
class StudentWelcomeBanner extends StatelessWidget {
  final int totalCourses;
  final int enrolledCount;

  const StudentWelcomeBanner({
    super.key,
    required this.totalCourses,
    required this.enrolledCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderHairline),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'app_name'.tr(),
                  style: AppTextStyles.heading3.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'app_tagline'.tr(),
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _MetricChip(
                      icon: PhosphorIconsRegular.books,
                      label: 'home.courses_available_count'.tr(
                        args: ['$totalCourses'],
                      ),
                      bgColor: AppColors.primaryLight,
                      fgColor: AppColors.primary,
                    ),
                    if (enrolledCount > 0)
                      _MetricChip(
                        icon: PhosphorIconsFill.sealCheck,
                        label: 'home.courses_enrolled_count'.tr(
                          args: ['$enrolledCount'],
                        ),
                        bgColor: AppColors.successLight,
                        fgColor: AppColors.successDark,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color fgColor;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.fgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fgColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.label.copyWith(color: fgColor),
          ),
        ],
      ),
    );
  }
}


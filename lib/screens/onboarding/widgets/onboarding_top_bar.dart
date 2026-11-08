import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// الشريط العلوي لشاشة التعريف بالمنصة مع الشعار وعداد الخطوات وزر التخطي.
class OnboardingTopBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final VoidCallback? onSkip;

  const OnboardingTopBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 20,
        vertical: 8,
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 38 : 44,
            height: compact ? 38 : 44,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderHairline),
            ),
            child: Image.asset(
              'assets/images/website-logo.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'منصة الأمين',
                  style: AppTextStyles.heading3.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!compact)
                  Text(
                    'الخطوة $currentStep من $totalSteps',
                    style: AppTextStyles.caption,
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text('تخطي'),
          ),
        ],
      ),
    );
  }
}


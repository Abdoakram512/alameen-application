import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../app_lottie_box.dart';
import '../buttons/app_primary_button.dart';

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionButtonText;
  final VoidCallback? onActionButtonPressed;
  final Color? iconColor;
  final String lottieAsset;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionButtonText,
    this.onActionButtonPressed,
    this.iconColor,
    this.lottieAsset = 'assets/lottie/empty_state.json',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AppLottieBox(
                  assetPath: lottieAsset,
                  size: 112,
                  fallbackIcon: icon,
                  fallbackColor: iconColor ?? AppColors.primary,
                ),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderHairline),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Icon(
                      icon,
                      size: 16,
                      color: iconColor ?? AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTextStyles.heading3,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionButtonText != null && onActionButtonPressed != null) ...[
              const SizedBox(height: 20),
              AppPrimaryButton(
                text: actionButtonText!,
                onPressed: onActionButtonPressed,
                height: 44,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';

class AppEmptyState extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? icon;
  final String? actionText;
  final VoidCallback? onAction;
  final IconData defaultIconData;

  const AppEmptyState({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.actionText,
    this.onAction,
    this.defaultIconData = PhosphorIconsRegular.tray,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon ??
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    defaultIconData,
                    size: 36,
                    color: AppColors.primary,
                  ),
                ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.heading3.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (description != null && description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 22),
              AppButton(
                text: actionText!,
                onPressed: onAction,
                isFullWidth: false,
                icon: const Icon(PhosphorIconsRegular.plusCircle, size: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

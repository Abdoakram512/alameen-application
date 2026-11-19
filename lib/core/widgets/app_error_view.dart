import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';

class AppErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String title;
  final Widget? icon;
  final String retryButtonText;
  final bool isCompact;

  const AppErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.title = 'حدث خطأ غير متوقع',
    this.icon,
    this.retryButtonText = 'إعادة المحاولة',
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.errorLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.errorBorder),
        ),
        child: Row(
          children: [
            const Icon(PhosphorIconsRegular.warningCircle, color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.caption.copyWith(color: AppColors.errorDark),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 18, color: AppColors.error),
                onPressed: onRetry,
                tooltip: retryButtonText,
              ),
            ],
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon ??
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.errorLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    PhosphorIconsRegular.warningCircle,
                    size: 32,
                    color: AppColors.error,
                  ),
                ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.heading3.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              AppButton(
                text: retryButtonText,
                onPressed: onRetry,
                isFullWidth: false,
                icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

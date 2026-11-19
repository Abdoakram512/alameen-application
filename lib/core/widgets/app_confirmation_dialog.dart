import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AppConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final bool isDestructive;
  final Widget? icon;

  const AppConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'تأكيد',
    this.cancelText = 'إلغاء',
    this.isDestructive = false,
    this.icon,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'تأكيد',
    String cancelText = 'إلغاء',
    bool isDestructive = false,
    Widget? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AppConfirmationDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
        icon: icon,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          icon ??
              Icon(
                isDestructive
                    ? PhosphorIconsRegular.warningOctagon
                    : PhosphorIconsRegular.info,
                color: isDestructive ? AppColors.error : AppColors.primary,
                size: 24,
              ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.heading3.copyWith(
                fontWeight: FontWeight.w700,
                color: isDestructive ? AppColors.error : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            cancelText,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: isDestructive ? AppColors.error : AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            confirmText,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum AppButtonVariant {
  primary,
  secondary,
  outlined,
  danger,
  text,
}

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final Widget? icon;
  final bool isFullWidth;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.isFullWidth = true,
    this.height = 46,
    this.borderRadius = 12,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null && !isLoading;

    Color backgroundColor;
    Color foregroundColor;
    BorderSide? borderSide;

    switch (variant) {
      case AppButtonVariant.primary:
        backgroundColor = isEnabled ? AppColors.primary : AppColors.primary.withValues(alpha: 0.5);
        foregroundColor = Colors.white;
        break;
      case AppButtonVariant.secondary:
        backgroundColor = isEnabled ? AppColors.primaryLight : AppColors.primaryLight.withValues(alpha: 0.5);
        foregroundColor = AppColors.primary;
        break;
      case AppButtonVariant.outlined:
        backgroundColor = Colors.transparent;
        foregroundColor = isEnabled ? AppColors.primary : AppColors.textMuted;
        borderSide = BorderSide(
          color: isEnabled ? AppColors.primary : AppColors.borderHairline,
          width: 1.2,
        );
        break;
      case AppButtonVariant.danger:
        backgroundColor = isEnabled ? AppColors.error : AppColors.error.withValues(alpha: 0.5);
        foregroundColor = Colors.white;
        break;
      case AppButtonVariant.text:
        backgroundColor = Colors.transparent;
        foregroundColor = isEnabled ? AppColors.primary : AppColors.textMuted;
        break;
    }

    Widget content;
    if (isLoading) {
      content = SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
        ),
      );
    } else {
      content = Row(
        mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyLarge.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      );
    }

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: 0,
      shadowColor: Colors.transparent,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: borderSide ?? BorderSide.none,
      ),
    );

    Widget button = SizedBox(
      height: height,
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton(
        style: buttonStyle,
        onPressed: isEnabled ? onPressed : null,
        child: content,
      ),
    );

    return button;
  }
}

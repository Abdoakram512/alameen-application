import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AppLoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;
  final Color color;
  final bool isCentered;

  const AppLoadingIndicator({
    super.key,
    this.message,
    this.size = 36,
    this.color = AppColors.primary,
    this.isCentered = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: size > 24 ? 3 : 2,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        if (message != null && message!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );

    if (isCentered) {
      return Center(child: content);
    }
    return content;
  }
}

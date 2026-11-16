import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// مؤشر تحميل أنيق ومركزي يعتمد على رسوم اللوتي المتحركة
class AppLottieLoading extends StatelessWidget {
  final String? message;
  final double size;

  const AppLottieLoading({
    super.key,
    this.message,
    this.size = 110,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Lottie.asset(
              'assets/lottie/learning_orbit.json',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            ),
          ),
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

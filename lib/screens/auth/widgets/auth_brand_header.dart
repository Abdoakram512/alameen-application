import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// ترويسة الهوية المؤسسية لمركز الأمين في شاشات الدخول وإنشاء الحساب.
class AuthBrandHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool compact;

  const AuthBrandHeader({
    super.key,
    this.title = 'مركز الأمين للتخاطب والتأهيل',
    required this.subtitle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final logoBoxSize = compact ? 74.0 : 86.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: logoBoxSize,
          height: logoBoxSize,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.borderHairline, width: 1.2),
            boxShadow: AppColors.heroShadow,
          ),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(height: compact ? 12 : 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.heading1.copyWith(
            fontSize: compact ? 21 : 23,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 13.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}


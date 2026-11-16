import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

class LoginHeader extends StatelessWidget {
  final bool compact;

  const LoginHeader({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final logoDimension = compact ? 76.0 : 92.0;

    return Column(
      children: [
        Container(
          width: logoDimension,
          height: logoDimension,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.borderHairline, width: 1.2),
            boxShadow: AppColors.cardShadow,
          ),
          child: Image.asset(
            AppConstants.logoAsset,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.admin_panel_settings_rounded,
                color: AppColors.primary,
                size: 44,
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          AppConstants.appName,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.royalNavy,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        const Text(
          AppConstants.appNameAr,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 14,
                color: AppColors.royalNavy,
              ),
              const SizedBox(width: 6),
              Text(
                'auth.badge'.tr(),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.royalNavy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_info_tile.dart';

class MuxIntegrationCard extends StatelessWidget {
  final bool isConfigured;
  final VoidCallback onConfigureTap;

  const MuxIntegrationCard({
    super.key,
    required this.isConfigured,
    required this.onConfigureTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderHairline),
        boxShadow: AppColors.cardShadow,
      ),
      child: AppInfoTile(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderRadius: BorderRadius.circular(16),
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppColors.accentCobaltLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.video_settings_rounded,
            color: AppColors.accentCobalt,
            size: 22,
          ),
        ),
        title: const Text(
          'إعدادات خدمة رفع الفيديو (Mux)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: const Text(
          'تهيئة مفاتيح جلسة الرفع المباشر للمحاضرات المسجلة',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: isConfigured
                    ? AppColors.successLight
                    : AppColors.warningLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isConfigured
                      ? AppColors.successBorder
                      : AppColors.warningBorder,
                  width: 0.8,
                ),
              ),
              child: Text(
                isConfigured ? 'متصل' : 'غير مهيأ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isConfigured
                      ? AppColors.successDark
                      : AppColors.warningDark,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.textMuted,
            ),
          ],
        ),
        onTap: onConfigureTap,
      ),
    );
  }
}


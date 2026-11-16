import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import '../core/config/app_config.dart';
import '../core/theme/app_colors.dart';

class AdminLanguageSwitchButton extends StatelessWidget {
  final bool compact;

  const AdminLanguageSwitchButton({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentCode = context.locale.languageCode;
    final isArabic = currentCode == 'ar';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final nextLocale = isArabic ? AppConfig.englishLocale : AppConfig.arabicLocale;
          await context.setLocale(nextLocale);
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderHairline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.language_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                isArabic ? 'English' : 'العربية',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


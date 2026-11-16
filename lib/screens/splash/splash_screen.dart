import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_lottie_box.dart';
import '../onboarding/widgets/onboarding_backdrop_painter.dart';

/// شاشة البداية المؤسسية لبوابة المتدرب — مركز الأمين للتخاطب.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  String _safeTr(String key, String fallback) {
    try {
      final val = key.tr();
      if (val.isEmpty || val == key) return fallback;
      return val;
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: RepaintBoundary(
        child: CustomPaint(
          painter: const OnboardingBackdropPainter(pageProgress: 0.5),
          child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: AppColors.borderHairline,
                          width: 1.2,
                        ),
                        boxShadow: AppColors.heroShadow,
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _safeTr('app_name', 'مركز الأمين للتخاطب'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.displayLarge.copyWith(
                        fontSize: 26,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _safeTr('app_tagline', 'بوابة المتدرب التفاعلية'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const AppLottieBox(
                      assetPath: 'assets/lottie/learning_orbit.json',
                      size: 56,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _safeTr('splash_loading', 'جاري تهيئة بوابة مركز الأمين للتخاطب...'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

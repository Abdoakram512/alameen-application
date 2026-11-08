import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_lottie_box.dart';

/// بطاقة العرض البصري لشاشة التعريف بطبقات عمق وحركة Parallax سلسة.
class OnboardingVisualCard extends StatelessWidget {
  final String imageAsset;
  final String semanticLabel;
  final String categoryTag;
  final IconData tagIcon;
  final int stepNumber;
  final int totalSteps;
  final Alignment imageAlignment;
  final double parallaxOffset;
  final double? fixedHeight;

  const OnboardingVisualCard({
    super.key,
    required this.imageAsset,
    required this.semanticLabel,
    required this.categoryTag,
    this.tagIcon = PhosphorIconsRegular.graduationCap,
    required this.stepNumber,
    required this.totalSteps,
    this.imageAlignment = Alignment.center,
    this.parallaxOffset = 0,
    this.fixedHeight,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 350;

    final cardBody = Stack(
      fit: StackFit.expand,
      children: [
        // طبقة خلفية مائلة تمنح إحساساً بالعمق المعماري النظيف
        if (!compact)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Transform.rotate(
              angle: -0.022,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ),
          ),
        // الإطار الرئيسي للصورة
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.borderHairline, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F012383),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
              BoxShadow(
                color: Color(0x060F172A),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.all(compact ? 6 : 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: AppColors.primaryLight,
                  child: ClipRect(
                    child: Transform.translate(
                      offset: Offset(parallaxOffset, 0),
                      child: Transform.scale(
                        scale: 1.07,
                        child: Image.asset(
                          imageAsset,
                          fit: BoxFit.cover,
                          alignment: imageAlignment,
                          semanticLabel: semanticLabel,
                        ),
                      ),
                    ),
                  ),
                ),
                // تدرج سفلي متوازن يبرز الشارة دون إظلام الصورة
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF011652).withValues(alpha: 0.14),
                        Colors.transparent,
                        const Color(0xFF011652).withValues(alpha: 0.62),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
                // شارة Lottie العلوية الهادئة
                if (!compact)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppLottieBox(
                            assetPath: 'assets/lottie/learning_orbit.json',
                            size: 20,
                            fallbackIcon: PhosphorIconsFill.sparkle,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '0$stepNumber / 0$totalSteps',
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // شارة التصنيف السفلية
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tagIcon, size: 15, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          categoryTag,
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.primary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (fixedHeight != null) {
      return SizedBox(
        height: fixedHeight,
        width: double.infinity,
        child: cardBody,
      );
    }

    return SizedBox(width: double.infinity, child: cardBody);
  }
}

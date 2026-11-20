import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_directional_icons.dart';
import 'onboarding_progress_dots.dart';

/// تذييل شاشة التعريف مع مؤشر التقدم الحلقي المرسوم بـ CustomPainter وأزرار واضحة التسلسل.
class OnboardingActionFooter extends StatelessWidget {
  final int currentIndex;
  final int totalSteps;
  final bool isLastSlide;
  final bool isSaving;
  final VoidCallback? onPreviousPressed;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onSignInPressed;

  const OnboardingActionFooter({
    super.key,
    required this.currentIndex,
    required this.totalSteps,
    required this.isLastSlide,
    required this.isSaving,
    this.onPreviousPressed,
    required this.onPrimaryPressed,
    required this.onSignInPressed,
  });

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
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 620 || size.width < 350;
    final progress = (currentIndex + 1) / math.max(1, totalSteps);

    return Container(
      margin: EdgeInsets.fromLTRB(
        compact ? 14 : 20,
        4,
        compact ? 14 : 20,
        compact ? 8 : 14,
      ),
      padding: EdgeInsets.fromLTRB(
        compact ? 14 : 18,
        compact ? 12 : 16,
        compact ? 14 : 18,
        compact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderHairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A012383),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OnboardingProgressDots(
            currentIndex: currentIndex,
            count: totalSteps,
          ),
          SizedBox(height: compact ? 10 : 14),
          Row(
            children: [
              if (currentIndex > 0 && onPreviousPressed != null) ...[
                SizedBox(
                  width: compact ? 44 : 48,
                  height: compact ? 44 : 50,
                  child: OutlinedButton(
                    onPressed: isSaving ? null : onPreviousPressed,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.borderHairline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Icon(
                      AppDirectionalIcons.backCaret(context),
                      size: 19,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: SizedBox(
                  height: compact ? 44 : 50,
                  child: FilledButton(
                    onPressed: isSaving ? null : onPrimaryPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: Text(
                              isSaving
                                  ? _safeTr('saving', 'جارٍ الحفظ...')
                                  : isLastSlide
                                      ? _safeTr('onboarding_start_now', 'ابدأ الآن')
                                      : _safeTr('next', 'التالي'),
                              key: ValueKey<String>(
                                '$isSaving-$isLastSlide',
                              ),
                              style: TextStyle(
                                fontSize: compact ? 14 : 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        if (!compact && !isSaving) ...[
                          const SizedBox(width: 10),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.25, end: progress),
                            duration: const Duration(milliseconds: 360),
                            curve: Curves.easeOutCubic,
                            builder: (context, animProgress, child) {
                              return CustomPaint(
                                painter: _StepRingPainter(
                                  progress: animProgress,
                                ),
                                child: SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: Center(child: child),
                                ),
                              );
                            },
                            child: Icon(
                              isLastSlide
                                  ? PhosphorIconsRegular.rocketLaunch
                                  : AppDirectionalIcons.forwardIcon(context),
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: isSaving ? null : onSignInPressed,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                visualDensity: compact
                    ? VisualDensity.compact
                    : VisualDensity.standard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(PhosphorIconsRegular.signIn, size: 16),
              label: const Text(
                'لدي حساب بالفعل',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRingPainter extends CustomPainter {
  final double progress;

  const _StepRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 1.5;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.white.withValues(alpha: 0.24);
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _StepRingPainter oldDelegate) {
    return (oldDelegate.progress - progress).abs() > 0.005;
  }
}

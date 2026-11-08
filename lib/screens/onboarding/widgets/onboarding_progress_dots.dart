import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// مؤشر التقدم النقطي المتوافق مع قارئات الشاشة.
class OnboardingProgressDots extends StatelessWidget {
  final int currentIndex;
  final int count;

  const OnboardingProgressDots({
    super.key,
    required this.currentIndex,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'الخطوة ${currentIndex + 1} من $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          count,
          (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == currentIndex ? 26 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == currentIndex
                  ? AppColors.primary
                  : const Color(0xFFCFDBEA),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}


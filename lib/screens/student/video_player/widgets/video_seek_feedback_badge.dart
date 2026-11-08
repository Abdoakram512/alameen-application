import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// شارة التغذية الراجعة عند النقر المزدوج للتقديم أو التأخير 10 ثوانٍ.
class VideoSeekFeedbackBadge extends StatelessWidget {
  final bool isForward;
  final int seconds;

  const VideoSeekFeedbackBadge({
    super.key,
    required this.isForward,
    required this.seconds,
  });

  @override
  Widget build(BuildContext context) {
    if (seconds == 0) return const SizedBox.shrink();

    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isForward ? Icons.forward_10_rounded : Icons.replay_10_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                isForward ? '+${seconds.abs()} ثوانٍ' : '-${seconds.abs()} ثوانٍ',
                style: const TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


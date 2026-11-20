import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// زر المتابعة عبر Google مع رسم متجهي (Vector CustomPaint) لشعار Google الرباعي الألوان.
class GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final String label;

  const GoogleSignInButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
    this.label = 'المتابعة باستخدام حساب Google',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          alignment: Alignment.center,
          side: const BorderSide(color: AppColors.borderHairline, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CustomPaint(painter: _GoogleLogoPainter()),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.button.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.19;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Red top arc
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -math.pi * 0.78, math.pi * 0.56, false, paint);

    // Yellow left arc
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, math.pi * 0.78, math.pi * 0.44, false, paint);

    // Green bottom arc
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, math.pi * 0.22, math.pi * 0.56, false, paint);

    // Blue right arc + crossbar
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -math.pi * 0.04, math.pi * 0.28, false, paint);

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.50,
        size.height * 0.41,
        size.width * 0.46,
        stroke * 0.92,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


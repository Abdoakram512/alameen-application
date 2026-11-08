import 'package:flutter/material.dart';

/// كليبر تذكرة احترافية مع ثقوب نصف دائرية على الجانبين
class TicketNotchClipper extends CustomClipper<Path> {
  final double notchRadius;
  final double notchPositionRatio; // 0.0 to 1.0 (vertical percentage where the notch appears)
  final double cornerRadius;

  TicketNotchClipper({
    this.notchRadius = 12.0,
    this.notchPositionRatio = 0.65,
    this.cornerRadius = 16.0,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final notchY = size.height * notchPositionRatio;

    // Top-left corner
    path.moveTo(0, cornerRadius);
    path.arcToPoint(
      Offset(cornerRadius, 0),
      radius: Radius.circular(cornerRadius),
    );

    // Top edge
    path.lineTo(size.width - cornerRadius, 0);

    // Top-right corner
    path.arcToPoint(
      Offset(size.width, cornerRadius),
      radius: Radius.circular(cornerRadius),
    );

    // Right edge down to notch
    path.lineTo(size.width, notchY - notchRadius);

    // Right notch (inward arc)
    path.arcToPoint(
      Offset(size.width, notchY + notchRadius),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );

    // Right edge down to bottom-right corner
    path.lineTo(size.width, size.height - cornerRadius);
    path.arcToPoint(
      Offset(size.width - cornerRadius, size.height),
      radius: Radius.circular(cornerRadius),
    );

    // Bottom edge
    path.lineTo(cornerRadius, size.height);

    // Bottom-left corner
    path.arcToPoint(
      Offset(0, size.height - cornerRadius),
      radius: Radius.circular(cornerRadius),
    );

    // Left edge up to notch
    path.lineTo(0, notchY + notchRadius);

    // Left notch (inward arc)
    path.arcToPoint(
      Offset(0, notchY - notchRadius),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant TicketNotchClipper oldClipper) =>
      oldClipper.notchRadius != notchRadius ||
      oldClipper.notchPositionRatio != notchPositionRatio ||
      oldClipper.cornerRadius != cornerRadius;
}


import 'package:flutter/material.dart';

/// كليبر هندسي يرسم نهاية انسيابية مقوسة لرأس الصفحة
class HeaderWaveClipper extends CustomClipper<Path> {
  final double waveHeight;

  HeaderWaveClipper({this.waveHeight = 28});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - waveHeight);

    final firstControlPoint = Offset(size.width * 0.25, size.height);
    final firstEndPoint = Offset(size.width * 0.5, size.height - (waveHeight * 0.4));
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    final secondControlPoint = Offset(size.width * 0.75, size.height - waveHeight * 1.3);
    final secondEndPoint = Offset(size.width, size.height - (waveHeight * 0.3));
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant HeaderWaveClipper oldClipper) =>
      oldClipper.waveHeight != waveHeight;
}


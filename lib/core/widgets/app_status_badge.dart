import 'package:flutter/material.dart';

enum AppStatusType {
  success,
  warning,
  error,
  info,
  neutral,
}

class AppStatusBadge extends StatelessWidget {
  final String label;
  final AppStatusType statusType;
  final Widget? icon;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const AppStatusBadge({
    super.key,
    required this.label,
    this.statusType = AppStatusType.neutral,
    this.icon,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (statusType) {
      case AppStatusType.success:
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF047857);
        break;
      case AppStatusType.warning:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        break;
      case AppStatusType.error:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        break;
      case AppStatusType.info:
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        break;
      case AppStatusType.neutral:
        bg = const Color(0xFFE5E7EB);
        fg = const Color(0xFF374151);
        break;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:math';
import 'package:flutter/material.dart';

/// علامة مائية متحركة تحمي الملكية الفكرية مع إخفاء جزء من البريد الشخصي للطالب.
class VideoWatermarkOverlay extends StatelessWidget {
  final Alignment alignment;
  final String studentName;
  final String studentEmail;
  final String studentUid;
  final String studentIp;

  const VideoWatermarkOverlay({
    super.key,
    required this.alignment,
    required this.studentName,
    required this.studentEmail,
    required this.studentUid,
    this.studentIp = '',
  });

  static String maskEmail(String email) {
    final trimmed = email.trim();
    final atIndex = trimmed.indexOf('@');
    if (atIndex <= 1) return trimmed;
    final visibleCount = min(2, atIndex);
    final prefix = trimmed.substring(0, visibleCount);
    final domain = trimmed.substring(atIndex);
    return '$prefix***$domain';
  }

  @override
  Widget build(BuildContext context) {
    final shortUid = studentUid.isEmpty
        ? ''
        : '#${studentUid.substring(0, min(6, studentUid.length)).toUpperCase()}';
    final maskedEmail = maskEmail(studentEmail);
    final label = [
      studentName,
      if (maskedEmail.isNotEmpty) maskedEmail,
      if (studentIp.isNotEmpty) studentIp,
      if (shortUid.isNotEmpty) shortUid,
    ].join(' • ');

    return IgnorePointer(
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeInOut,
        alignment: alignment,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: Colors.white.withValues(alpha: 0.78),
                size: 12,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// شبكة مؤشرات الإنجاز التدريبي للطالب بأيقونات واقعية وأرقام متساوية العرض.
class StudentStatsGrid extends StatelessWidget {
  final int enrolledCount;
  final int completedLessonsCount;
  final String watchTimeFormatted;

  const StudentStatsGrid({
    super.key,
    required this.enrolledCount,
    required this.completedLessonsCount,
    required this.watchTimeFormatted,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;

    String safeTr(String key, String fallback) {
      try {
        final val = key.tr();
        if (val.isEmpty || val == key) return fallback;
        return val;
      } catch (_) {
        return fallback;
      }
    }

    final cards = [
      _StatTile(
        icon: PhosphorIconsRegular.graduationCap,
        accentColor: AppColors.primary,
        value: '$enrolledCount',
        label: safeTr('profile.enrolled_courses', 'دورات مشترك بها'),
      ),
      _StatTile(
        icon: PhosphorIconsRegular.checkCircle,
        accentColor: AppColors.success,
        value: '$completedLessonsCount',
        label: safeTr('profile.completed_lessons', 'محاضرة مكتملة'),
      ),
      _StatTile(
        icon: PhosphorIconsRegular.clockCountdown,
        accentColor: const Color(0xFF1D4ED8),
        value: watchTimeFormatted,
        label: safeTr('profile.total_watch_time', 'وقت التعلم المسجل'),
      ),
    ];

    if (compact) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 10),
              Expanded(child: cards[1]),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: cards[2]),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 12),
        Expanded(child: cards[1]),
        const SizedBox(width: 12),
        Expanded(child: cards[2]),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.accentColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderHairline),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTextStyles.heading3.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

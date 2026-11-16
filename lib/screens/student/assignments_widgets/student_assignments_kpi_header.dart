import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_directional_icons.dart';

/// بطاقة ملخص مؤشرات أداء التكليفات والواجبات للطلاب.
class StudentAssignmentsKpiHeader extends StatelessWidget {
  final int submittedCount;
  final int pendingCount;
  final int? avgScore;

  const StudentAssignmentsKpiHeader({
    super.key,
    required this.submittedCount,
    required this.pendingCount,
    required this.avgScore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderHairline),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: _KpiBox(
              title: 'تم تسليمها',
              value: '$submittedCount',
              icon: AppDirectionalIcons.checkCircle(
                color: AppColors.successDark,
                size: 18,
              ),
              color: AppColors.successLight,
              textColor: AppColors.successDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _KpiBox(
              title: 'متبقية',
              value: '$pendingCount',
              icon: const Icon(
                PhosphorIconsRegular.clock,
                color: AppColors.warningDark,
                size: 18,
              ),
              color: AppColors.warningLight,
              textColor: AppColors.warningDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _KpiBox(
              title: 'متوسط الدرجات',
              value: avgScore != null ? '$avgScore%' : '—',
              icon: const Icon(
                PhosphorIconsRegular.chartLineUp,
                color: AppColors.primary,
                size: 18,
              ),
              color: AppColors.primaryLight,
              textColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiBox extends StatelessWidget {
  final String title;
  final String value;
  final Widget icon;
  final Color color;
  final Color textColor;

  const _KpiBox({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.heading2.copyWith(
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

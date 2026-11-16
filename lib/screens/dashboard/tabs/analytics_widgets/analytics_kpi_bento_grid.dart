import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// شبكة بطاقات المؤشرات الرئيسية (Bento KPIs) في لوحة الإحصائيات العامة للإدارة.
class AnalyticsKpiBentoGrid extends StatelessWidget {
  final double estimatedRevenueEgp;
  final int totalWatchMinutes;
  final int activeStudentsCount;
  final int totalStudentsCount;
  final int pendingActionCount;
  final VoidCallback? onTapPendingActions;

  const AnalyticsKpiBentoGrid({
    super.key,
    required this.estimatedRevenueEgp,
    required this.totalWatchMinutes,
    required this.activeStudentsCount,
    required this.totalStudentsCount,
    required this.pendingActionCount,
    this.onTapPendingActions,
  });

  String _formatWatchDuration(BuildContext context, int totalMinutes) {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final hours = totalMinutes ~/ 60;
    final rem = totalMinutes % 60;
    if (hours > 0) {
      return isAr ? '$hours س و $rem د' : '${hours}h ${rem}m';
    }
    return isAr ? '$totalMinutes دقيقة' : '$totalMinutes min';
  }

  String _formatMoney(double amount) {
    final intVal = amount.round();
    final raw = intVal.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final posFromEnd = raw.length - i;
      buffer.write(raw[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }
    return '${buffer.toString()} ${'currency'.tr()}';
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final activationRate = totalStudentsCount <= 0
        ? 0
        : ((activeStudentsCount / totalStudentsCount) * 100).round();

    return ResponsiveCardGrid(
      minItemWidth: 225,
      maxColumns: 4,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _KpiTile(
          icon: PhosphorIconsRegular.coins,
          accentColor: AppColors.primary,
          badgeText: isAr ? 'قيمة الاشتراكات المفعّلة' : 'Active Subscriptions Value',
          value: _formatMoney(estimatedRevenueEgp),
          subtitle: isAr ? 'محسوبة من الدورات الممنوحة فعلياً' : 'Calculated from unlocked courses',
        ),
        _KpiTile(
          icon: PhosphorIconsRegular.clockCountdown,
          accentColor: const Color(0xFF2563EB),
          badgeText: isAr ? 'إجمالي ساعات المشاهدة' : 'Total Watch Hours',
          value: _formatWatchDuration(context, totalWatchMinutes),
          subtitle: isAr ? 'عبر جميع حسابات المتدربين' : 'Across all registered students',
        ),
        _KpiTile(
          icon: PhosphorIconsRegular.usersThree,
          accentColor: AppColors.success,
          badgeText: isAr ? 'معدل التفعيل النشط' : 'Active Enrollment Rate',
          value: '$activationRate% ($activeStudentsCount/$totalStudentsCount)',
          subtitle: isAr ? 'متدربون مشتركـون بدورة أو أكثر' : 'Students enrolled in courses',
        ),
        _KpiTile(
          icon: PhosphorIconsRegular.bellRinging,
          accentColor:
              pendingActionCount > 0 ? AppColors.warning : AppColors.textMuted,
          badgeText: isAr ? 'مهام بانتظار المراجعة' : 'Pending Tasks',
          value: '$pendingActionCount ${isAr ? 'عنصر' : 'items'}',
          subtitle: isAr ? 'طلبات التحاق وتكليفات غير مقيمة' : 'Access requests & ungraded tasks',
          onTap: onTapPendingActions,
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String badgeText;
  final String value;
  final String subtitle;
  final VoidCallback? onTap;

  const _KpiTile({
    required this.icon,
    required this.accentColor,
    required this.badgeText,
    required this.value,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderHairline),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: accentColor, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      badgeText,
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    const Icon(
                      PhosphorIconsRegular.arrowUpLeft,
                      size: 15,
                      color: AppColors.textMuted,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: AppTextStyles.heading2.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

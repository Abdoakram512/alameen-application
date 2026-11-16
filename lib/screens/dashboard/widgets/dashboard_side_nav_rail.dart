import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';

/// شريط تنقل جانبي للشاشات العريضة (Tablet Landscape / Desktop >= 840px).
class DashboardSideNavRail extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final int pendingCount;

  const DashboardSideNavRail({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: BorderDirectional(
          end: BorderSide(color: AppColors.borderHairline, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  context.locale.languageCode == 'ar' ? 'أقسام الإدارة' : 'Administration',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildNavTile(
                index: 0,
                label: 'nav.courses'.tr(),
                icon: PhosphorIconsRegular.books,
                activeIcon: PhosphorIconsFill.books,
              ),
              const SizedBox(height: 6),
              _buildNavTile(
                index: 1,
                label: 'nav.assignments'.tr(),
                icon: PhosphorIconsRegular.notebook,
                activeIcon: PhosphorIconsFill.notebook,
              ),
              const SizedBox(height: 6),
              _buildNavTile(
                index: 2,
                label: 'nav.analytics'.tr(),
                icon: PhosphorIconsRegular.chartPolar,
                activeIcon: PhosphorIconsFill.chartPolar,
              ),
              const SizedBox(height: 6),
              _buildNavTile(
                index: 3,
                label: 'nav.students'.tr(),
                icon: PhosphorIconsRegular.usersThree,
                activeIcon: PhosphorIconsFill.usersThree,
              ),
              const SizedBox(height: 6),
              _buildNavTile(
                index: 4,
                label: 'nav.requests'.tr(),
                icon: PhosphorIconsRegular.receipt,
                activeIcon: PhosphorIconsFill.receipt,
                badgeCount: pendingCount,
              ),
              const SizedBox(height: 6),
              _buildNavTile(
                index: 5,
                label: 'nav.settings'.tr(),
                icon: PhosphorIconsRegular.userGear,
                activeIcon: PhosphorIconsFill.userGear,
              ),
              const SizedBox(height: 6),
              _buildNavTile(
                index: 6,
                label: 'nav.admins'.tr(),
                icon: PhosphorIconsRegular.shieldCheck,
                activeIcon: PhosphorIconsFill.shieldCheck,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavTile({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    int badgeCount = 0,
  }) {
    final isSelected = currentIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onIndexChanged(index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.borderHairline : Colors.transparent,
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                size: 20,
                color: isSelected ? AppColors.royalNavy : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? AppColors.royalNavy : AppColors.textPrimary,
                  ),
                ),
              ),
              if (badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warningAmber,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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

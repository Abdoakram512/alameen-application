import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';

/// شريط التنقل السفلي لتطبيق الإدارة (5 تبويبات بأيقونات Phosphor الواقعية).
class DashboardBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final int pendingCount;

  const DashboardBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.borderHairline, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                label: 'nav.courses'.tr(),
                icon: PhosphorIconsRegular.books,
                activeIcon: PhosphorIconsFill.books,
              ),
              _buildNavItem(
                index: 1,
                label: 'nav.assignments'.tr(),
                icon: PhosphorIconsRegular.notebook,
                activeIcon: PhosphorIconsFill.notebook,
              ),
              _buildNavItem(
                index: 2,
                label: 'nav.analytics'.tr(),
                icon: PhosphorIconsRegular.chartPolar,
                activeIcon: PhosphorIconsFill.chartPolar,
              ),
              _buildNavItem(
                index: 3,
                label: 'nav.students'.tr(),
                icon: PhosphorIconsRegular.usersThree,
                activeIcon: PhosphorIconsFill.usersThree,
              ),
              _buildNavItem(
                index: 4,
                label: 'nav.requests'.tr(),
                icon: PhosphorIconsRegular.receipt,
                activeIcon: PhosphorIconsFill.receipt,
                badgeCount: pendingCount,
              ),
              _buildNavItem(
                index: 5,
                label: 'nav.settings'.tr(),
                icon: PhosphorIconsRegular.userGear,
                activeIcon: PhosphorIconsFill.userGear,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    int badgeCount = 0,
  }) {
    return Builder(
      builder: (context) {
        final isSelected = currentIndex == index;

        final itemContent = InkWell(
          onTap: () => onIndexChanged(index),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? 11 : 8,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryLight : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Badge(
                  isLabelVisible: badgeCount > 0,
                  backgroundColor: AppColors.warningAmber,
                  textColor: Colors.white,
                  label: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    size: 20,
                    color: isSelected ? AppColors.royalNavy : AppColors.textSecondary,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.royalNavy,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );

        return itemContent;
      },
    );
  }
}

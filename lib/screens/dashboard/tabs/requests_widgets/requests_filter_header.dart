import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/access_request.dart';

/// رأس قسم طلبات الانضمام مع حقل البحث وتبويبات تصفية الحالات الواضحة بصرياً.
class RequestsFilterHeader extends StatelessWidget {
  final int pendingCount;
  final int approvedCount;
  final int rejectedCount;
  final int allCount;
  final String? errorMessage;
  final TextEditingController searchController;
  final String query;
  final AccessStatus? selectedFilter;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<AccessStatus?> onFilterChanged;

  const RequestsFilterHeader({
    super.key,
    required this.pendingCount,
    this.approvedCount = 0,
    this.rejectedCount = 0,
    this.allCount = 0,
    this.errorMessage,
    required this.searchController,
    required this.query,
    required this.selectedFilter,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'requests.title'.tr(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.royalNavy,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'مراجعة واعتماد إيصالات الدفع وطلبات الالتحاق بالكورسات',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (pendingCount > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.warningBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.warningDark,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$pendingCount طلب جديد',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.warningDark,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: searchController,
          onChanged: onQueryChanged,
          decoration: InputDecoration(
            labelText: 'requests.search_hint'.tr(),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'requests.clear_search'.tr(),
                    icon: const Icon(Icons.close),
                    onPressed: onClearQuery,
                  ),
          ),
        ),
        const SizedBox(height: 14),

        // تبويبات الحالات الثلاثة المنفصلة بصرياً بدقة تمنع التشتت
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTriageTab(
                label: 'بانتظار المراجعة',
                count: pendingCount,
                isSelected: selectedFilter == AccessStatus.pending,
                activeColor: AppColors.warningDark,
                activeBg: AppColors.warningLight,
                activeBorder: AppColors.warningBorder,
                icon: Icons.hourglass_top_rounded,
                onTap: () => onFilterChanged(AccessStatus.pending),
              ),
              const SizedBox(width: 8),
              _buildTriageTab(
                label: 'الطلبات المقبولة',
                count: approvedCount,
                isSelected: selectedFilter == AccessStatus.approved,
                activeColor: AppColors.successDark,
                activeBg: AppColors.successLight,
                activeBorder: AppColors.successBorder,
                icon: Icons.check_circle_outline_rounded,
                onTap: () => onFilterChanged(AccessStatus.approved),
              ),
              const SizedBox(width: 8),
              _buildTriageTab(
                label: 'الطلبات المرفوضة',
                count: rejectedCount,
                isSelected: selectedFilter == AccessStatus.rejected,
                activeColor: AppColors.errorDark,
                activeBg: AppColors.errorLight,
                activeBorder: AppColors.errorBorder,
                icon: Icons.cancel_outlined,
                onTap: () => onFilterChanged(AccessStatus.rejected),
              ),
              const SizedBox(width: 8),
              _buildTriageTab(
                label: 'جميع الطلبات',
                count: allCount,
                isSelected: selectedFilter == null,
                activeColor: AppColors.royalNavy,
                activeBg: AppColors.primaryLight,
                activeBorder: AppColors.primaryLight,
                icon: Icons.all_inbox_rounded,
                onTap: () => onFilterChanged(null),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTriageTab({
    required String label,
    required int count,
    required bool isSelected,
    required Color activeColor,
    required Color activeBg,
    required Color activeBorder,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeBorder : AppColors.borderHairline,
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeColor : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? activeColor : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor
                    : AppColors.surfaceLevel2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

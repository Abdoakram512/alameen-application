import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// شريط بحث وتصفية الطلاب حسب حالة الاشتراك.
class StudentsFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final String selectedFilter;
  final int totalCount;
  final int enrolledCount;
  final int notEnrolledCount;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onFilterChanged;

  const StudentsFilterBar({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.selectedFilter,
    required this.totalCount,
    required this.enrolledCount,
    required this.notEnrolledCount,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.borderHairline,
              width: 1.2,
            ),
            boxShadow: AppColors.cardShadow,
          ),
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'students.search_hint'.tr(),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.royalNavy,
              ),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      tooltip: 'students.clear_search'.tr(),
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: onClearSearch,
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildChip('students.filter_all'.tr(args: ['$totalCount']), 'all'),
            _buildChip('students.filter_enrolled'.tr(args: ['$enrolledCount']), 'enrolled'),
            _buildChip('students.filter_not_enrolled'.tr(args: ['$notEnrolledCount']), 'notEnrolled'),
          ],
        ),
      ],
    );
  }

  Widget _buildChip(String label, String value) {
    final isSelected = selectedFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onFilterChanged(value),
      selectedColor: AppColors.primaryLight,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AppColors.royalNavy : AppColors.borderHairline,
          width: isSelected ? 1.2 : 0.8,
        ),
      ),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.royalNavy : AppColors.textSecondary,
      ),
    );
  }
}


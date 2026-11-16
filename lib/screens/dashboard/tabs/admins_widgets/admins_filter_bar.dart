import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// شريط البحث والتصفية لقائمة المشرفين الإداريين.
class AdminsFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onSearchChanged;
  final bool isAr;

  const AdminsFilterBar({
    super.key,
    required this.searchController,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onClearSearch,
    required this.onSearchChanged,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderHairline),
      ),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: isAr
                  ? 'البحث باسم المشرف، بريده، أو رقم هاتفه...'
                  : 'Search by admin name, email, or phone...',
              prefixIcon: const Icon(Icons.search_rounded, size: 22),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: onClearSearch,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
              ),
            ),
          ),
          const Divider(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilterChip(
                label: Text('requests.all'.tr()),
                selected: selectedFilter == 'all',
                onSelected: (_) => onFilterChanged('all'),
              ),
              FilterChip(
                label: Text('admin_management.active'.tr()),
                selected: selectedFilter == 'active',
                onSelected: (_) => onFilterChanged('active'),
              ),
              FilterChip(
                label: Text('admin_management.inactive'.tr()),
                selected: selectedFilter == 'inactive',
                onSelected: (_) => onFilterChanged('inactive'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

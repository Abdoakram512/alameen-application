import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// شريط البحث وتصفية التخصصات التدريبية مع حفظ حالة حقل البحث.
class CourseSearchFilterBar extends StatefulWidget {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategorySelected;

  const CourseSearchFilterBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onSearchChanged,
    required this.onCategorySelected,
  });

  @override
  State<CourseSearchFilterBar> createState() => _CourseSearchFilterBarState();
}

class _CourseSearchFilterBarState extends State<CourseSearchFilterBar> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {});
            widget.onSearchChanged(value);
          },
          decoration: InputDecoration(
            hintText: 'ابحث باسم الدورة أو المحاضر أو التخصص...',
            prefixIcon: const Icon(
              PhosphorIconsRegular.magnifyingGlass,
              color: AppColors.textMuted,
              size: 19,
            ),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'مسح البحث',
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                      widget.onSearchChanged('');
                    },
                    icon: const Icon(PhosphorIconsRegular.x, size: 17),
                  ),
          ),
        ),
        if (widget.categories.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = widget.categories[index];
                final isSelected = widget.selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) => widget.onCategorySelected(cat),
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  showCheckmark: false,
                  labelStyle: AppTextStyles.bodyMedium.copyWith(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.borderHairline,
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}


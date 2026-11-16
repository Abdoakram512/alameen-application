import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/assignment_submission.dart';
import '../../../../models/course.dart';

/// شريط البحث والتصفية لتسليمات المتدربين في لوحة التحكم الإدارية.
class AssignmentsFilterHeader extends StatelessWidget {
  final bool isAr;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final List<Course> courses;
  final String? selectedCourseId;
  final ValueChanged<String?> onCourseChanged;
  final String statusFilter;
  final ValueChanged<String> onStatusChanged;
  final List<AssignmentSubmission> allSubmissions;

  const AssignmentsFilterHeader({
    super.key,
    required this.isAr,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.courses,
    required this.selectedCourseId,
    required this.onCourseChanged,
    required this.statusFilter,
    required this.onStatusChanged,
    required this.allSubmissions,
  });

  @override
  Widget build(BuildContext context) {
    final pendingCount = allSubmissions.where((s) => !s.isGraded).length;
    final gradedCount = allSubmissions.where((s) => s.isGraded).length;
    final gradedList = allSubmissions
        .where((s) => s.isGraded && s.score != null)
        .toList();
    final avgScore = gradedList.isEmpty
        ? 0
        : (gradedList.map((s) => s.score!).reduce((a, b) => a + b) /
                gradedList.length)
            .round();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: isAr
                        ? 'ابحث باسم المتدرب، البريد، أو التكليف...'
                        : 'Search by student name, email, or task...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: onClearSearch,
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.borderHairline),
                    ),
                  ),
                  onChanged: onSearchChanged,
                ),
              ),
              const SizedBox(width: 12),
              // Course filter dropdown
              DropdownButton<String?>(
                value: selectedCourseId,
                hint: Text(
                  isAr ? 'جميع الكورسات' : 'All Courses',
                  style: const TextStyle(fontSize: 13),
                ),
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      isAr ? 'جميع الكورسات' : 'All Courses',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  ...courses.map(
                    (c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Text(
                          c.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ],
                onChanged: onCourseChanged,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Status Chips Filter
          Row(
            children: [
              _buildFilterChip(
                label: isAr
                    ? 'الكل (${allSubmissions.length})'
                    : 'All (${allSubmissions.length})',
                isSelected: statusFilter == 'all',
                onSelected: () => onStatusChanged('all'),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: isAr
                    ? 'قيد المراجعة ($pendingCount)'
                    : 'Pending ($pendingCount)',
                isSelected: statusFilter == 'pending',
                onSelected: () => onStatusChanged('pending'),
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: isAr
                    ? 'تم التقييم ($gradedCount)'
                    : 'Graded ($gradedCount)',
                isSelected: statusFilter == 'graded',
                onSelected: () => onStatusChanged('graded'),
                color: AppColors.success,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isAr ? 'متوسط الدرجات: $avgScore%' : 'Avg Score: $avgScore%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    Color color = AppColors.primary,
  }) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

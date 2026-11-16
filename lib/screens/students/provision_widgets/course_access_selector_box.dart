import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/course.dart';

/// صندوق اختيار متعدد لمنح المتدرب الجديد صلاحية الوصول الفوري للكورسات المتاحة.
class CourseAccessSelectorBox extends StatelessWidget {
  final List<Course> courses;
  final Set<String> selectedCourseIds;
  final ValueChanged<String> onToggleCourse;
  final VoidCallback onToggleAll;

  const CourseAccessSelectorBox({
    super.key,
    required this.courses,
    required this.selectedCourseIds,
    required this.onToggleCourse,
    required this.onToggleAll,
  });

  @override
  Widget build(BuildContext context) {
    final allSelected =
        courses.isNotEmpty && selectedCourseIds.length == courses.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLevel0,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                PhosphorIconsRegular.graduationCap,
                size: 19,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'منح صلاحية الكورسات المتاحة فوراً',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (courses.isNotEmpty)
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: onToggleAll,
                  child: Text(
                    allSelected ? 'إلغاء تحديد الكل' : 'تحديد الكل',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            courses.isEmpty
                ? 'لا توجد كورسات منشأة بعد — سيتم إنشاء الحساب ويمكنك إضافة الكورسات لاحقاً.'
                : 'اختر دورة أو أكثر ليتم تفعيلها تلقائياً في حساب المتدرب فور إنشائه (${selectedCourseIds.length} محددة):',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (courses.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final course in courses) ...[
              _CourseCheckboxTile(
                course: course,
                isSelected: selectedCourseIds.contains(course.id),
                onTap: () => onToggleCourse(course.id),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _CourseCheckboxTile extends StatelessWidget {
  final Course course;
  final bool isSelected;
  final VoidCallback onTap;

  const _CourseCheckboxTile({
    required this.course,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.06)
          : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.borderHairline,
              width: isSelected ? 1.3 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? PhosphorIconsFill.checkSquare
                    : PhosphorIconsRegular.square,
                size: 20,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${course.totalLessonsCount} محاضرة • ${course.priceFormatted}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


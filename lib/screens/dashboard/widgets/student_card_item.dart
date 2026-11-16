import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/student_avatar.dart';
import '../../../logic/students/admin_students_cubit.dart';
import '../../../models/course.dart';
import '../../../models/registered_student.dart';

/// Alameen Center Clean Student Card
class StudentCardItem extends StatelessWidget {
  final RegisteredStudent student;
  final List<Course> courses;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectChanged;
  final VoidCallback? onLongPress;

  const StudentCardItem({
    super.key,
    required this.student,
    required this.courses,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectChanged,
    this.onLongPress,
  });

  Future<void> _toggleSuspension(BuildContext context) async {
    final willSuspend = !student.isSuspended;
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(willSuspend ? 'تعليق حساب الطالب' : 'إلغاء تعليق الحساب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              willSuspend
                  ? 'هل أنت متأكد من تعليق حساب "${student.name}"؟ سيتم منعه فورياً من دخول المحتوى والكورسات وتوجيهه للدعم الفني.'
                  : 'هل ترغب في إعادة تنشيط حساب "${student.name}" والسماح له بالدخول؟',
            ),
            if (willSuspend) ...[
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'سبب التعليق (اختياري)',
                  hintText: 'مثال: مخالفة شروط الاستخدام أو التحقق من السداد',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  willSuspend ? AppColors.error : AppColors.success,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(willSuspend ? 'تأكيد التعليق' : 'إعادة التنشيط'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final success = await context
          .read<AdminStudentsCubit>()
          .toggleStudentSuspension(
            student.id,
            suspend: willSuspend,
            reason: reasonController.text.trim(),
          );
      if (context.mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              willSuspend
                  ? 'تم تعليق حساب الطالب بنجاح.'
                  : 'تم إلغاء التعليق وتنشيط الحساب.',
            ),
            backgroundColor:
                willSuspend ? AppColors.warningDark : AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _deleteStudent(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف حساب الطالب نهائياً'),
        content: Text(
          'تحذير شديد الأهمية: هل أنت متأكد تماماً من حذف حساب الطالب "${student.name}" نهائياً من منصة مركز الأمين؟\n\nسيتم حذف بياناته وسجلات حضوره بالكامل ولا يمكن التراجع.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الحذف النهائي'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final success =
          await context.read<AdminStudentsCubit>().deleteStudent(student.id);
      if (context.mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف حساب الطالب بنجاح.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    return InkWell(
      onTap: isSelectionMode ? () => onSelectChanged?.call(!isSelected) : null,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight.withValues(alpha: 0.35) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderHairline,
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: AppColors.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSelectionMode) ...[
                    Checkbox(
                      value: isSelected,
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      onChanged: onSelectChanged,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: StudentAvatar(
                      name: student.name,
                      photoUrl: student.avatarUrl,
                      radius: 20,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Text(
                            student.name,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                          ),
                          if (student.isSuspended)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.errorLight,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.errorBorder),
                              ),
                              child: const Text(
                                'معلق',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.errorDark,
                                ),
                              ),
                            ),
                          if (student.enrolledCourseIds.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.successLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'students.enrolled_badge'.tr(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.successDark,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        student.email,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: IconButton(
                    icon: Icon(
                      isAr
                          ? PhosphorIconsRegular.caretLeft
                          : PhosphorIconsRegular.caretRight,
                      size: 18,
                      color: AppColors.royalNavy,
                    ),
                    tooltip: 'students.view_profile_tooltip'.tr(),
                    onPressed: () {
                      context.push(
                        AppRoutes.studentDetailPath(student.id),
                        extra: student,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Direct Account Status & Quick Action Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: student.isSuspended
                    ? AppColors.warningLight.withValues(alpha: 0.5)
                    : AppColors.surfaceLevel0,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: student.isSuspended
                      ? AppColors.warningBorder
                      : AppColors.borderHairline,
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  // Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: student.isSuspended
                          ? AppColors.warningDark
                          : AppColors.success,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          student.isSuspended
                              ? PhosphorIconsFill.prohibit
                              : PhosphorIconsFill.checkCircle,
                          size: 11,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          student.isSuspended ? 'حساب معلق' : 'حساب نشط',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Direct Toggle Suspension Action Button
                  InkWell(
                    onTap: () => _toggleSuspension(context),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: student.isSuspended
                            ? AppColors.successLight
                            : AppColors.warningLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: student.isSuspended
                              ? AppColors.successBorder
                              : AppColors.warningBorder,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            student.isSuspended
                                ? PhosphorIconsRegular.arrowCounterClockwise
                                : PhosphorIconsRegular.prohibit,
                            size: 12,
                            color: student.isSuspended
                                ? AppColors.successDark
                                : AppColors.warningDark,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            student.isSuspended
                                ? 'إعادة التنشيط'
                                : 'تعليق الحساب',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: student.isSuspended
                                  ? AppColors.successDark
                                  : AppColors.warningDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Direct Delete Action Button
                  InkWell(
                    onTap: () => _deleteStudent(context),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.errorBorder,
                          width: 0.8,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIconsRegular.trash,
                            size: 12,
                            color: AppColors.error,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'حذف',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'students.permissions_label'.tr(
                      args: [
                        '${student.enrolledCourseIds.length}',
                        student.localizedWatchTime(isAr: isAr),
                      ],
                    ),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  onPressed: () {
                    context.push(
                      AppRoutes.studentDetailPath(student.id),
                      extra: student,
                    );
                  },
                  icon: const Icon(
                    PhosphorIconsRegular.chartPolar,
                    size: 14,
                    color: AppColors.royalNavy,
                  ),
                  label: Text(
                    'students.full_analytics_btn'.tr(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.royalNavy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (courses.isEmpty)
              Text(
                'students.no_courses_yet'.tr(),
                style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: courses.map((course) {
                  final isEnrolled = student.isEnrolled(course.id);
                  return FilterChip(
                    selected: isEnrolled,
                    label: Text(
                      course.title,
                      style: TextStyle(
                        fontSize: 11,
                        color: isEnrolled ? AppColors.successDark : AppColors.textPrimary,
                        fontWeight: isEnrolled ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onSelected: (_) {
                      context.read<AdminStudentsCubit>().toggleStudentCourse(
                            student.id,
                            course.id,
                            isEnrolled,
                          );
                    },
                    selectedColor: AppColors.successLight,
                    checkmarkColor: AppColors.successDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(
                        color: isEnrolled ? AppColors.successBorder : AppColors.borderHairline,
                        width: 0.8,
                      ),
                    ),
                    avatar: Icon(
                      isEnrolled
                          ? PhosphorIconsFill.checkCircle
                          : PhosphorIconsRegular.lockSimple,
                      size: 13,
                      color: isEnrolled ? AppColors.successDark : AppColors.textMuted,
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    ),
  );
}
}

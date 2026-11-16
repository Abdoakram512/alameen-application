import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/bouncing_card.dart';
import '../../../logic/courses/admin_courses_cubit.dart';
import '../../../models/course.dart';
import '../../../services/course_audit_pdf_service.dart';
import '../../../services/firestore_service.dart';
import '../../courses/widgets/assign_students_dialog.dart';
import '../../courses/widgets/course_assignments_sheet.dart';
import '../../courses/widgets/edit_course_dialog.dart';

/// Alameen Center Clean Course Card
/// Human-crafted layout following top EdTech design systems (Coursera, Maven, MasterClass).
class CourseCardItem extends StatelessWidget {
  final Course course;
  final int enrolledCount;

  const CourseCardItem({
    super.key,
    required this.course,
    required this.enrolledCount,
  });

  Widget _buildThumbnail() {
    return AppCachedImage(
      imageUrl: course.thumbnailUrl,
      width: 90,
      height: 90,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(12),
    );
  }

  Future<void> _printCourseReport(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('جارٍ إعداد وطباعة تقرير الحضور والإنجاز الشامل (PDF)...'),
          ],
        ),
        duration: Duration(seconds: 3),
      ),
    );

    try {
      final allStudents = await FirestoreService().streamStudents().first;
      final courseStudents = allStudents
          .where((s) => s.enrolledCourseIds.contains(course.id))
          .toList();
      final allSubs = await FirestoreService().streamAllSubmissions().first;
      final courseSubs =
          allSubs.where((sub) => sub.courseId == course.id).toList();

      await CourseAuditPdfService.generateAndPrintReport(
        course: course,
        students: courseStudents,
        submissions: courseSubs,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر استخراج التقرير: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showExtendValidityDialog(BuildContext context) async {
    final daysController = TextEditingController(text: '30');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تمديد صلاحية الدورة للجميع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('أدخل عدد الأيام الإضافية لتمديد اشتراك جميع الطلاب المسجلين في دورة "${course.title}":'),
            const SizedBox(height: 12),
            TextField(
              controller: daysController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'عدد الأيام الإضافية',
                suffixText: 'يوم',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.royalNavy),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد التمديد للجميع'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final days = int.tryParse(daysController.text.trim()) ?? 30;
      final count = await FirestoreService().extendCourseValidityForAll(
        courseId: course.id,
        additionalDays: days,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تمديد الصلاحية بمقدار $days يوماً لـ $count طالباً بنجاح.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BouncingCard(
      onTap: () {
        context.push(AppRoutes.manageLevelsPath(course.id));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderHairline),
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
                  _buildThumbnail(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Course Title (unconstrained width for perfect baseline wrap)
                        Text(
                          course.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Instructor & Price Badge Row (perfectly baseline-aligned)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                course.instructor,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: course.accessMode.badgeBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: course.accessMode.badgeBorder,
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    course.accessMode.icon,
                                    size: 11,
                                    color: course.accessMode.badgeFg,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    course.accessMode.labelAr,
                                    style: TextStyle(
                                      color: course.accessMode.badgeFg,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: course.price > 0
                                    ? AppColors.surfaceLevel0
                                    : AppColors.successLight,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: course.price > 0
                                      ? AppColors.borderHairline
                                      : AppColors.successBorder,
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                course.price > 0
                                    ? '${course.price.toStringAsFixed(course.price.truncateToDouble() == course.price ? 0 : 2)} ${'currency'.tr()}'
                                    : 'free'.tr(),
                                style: TextStyle(
                                  color: course.price > 0
                                      ? AppColors.royalNavy
                                      : AppColors.successDark,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Clean human metadata row (No excessive rainbow pills)
                        Row(
                          children: [
                            Text(
                              'courses.levels_count'.tr(args: ['${course.levels.length}']),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Text(
                              ' • ',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                            Text(
                              'courses.lessons_count'.tr(args: ['${course.totalLessonsCount}']),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Text(
                              ' • ',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                            Text(
                              'courses.students_count'.tr(args: ['$enrolledCount']),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 12),

              // Action Buttons Row with clear human hierarchy
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.royalNavy,
                        side: const BorderSide(
                          color: AppColors.borderHairline,
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        context.push(AppRoutes.manageLevelsPath(course.id));
                      },
                      icon: const Icon(PhosphorIconsRegular.stack, size: 17),
                      label: Text(
                        'courses.manage_levels'.tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'courses.assignments_tooltip'.tr(),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceLevel0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: AppColors.borderHairline),
                      ),
                      minimumSize: const Size(38, 38),
                    ),
                    icon: const Icon(
                      PhosphorIconsRegular.clipboardText,
                      size: 18,
                      color: AppColors.royalNavy,
                    ),
                    onPressed: () =>
                        CourseAssignmentsSheet.show(context, course: course),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'تعيين الطلاب للكورس',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceLevel0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: AppColors.borderHairline),
                      ),
                      minimumSize: const Size(38, 38),
                    ),
                    icon: const Icon(
                      PhosphorIconsRegular.userPlus,
                      size: 18,
                      color: AppColors.royalNavy,
                    ),
                    onPressed: () =>
                        AssignStudentsDialog.show(context, course: course),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'courses.edit_tooltip'.tr(),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceLevel0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: AppColors.borderHairline),
                      ),
                      minimumSize: const Size(38, 38),
                    ),
                    icon: const Icon(
                      PhosphorIconsRegular.pencilSimpleLine,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () =>
                        EditCourseDialog.show(context, course: course),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'طباعة تقرير الحضور والإنجاز الشامل (PDF)',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceLevel0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: AppColors.borderHairline),
                      ),
                      minimumSize: const Size(38, 38),
                    ),
                    icon: const Icon(
                      PhosphorIconsRegular.filePdf,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    onPressed: () => _printCourseReport(context),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'تمديد صلاحية اشتراك جميع الطلاب المسجلين',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceLevel0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: AppColors.borderHairline),
                      ),
                      minimumSize: const Size(38, 38),
                    ),
                    icon: const Icon(
                      PhosphorIconsRegular.timer,
                      size: 18,
                      color: AppColors.royalNavy,
                    ),
                    onPressed: () => _showExtendValidityDialog(context),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'courses.delete_tooltip'.tr(),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceLevel0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: AppColors.borderHairline),
                      ),
                      minimumSize: const Size(38, 38),
                    ),
                    icon: const Icon(
                      PhosphorIconsRegular.trash,
                      size: 18,
                      color: AppColors.error,
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('courses.delete_dialog_title'.tr()),
                          content: Text(
                            'courses.delete_dialog_msg'.tr(args: [course.title]),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('dialogs.cancel'.tr()),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.error,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text('dialogs.delete'.tr()),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        await context.read<AdminCoursesCubit>().deleteCourse(
                          course.id,
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

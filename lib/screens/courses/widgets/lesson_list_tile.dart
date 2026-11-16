import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../logic/courses/admin_courses_cubit.dart';
import '../../../models/lesson.dart';
import 'lesson_attendance_sheet.dart';

class LessonListTile extends StatelessWidget {
  final String courseId;
  final String levelId;
  final Lesson lesson;
  final VoidCallback onDelete;
  final VoidCallback? onRetrySync;

  const LessonListTile({
    super.key,
    required this.courseId,
    required this.levelId,
    required this.lesson,
    required this.onDelete,
    this.onRetrySync,
  });

  Future<void> _publishNow(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('نشر المحاضرة الآن'),
        content: Text(
          'هل ترغب في نشر محاضرة "${lesson.title}" وإتاحتها للطلاب فوراً؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نشر فوري'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<AdminCoursesCubit>().updateLessonPublishStatus(
            courseId: courseId,
            levelId: levelId,
            lessonId: lesson.id,
            isPublished: true,
            scheduledPublishAt: null,
          );
    }
  }

  Future<void> _scheduleLecture(BuildContext context) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate:
          lesson.scheduledPublishAt ?? now.add(const Duration(hours: 2)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      confirmText: 'التالي',
      cancelText: 'إلغاء',
    );
    if (pickedDate == null || !context.mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: lesson.scheduledPublishAt != null
          ? TimeOfDay.fromDateTime(lesson.scheduledPublishAt!)
          : TimeOfDay.fromDateTime(now.add(const Duration(hours: 2))),
      confirmText: 'تأكيد الموعد',
      cancelText: 'إلغاء',
    );
    if (pickedTime == null || !context.mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (combined.isBefore(DateTime.now())) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار موعد في المستقبل')),
      );
      return;
    }

    if (context.mounted) {
      await context.read<AdminCoursesCubit>().updateLessonPublishStatus(
            courseId: courseId,
            levelId: levelId,
            lessonId: lesson.id,
            isPublished: true,
            scheduledPublishAt: combined,
          );
    }
  }

  Future<void> _makeDraft(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تحويل المحاضرة إلى مسودة'),
        content: Text(
          'هل ترغب في إخفاء محاضرة "${lesson.title}" عن الطلاب وحفظها كمسودة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تحويل لمسودة'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<AdminCoursesCubit>().updateLessonPublishStatus(
            courseId: courseId,
            levelId: levelId,
            lessonId: lesson.id,
            isPublished: false,
            scheduledPublishAt: null,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAssignment = lesson.isAssignmentLesson;
    final String streamSummary;
    if (isAssignment) {
      streamSummary = 'مهمة تطبيقية / تكليف تدريبي مستقل';
    } else if (lesson.muxPlaybackId.trim().isEmpty && !lesson.isFreePreview) {
      streamSummary = 'بث محمي للمشتركين فقط';
    } else if (lesson.muxPlaybackId.length >= 12) {
      streamSummary = 'معرف البث: ${lesson.muxPlaybackId.substring(0, 12)}...';
    } else {
      streamSummary = 'معرف البث: ${lesson.muxPlaybackId}';
    }

    final isProcessing = !isAssignment && lesson.isVideoProcessing;
    final hasError = !isAssignment && lesson.hasVideoError;

    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: isAssignment
            ? const Color(0xFFFEF3C7)
            : (isProcessing
                ? const Color(0xFFDBEAFE)
                : (hasError
                    ? AppColors.errorLight
                    : AppColors.secondary.withValues(alpha: 0.12))),
        child: isAssignment
            ? const Icon(
                Icons.assignment_outlined,
                color: Color(0xFFB45309),
                size: 20,
              )
            : (isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF1D4ED8),
                    ),
                  )
                : Icon(
                    hasError ? Icons.error_outline_rounded : Icons.play_arrow,
                    color: hasError ? AppColors.error : AppColors.secondary,
                    size: 20,
                  )),
      ),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              lesson.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (isProcessing)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_sync_rounded,
                        size: 12,
                        color: Color(0xFF1D4ED8),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        lesson.videoProgress > 0
                            ? 'سحب سحابي: ${lesson.videoProgress.toInt()}%'
                            : 'جاري التجهيز سحابياً...',
                        style: const TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else if (hasError)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.errorBorder),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 11,
                        color: AppColors.errorDark,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'خطأ في السحب',
                        style: TextStyle(
                          color: AppColors.errorDark,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else if (lesson.isFreePreview)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.successBorder),
                  ),
                  child: const Text(
                    'معاينة مجانية',
                    style: TextStyle(
                      color: AppColors.successDark,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 11,
                        color: AppColors.royalNavy,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'محمي',
                        style: TextStyle(
                          color: AppColors.royalNavy,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              if (lesson.hasAssignment)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: lesson.lockNextUntilSubmitted
                        ? AppColors.warningLight
                        : AppColors.surfaceLevel0,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: lesson.lockNextUntilSubmitted
                          ? AppColors.warningBorder
                          : AppColors.borderHairline,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        lesson.lockNextUntilSubmitted
                            ? Icons.lock_clock_rounded
                            : Icons.assignment_outlined,
                        size: 11,
                        color: lesson.lockNextUntilSubmitted
                            ? AppColors.warningDark
                            : AppColors.royalNavy,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        lesson.lockNextUntilSubmitted
                            ? 'تكليف مشروط'
                            : 'تكليف مرفق',
                        style: TextStyle(
                          color: lesson.lockNextUntilSubmitted
                              ? AppColors.warningDark
                              : AppColors.royalNavy,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              // حالة نشر المحاضرة وموعدها
              if (lesson.isDraft)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.drafts_outlined,
                          size: 11, color: Colors.grey.shade700),
                      const SizedBox(width: 3),
                      Text(
                        'مسودة (مغلق)',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else if (lesson.isScheduled)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFD8B4FE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 11, color: Color(0xFF6B21A8)),
                      const SizedBox(width: 3),
                      Text(
                        'مجدولة: ${lesson.scheduledPublishAt!.month}/${lesson.scheduledPublishAt!.day} ${lesson.scheduledPublishAt!.hour.toString().padLeft(2, '0')}:${lesson.scheduledPublishAt!.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Color(0xFF6B21A8),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.successBorder),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 11, color: AppColors.successDark),
                      SizedBox(width: 3),
                      Text(
                        'منشورة',
                        style: TextStyle(
                          color: AppColors.successDark,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      subtitle: isProcessing
          ? const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 3),
                Text(
                  'Mux يسحب ويعالج الفيديو سحابياً من الرابط • لن يتأثر التحميل بإغلاق التطبيق',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF1E40AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(3)),
                  child: LinearProgressIndicator(
                    minHeight: 3.5,
                    backgroundColor: Color(0xFFE2E8F0),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                  ),
                ),
              ],
            )
          : (hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'تعذر السحب: ${lesson.videoErrorMessage ?? "تأكد من جعل مشاركة الرابط عامة"}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.errorDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              : Text(
                  '${lesson.duration} • $streamSummary',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                )),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isProcessing && onRetrySync != null)
            IconButton(
              icon: const Icon(
                Icons.sync_rounded,
                size: 19,
                color: Color(0xFF2563EB),
              ),
              tooltip: 'تحديث حالة المعالجة السحابية الآن',
              onPressed: onRetrySync,
            ),
          if (lesson.isDraft || lesson.isScheduled)
            IconButton(
              icon: const Icon(
                Icons.cloud_upload_outlined,
                size: 20,
                color: AppColors.success,
              ),
              tooltip: 'نشر للطلاب الآن فوراً',
              onPressed: () => _publishNow(context),
            ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              size: 20,
              color: AppColors.royalNavy,
            ),
            tooltip: 'خيارات المحاضرة والنشر',
            onSelected: (value) {
              if (value == 'publish') {
                _publishNow(context);
              } else if (value == 'schedule') {
                _scheduleLecture(context);
              } else if (value == 'draft') {
                _makeDraft(context);
              }
            },
            itemBuilder: (ctx) => [
              if (lesson.isDraft || lesson.isScheduled)
                const PopupMenuItem(
                  value: 'publish',
                  child: Row(
                    children: [
                      Icon(Icons.bolt, color: AppColors.success, size: 18),
                      SizedBox(width: 8),
                      Text('نشر فوري الآن'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'schedule',
                child: Row(
                  children: [
                    Icon(Icons.edit_calendar,
                        color: Color(0xFF6B21A8), size: 18),
                    SizedBox(width: 8),
                    Text('جدولة موعد المحاضرة'),
                  ],
                ),
              ),
              if (lesson.isPublished)
                const PopupMenuItem(
                  value: 'draft',
                  child: Row(
                    children: [
                      Icon(Icons.drafts_outlined, color: Colors.grey, size: 18),
                      SizedBox(width: 8),
                      Text('تحويل إلى مسودة (إخفاء)'),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(
              Icons.analytics_outlined,
              size: 20,
              color: AppColors.royalNavy,
            ),
            tooltip: 'سجل حضور ومشاهدات الدرس',
            onPressed: () => LessonAttendanceSheet.show(
              context,
              courseId: courseId,
              lesson: lesson,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 20,
              color: AppColors.error,
            ),
            tooltip: 'حذف الدرس',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('حذف الدرس'),
                  content: Text(
                    'هل أنت متأكد من حذف درس "${lesson.title}" نهائياً؟',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('إلغاء'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.error,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('حذف'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                onDelete();
              }
            },
          ),
        ],
      ),
    );
  }
}

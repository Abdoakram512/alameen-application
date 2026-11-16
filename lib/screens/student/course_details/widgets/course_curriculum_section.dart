import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/course_level.dart';
import '../../../../models/lesson.dart';

/// قسم المنهج الدراسي المقسم إلى مستويات ومحاضرات واضحة.
class CourseCurriculumSection extends StatelessWidget {
  final List<CourseLevel> levels;
  final bool isEnrolled;
  final Set<String> completedLessonIds;
  final Map<String, String> lockedReasons;
  final ValueChanged<Lesson> onPlayLesson;
  final VoidCallback onLockedLessonTap;
  final void Function(String reason)? onAssignmentLockedLessonTap;

  const CourseCurriculumSection({
    super.key,
    required this.levels,
    required this.isEnrolled,
    required this.completedLessonIds,
    this.lockedReasons = const {},
    required this.onPlayLesson,
    required this.onLockedLessonTap,
    this.onAssignmentLockedLessonTap,
  });

  @override
  Widget build(BuildContext context) {
    if (levels.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderHairline),
        ),
        child: Text(
          'سيتم نشر مستويات ومحاضرات هذه الدورة قريباً.',
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('المنهج التدريبي والمحاضرات', style: AppTextStyles.heading2),
        const SizedBox(height: 12),
        for (int i = 0; i < levels.length; i++) ...[
          CourseLevelCard(
            level: levels[i],
            levelIndex: i + 1,
            initiallyExpanded: i == 0,
            isEnrolled: isEnrolled,
            completedLessonIds: completedLessonIds,
            lockedReasons: lockedReasons,
            onPlayLesson: onPlayLesson,
            onLockedLessonTap: onLockedLessonTap,
            onAssignmentLockedLessonTap: onAssignmentLockedLessonTap,
          ),
          if (i < levels.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class CourseLevelCard extends StatelessWidget {
  final CourseLevel level;
  final int levelIndex;
  final bool initiallyExpanded;
  final bool isEnrolled;
  final Set<String> completedLessonIds;
  final Map<String, String> lockedReasons;
  final ValueChanged<Lesson> onPlayLesson;
  final VoidCallback onLockedLessonTap;
  final void Function(String reason)? onAssignmentLockedLessonTap;

  const CourseLevelCard({
    super.key,
    required this.level,
    required this.levelIndex,
    required this.initiallyExpanded,
    required this.isEnrolled,
    required this.completedLessonIds,
    this.lockedReasons = const {},
    required this.onPlayLesson,
    required this.onLockedLessonTap,
    this.onAssignmentLockedLessonTap,
  });

  @override
  Widget build(BuildContext context) {
    final completedInLevel = level.lessons
        .where((l) => completedLessonIds.contains(l.id))
        .length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderHairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'المستوى $levelIndex',
              style: AppTextStyles.label.copyWith(
                color: AppColors.royalNavy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          title: Text(
            level.title,
            style: AppTextStyles.heading3.copyWith(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${level.lessons.length} محاضرات • تم إكمال $completedInLevel',
            style: AppTextStyles.caption,
          ),
          children: [
            const Divider(height: 1),
            if (level.lessons.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'لا توجد محاضرات مضافة في هذا المستوى بعد.',
                  style: AppTextStyles.bodyMedium,
                ),
              )
            else
              for (int idx = 0; idx < level.lessons.length; idx++) ...[
                () {
                  final item = level.lessons[idx];
                  final lockReason = lockedReasons[item.id];
                  final isAvailable = item.isAvailableNow;
                  final isUnlocked = (isEnrolled || item.isFreePreview) &&
                      lockReason == null &&
                      isAvailable;

                  return CourseLessonTile(
                    lesson: item,
                    isUnlocked: isUnlocked,
                    isCompleted: completedLessonIds.contains(item.id),
                    assignmentLockReason: lockReason,
                    onTap: () {
                      if (!item.isAvailableNow) {
                        final msg = item.isScheduled
                            ? 'هذه المحاضرة مجدولة وستتاح تلقائياً للطلاب في موعدها المحدد (${item.scheduledPublishAt!.year}/${item.scheduledPublishAt!.month.toString().padLeft(2, '0')}/${item.scheduledPublishAt!.day.toString().padLeft(2, '0')} - ${item.scheduledPublishAt!.hour.toString().padLeft(2, '0')}:${item.scheduledPublishAt!.minute.toString().padLeft(2, '0')})'
                            : 'هذه المحاضرة غير متاحة حالياً (قيد الإعداد والمراجعة).';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: const Color(0xFF6B21A8),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                        return;
                      }
                      if (lockReason != null) {
                        if (onAssignmentLockedLessonTap != null) {
                          onAssignmentLockedLessonTap!(lockReason);
                        } else {
                          onLockedLessonTap();
                        }
                      } else if (isEnrolled || item.isFreePreview) {
                        onPlayLesson(item);
                      } else {
                        onLockedLessonTap();
                      }
                    },
                  );
                }(),
                if (idx < level.lessons.length - 1) const Divider(height: 1),
              ],
          ],
        ),
      ),
    );
  }
}

class CourseLessonTile extends StatelessWidget {
  final Lesson lesson;
  final bool isUnlocked;
  final bool isCompleted;
  final String? assignmentLockReason;
  final VoidCallback onTap;

  const CourseLessonTile({
    super.key,
    required this.lesson,
    required this.isUnlocked,
    required this.isCompleted,
    this.assignmentLockReason,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAssignmentLocked = assignmentLockReason != null;
    final isUnavailable = !lesson.isAvailableNow;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.successLight
                    : isUnavailable
                        ? (lesson.isScheduled
                            ? const Color(0xFFF3E8FF)
                            : AppColors.surfaceLevel2)
                        : isAssignmentLocked
                            ? const Color(0xFFFEF3C7)
                            : lesson.isAssignmentLesson
                                ? const Color(0xFFEFF6FF)
                                : isUnlocked
                                    ? AppColors.primaryLight
                                    : AppColors.surfaceLevel2,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompleted
                    ? Icons.check_rounded
                    : isUnavailable
                        ? (lesson.isScheduled
                            ? Icons.access_time_rounded
                            : Icons.lock_outline_rounded)
                        : isAssignmentLocked
                            ? Icons.lock_clock_rounded
                            : lesson.isAssignmentLesson
                                ? Icons.assignment_outlined
                                : isUnlocked
                                    ? Icons.play_arrow_rounded
                                    : Icons.lock_outline_rounded,
                size: 19,
                color: isCompleted
                    ? AppColors.success
                    : isUnavailable
                        ? (lesson.isScheduled
                            ? const Color(0xFF6B21A8)
                            : AppColors.textMuted)
                        : isAssignmentLocked
                            ? const Color(0xFFB45309)
                            : lesson.isAssignmentLesson
                                ? const Color(0xFF1D4ED8)
                                : isUnlocked
                                    ? AppColors.primary
                                    : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isUnlocked
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        lesson.isAssignmentLesson
                            ? 'مهمة تطبيقية'
                            : lesson.duration,
                        style: AppTextStyles.caption,
                      ),
                      if (lesson.isAssignmentLesson)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFFBFDBFE),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.assignment_outlined,
                                size: 11,
                                color: Color(0xFF1D4ED8),
                              ),
                              SizedBox(width: 3),
                              Text(
                                'مهمة / تكليف مستقل',
                                style: TextStyle(
                                  color: Color(0xFF1D4ED8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (!lesson.isAssignmentLesson && lesson.isFreePreview && !isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.infoLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'معاينة مجانية',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.info,
                            ),
                          ),
                        ),
                      if (!lesson.isAssignmentLesson && lesson.hasAssignment)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: lesson.lockNextUntilSubmitted
                                ? const Color(0xFFFEF3C7)
                                : AppColors.surfaceLevel0,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: lesson.lockNextUntilSubmitted
                                  ? const Color(0xFFFDE68A)
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
                                    ? const Color(0xFFB45309)
                                    : AppColors.royalNavy,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                lesson.lockNextUntilSubmitted
                                    ? 'تكليف مشروط'
                                    : 'تكليف مرفق',
                                style: TextStyle(
                                  color: lesson.lockNextUntilSubmitted
                                      ? const Color(0xFFB45309)
                                      : AppColors.royalNavy,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (isAssignmentLocked)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'يتطلب تسليم تكليف: $assignmentLockReason',
                            style: const TextStyle(
                              color: Color(0xFF991B1B),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (isUnavailable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: lesson.isScheduled
                                ? const Color(0xFFF3E8FF)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: lesson.isScheduled
                                  ? const Color(0xFFD8B4FE)
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                lesson.isScheduled
                                    ? Icons.access_time_rounded
                                    : Icons.lock_clock_outlined,
                                size: 11,
                                color: lesson.isScheduled
                                    ? const Color(0xFF6B21A8)
                                    : Colors.grey.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                lesson.isScheduled
                                    ? 'موعد المحاضرة: ${lesson.scheduledPublishAt!.month}/${lesson.scheduledPublishAt!.day} ${lesson.scheduledPublishAt!.hour.toString().padLeft(2, '0')}:${lesson.scheduledPublishAt!.minute.toString().padLeft(2, '0')}'
                                    : 'غير متاحة حالياً',
                                style: TextStyle(
                                  color: lesson.isScheduled
                                      ? const Color(0xFF6B21A8)
                                      : Colors.grey.shade800,
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
            ),
          ],
        ),
      ),
    );
  }
}

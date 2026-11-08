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
  final ValueChanged<Lesson> onPlayLesson;
  final VoidCallback onLockedLessonTap;

  const CourseCurriculumSection({
    super.key,
    required this.levels,
    required this.isEnrolled,
    required this.completedLessonIds,
    required this.onPlayLesson,
    required this.onLockedLessonTap,
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
            onPlayLesson: onPlayLesson,
            onLockedLessonTap: onLockedLessonTap,
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
  final ValueChanged<Lesson> onPlayLesson;
  final VoidCallback onLockedLessonTap;

  const CourseLevelCard({
    super.key,
    required this.level,
    required this.levelIndex,
    required this.initiallyExpanded,
    required this.isEnrolled,
    required this.completedLessonIds,
    required this.onPlayLesson,
    required this.onLockedLessonTap,
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
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$levelIndex',
              style: AppTextStyles.heading3.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          title: Text(
            level.title,
            style: AppTextStyles.heading3.copyWith(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            isEnrolled
                ? 'مكتمل $completedInLevel من ${level.lessons.length} محاضرة'
                : '${level.lessons.length} محاضرة',
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
                CourseLessonTile(
                  lesson: level.lessons[idx],
                  isUnlocked: isEnrolled || level.lessons[idx].isFreePreview,
                  isCompleted: completedLessonIds.contains(
                    level.lessons[idx].id,
                  ),
                  onTap: () {
                    final item = level.lessons[idx];
                    if (isEnrolled || item.isFreePreview) {
                      onPlayLesson(item);
                    } else {
                      onLockedLessonTap();
                    }
                  },
                ),
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
  final VoidCallback onTap;

  const CourseLessonTile({
    super.key,
    required this.lesson,
    required this.isUnlocked,
    required this.isCompleted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                    : isUnlocked
                        ? AppColors.primaryLight
                        : AppColors.surfaceLevel2,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompleted
                    ? Icons.check_rounded
                    : isUnlocked
                        ? Icons.play_arrow_rounded
                        : Icons.lock_outline_rounded,
                size: 19,
                color: isCompleted
                    ? AppColors.success
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
                      Text(lesson.duration, style: AppTextStyles.caption),
                      if (lesson.isFreePreview && !isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.infoLight,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'معاينة مجانية',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.primary,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              isUnlocked
                  ? Icons.chevron_right_rounded
                  : Icons.lock_outline_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}


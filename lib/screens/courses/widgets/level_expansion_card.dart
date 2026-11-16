import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../logic/courses/admin_courses_cubit.dart';
import '../../../models/course_level.dart';
import 'add_lesson_bottom_sheet.dart';
import 'lesson_list_tile.dart';

class LevelExpansionCard extends StatelessWidget {
  final String courseId;
  final CourseLevel level;
  final int index;

  const LevelExpansionCard({
    super.key,
    required this.courseId,
    required this.level,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      color: Colors.white,
      child: ExpansionTile(
        // يزيل خطي الـ Divider العلوي والسفلي اللذين يرسمهما ExpansionTile تلقائياً
        shape: const Border(),
        collapsedShape: const Border(),
        initiallyExpanded: index == 0,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Text(
          level.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          level.description.isNotEmpty
              ? '${level.lessons.length} فيديوهات Mux • ${level.description}'
              : '${level.lessons.length} فيديوهات Mux',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: AppColors.error,
                size: 20,
              ),
              tooltip: 'حذف المستوى',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('حذف المستوى'),
                    content: Text(
                      'هل أنت متأكد من حذف "${level.title}" بجميع دروسه؟',
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
                        child: const Text('حذف المستوى'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await context.read<AdminCoursesCubit>().deleteLevel(
                    courseId,
                    level.id,
                  );
                }
              },
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          if (level.lessons.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'لا توجد دروس في هذا المستوى بعد. اضغط على "إضافة درس فيديو Mux".',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: level.lessons.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
              itemBuilder: (ctx, lessonIdx) {
                final lesson = level.lessons[lessonIdx];
                return LessonListTile(
                  courseId: courseId,
                  levelId: level.id,
                  lesson: lesson,
                  onRetrySync: () {
                    context.read<AdminCoursesCubit>().syncLessonVideoStatus(
                          courseId,
                          level.id,
                          lesson,
                        );
                  },
                  onDelete: () {
                    context.read<AdminCoursesCubit>().deleteLesson(
                      courseId,
                      level.id,
                      lesson.id,
                    );
                  },
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  AddLessonBottomSheet.show(
                    context,
                    courseId: courseId,
                    levelId: level.id,
                  );
                },
                icon: const Icon(Icons.video_call_outlined, size: 20),
                label: const Text('إضافة درس فيديو Mux للمستوى'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

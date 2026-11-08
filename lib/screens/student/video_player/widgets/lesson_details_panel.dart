import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../logic/auth/auth_cubit.dart';
import '../../../../logic/auth/auth_state.dart';
import '../../../../models/lesson.dart';
import '../../lesson_playlist.dart';

/// لوحة تفاصيل المحاضرة، حالة الإكمال، والانتقال للدرس التالي وقائمة الدروس.
class LessonDetailsPanel extends StatelessWidget {
  final Lesson lesson;
  final String courseId;
  final bool isCompleted;
  final bool savingCompletion;
  final bool canComplete;
  final List<Lesson> playlist;
  final bool showInlinePlaylist;
  final VoidCallback onToggleCompletion;
  final ValueChanged<Lesson> onSelectLesson;

  const LessonDetailsPanel({
    super.key,
    required this.lesson,
    required this.courseId,
    required this.isCompleted,
    required this.savingCompletion,
    required this.canComplete,
    required this.playlist,
    required this.showInlinePlaylist,
    required this.onToggleCompletion,
    required this.onSelectLesson,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            lesson.title,
            style: AppTextStyles.heading2.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 15,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(lesson.duration, style: AppTextStyles.caption),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: lesson.isFreePreview
                      ? AppColors.infoLight
                      : AppColors.successLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  lesson.isFreePreview ? 'معاينة مفتوحة' : 'محاضرة مسجلة',
                  style: AppTextStyles.label.copyWith(
                    color: lesson.isFreePreview
                        ? AppColors.info
                        : AppColors.successDark,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          Text('ملخص المحاضرة', style: AppTextStyles.heading3),
          const SizedBox(height: 6),
          Text(
            lesson.description.trim().isNotEmpty
                ? lesson.description
                : 'تابع شرح المحاضرة ثم حددها كمكتملة بعد استيعاب النقاط التدريبية الواردة فيها.',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderHairline),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.bookmark_added_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'يُحفظ موضع التوقف تلقائياً على هذا الجهاز للعودة إلى نفس النقطة لاحقاً.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: savingCompletion || !canComplete
                ? null
                : onToggleCompletion,
            icon: Icon(
              isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.check_circle_outline_rounded,
            ),
            label: Text(
              isCompleted
                  ? 'مكتمل — اضغط لإلغاء علامة الإكمال'
                  : 'تحديد المحاضرة كمكتملة',
            ),
            style: FilledButton.styleFrom(
              backgroundColor:
                  isCompleted ? AppColors.success : AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          if (playlist.isNotEmpty)
            BlocBuilder<AuthCubit, AuthState>(
              builder: (context, state) {
                final user = state is Authenticated ? state.user : null;
                final currentIndex = playlist.indexWhere(
                  (item) => item.id == lesson.id,
                );
                final next =
                    currentIndex >= 0 && currentIndex + 1 < playlist.length
                        ? playlist[currentIndex + 1]
                        : null;
                final canOpenNext = next != null &&
                    user != null &&
                    (next.isFreePreview || user.isEnrolled(courseId));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (next != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed:
                            canOpenNext ? () => onSelectLesson(next) : null,
                        icon: const Icon(Icons.skip_next_rounded),
                        label: Text(
                          'المحاضرة التالية: ${next.title}',
                        ),
                      ),
                    ],
                    if (showInlinePlaylist) ...[
                      const SizedBox(height: 22),
                      LessonPlaylist(
                        lessons: playlist,
                        selectedId: lesson.id,
                        enrolled: user?.isEnrolled(courseId) ?? false,
                        completedIds: {...?user?.completedLessonIds},
                        onSelected: onSelectLesson,
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}


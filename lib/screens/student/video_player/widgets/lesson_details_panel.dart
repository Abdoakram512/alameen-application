import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../logic/auth/auth_cubit.dart';
import '../../../../logic/auth/auth_state.dart';
import '../../../../models/course_level.dart';
import '../../../../models/course_progress_policy.dart';
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
  final List<CourseLevel> levels;
  final bool showInlinePlaylist;
  final Map<String, String> lockedReasons;
  final bool isAssignmentSubmitted;
  final VoidCallback? onOpenAssignmentSheet;
  final VoidCallback? onToggleCompletion;
  final ValueChanged<Lesson> onSelectLesson;

  const LessonDetailsPanel({
    super.key,
    required this.lesson,
    required this.courseId,
    required this.isCompleted,
    required this.savingCompletion,
    required this.canComplete,
    required this.playlist,
    this.levels = const [],
    required this.showInlinePlaylist,
    this.lockedReasons = const {},
    this.isAssignmentSubmitted = false,
    this.onOpenAssignmentSheet,
    this.onToggleCompletion,
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
          if (lesson.hasAssignment) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isAssignmentSubmitted
                    ? AppColors.successLight
                    : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isAssignmentSubmitted
                      ? AppColors.successBorder
                      : const Color(0xFFFDE68A),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isAssignmentSubmitted
                            ? Icons.check_circle_rounded
                            : Icons.assignment_outlined,
                        color: isAssignmentSubmitted
                            ? AppColors.success
                            : const Color(0xFFB45309),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isAssignmentSubmitted
                              ? 'تم تسليم تكليف هذه المحاضرة'
                              : 'تكليف عملي خاص بهذه المحاضرة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isAssignmentSubmitted
                                ? AppColors.successDark
                                : const Color(0xFF92400E),
                          ),
                        ),
                      ),
                      if (lesson.lockNextUntilSubmitted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'إلزامي لفتح الدرس التالي',
                            style: TextStyle(
                              color: Color(0xFF991B1B),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (onOpenAssignmentSheet != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isAssignmentSubmitted
                              ? AppColors.successDark
                              : const Color(0xFF92400E),
                          side: BorderSide(
                            color: isAssignmentSubmitted
                                ? AppColors.successBorder
                                : const Color(0xFFB45309),
                          ),
                        ),
                        onPressed: onOpenAssignmentSheet,
                        icon: Icon(
                          isAssignmentSubmitted
                              ? Icons.visibility_outlined
                              : Icons.upload_file_rounded,
                          size: 18,
                        ),
                        label: Text(
                          isAssignmentSubmitted
                              ? 'عرض التكليف المُسلّم'
                              : 'تسليم التكليف الآن',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
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
                    'player.saved_position_hint'.tr(),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppColors.successLight
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isCompleted
                    ? AppColors.successBorder
                    : AppColors.borderHairline,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isCompleted
                      ? Icons.verified_rounded
                      : Icons.timelapse_rounded,
                  color:
                      isCompleted ? AppColors.successDark : AppColors.primary,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCompleted
                            ? 'player.lesson_completed_title'.tr()
                            : 'player.lesson_auto_track_title'.tr(),
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isCompleted
                              ? AppColors.successDark
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isCompleted
                            ? 'player.lesson_completed_desc'.tr()
                            : 'player.lesson_auto_track_desc'.tr(args: [
                                '${lesson.effectiveCompletionThresholdPercentage}%',
                              ]),
                        style: AppTextStyles.caption.copyWith(
                          color: isCompleted
                              ? AppColors.successDark.withValues(alpha: 0.85)
                              : AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (playlist.isNotEmpty)
            BlocBuilder<AuthCubit, AuthState>(
              builder: (context, state) {
                final user = state is Authenticated ? state.user : null;
                final isEnrolled = user?.isEnrolled(courseId) ?? false;
                final completedSet = <String>{
                  ...?user?.completedLessonIds,
                  for (final l in playlist)
                    if (l.isCompleted) l.id,
                  if (isCompleted) lesson.id,
                };
                final currentIndex = playlist.indexWhere(
                  (item) => item.id == lesson.id,
                );
                final next =
                    currentIndex >= 0 && currentIndex + 1 < playlist.length
                        ? playlist[currentIndex + 1]
                        : null;
                final isNextLockedByAssignment =
                    next != null && lockedReasons.containsKey(next.id);
                final nextLockReason = next == null
                    ? null
                    : CourseProgressPolicy.lessonLockReason(
                        levels: levels,
                        lesson: next,
                        isEnrolled: isEnrolled,
                        completedLessonIds: completedSet,
                        assignmentLockReasons: lockedReasons,
                      );
                final canOpenNext =
                    next != null && user != null && nextLockReason == null;

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
                          'player.next_lesson'.tr(args: [next.title]),
                        ),
                      ),
                      if (isNextLockedByAssignment)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.lock_clock_rounded,
                                size: 16,
                                color: Color(0xFFB45309),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'player.must_submit_assignment_first'.tr(),
                                  style: const TextStyle(
                                    color: Color(0xFF92400E),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (nextLockReason != null)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderHairline),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.lock_outline_rounded,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  nextLockReason,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    if (showInlinePlaylist) ...[
                      const SizedBox(height: 22),
                      LessonPlaylist(
                        lessons: playlist,
                        levels: levels,
                        selectedId: lesson.id,
                        enrolled: isEnrolled,
                        completedIds: completedSet,
                        lockedReasons: lockedReasons,
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

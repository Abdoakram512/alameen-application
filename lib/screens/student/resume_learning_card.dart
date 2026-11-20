import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/painters/learning_progress_ring_painter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/courses/presentation/cubits/course_entitlement/course_entitlement_cubit.dart';
import '../../models/course.dart';
import '../../models/course_progress_policy.dart';
import '../../models/learning_history.dart';
import '../../models/user_profile.dart';
import 'video_player_screen.dart';

class ResumeLearningCard extends StatefulWidget {
  final UserModel user;
  final List<Course> courses;

  const ResumeLearningCard({
    super.key,
    required this.user,
    required this.courses,
  });

  @override
  State<ResumeLearningCard> createState() => _ResumeLearningCardState();
}

class _ResumeLearningCardState extends State<ResumeLearningCard> {
  RecentLesson? _recent;

  @override
  void initState() {
    super.initState();
    learningHistoryRevision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    learningHistoryRevision.removeListener(_load);
    super.dispose();
  }

  @override
  void didUpdateWidget(ResumeLearningCard old) {
    super.didUpdateWidget(old);
    if (old.user.uid != widget.user.uid) {
      _recent = null;
      _load();
    }
  }

  Future<void> _load() async {
    final uid = widget.user.uid;
    try {
      final saved = await SharedPreferencesAsync().getString(
        'learning.recent.$uid',
      );
      if (mounted && uid == widget.user.uid) {
        setState(() => _recent = RecentLesson.decode(saved));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final recent = _recent;
    if (recent == null) return const SizedBox.shrink();
    final matches = widget.courses.where((c) => c.id == recent.courseId);
    if (matches.isEmpty) return const SizedBox.shrink();
    final course = matches.first;
    final lessons = orderedLessons(course);
    final found = lessons.where((lesson) => lesson.id == recent.lessonId);
    if (found.isEmpty) return const SizedBox.shrink();
    final lesson = found.first;

    final isExpired = widget.user.isCourseExpired(course.id);
    final isAuthorized = context.select<CourseEntitlementCubit, bool>(
      (cubit) => cubit.state.isCourseAuthorized(course.id),
    );
    final isEnrolled = !isExpired && isAuthorized;

    final completedSet = CourseProgressPolicy.effectiveCompletedLessonIds(
      course: course,
      userCompletedLessonIds: {...widget.user.completedLessonIds},
    );

    final lockReason = CourseProgressPolicy.lessonLockReason(
      levels: course.levels,
      lesson: lesson,
      isEnrolled: isEnrolled,
      completedLessonIds: completedSet,
    );
    if (lockReason != null) {
      return const SizedBox.shrink();
    }

    final progress = widget.user.calculateCourseProgress(course.allLessonIds);
    final isWide = MediaQuery.sizeOf(context).width >= 680;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: AppColors.heroGradient,
          boxShadow: AppColors.heroShadow,
        ),
        padding: const EdgeInsets.all(20),
        child: isWide
            ? Row(
                children: [
                  Expanded(
                    child: _ResumeTextSummary(course: course, lesson: lesson),
                  ),
                  const SizedBox(width: 20),
                  AnimatedLearningProgressRing(
                    progress: progress,
                    size: 60,
                    strokeWidth: 5.5,
                    centerChild: Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    height: 46,
                    child: _ResumeActionButton(
                      onPressed: () => _openRecent(course, lesson, lessons),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ResumeTextSummary(
                          course: course,
                          lesson: lesson,
                        ),
                      ),
                      const SizedBox(width: 14),
                      AnimatedLearningProgressRing(
                        progress: progress,
                        size: 58,
                        strokeWidth: 5.5,
                        centerChild: Text(
                          '${(progress * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: _ResumeActionButton(
                      onPressed: () => _openRecent(course, lesson, lessons),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _openRecent(
    Course course,
    dynamic lesson,
    List<dynamic> lessons,
  ) async {
    HapticFeedback.mediumImpact();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VideoPlayerScreen(
          lesson: lesson,
          courseId: course.id,
          courseSlug: course.slug,
          courseTitle: course.title,
          courseAccessMode: course.accessMode,
          currentUser: widget.user,
          playlist: lessons.cast(),
          levels: course.levels,
        ),
      ),
    );
    if (mounted) await _load();
  }
}

class _ResumeTextSummary extends StatelessWidget {
  final Course course;
  final dynamic lesson;

  const _ResumeTextSummary({required this.course, required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_rounded, size: 14, color: Colors.white),
              SizedBox(width: 5),
              Text(
                'استئناف آخر محاضرة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          course.title,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          lesson.title,
          style: AppTextStyles.heading3.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ResumeActionButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ResumeActionButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.play_arrow_rounded, size: 20),
      label: Text(
        'متابعة المحاضرة',
        style: AppTextStyles.button.copyWith(
          color: AppColors.primary,
          fontSize: 13.5,
        ),
      ),
      onPressed: onPressed,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/course.dart';
import '../../../../models/user_profile.dart';

/// بطاقة تفصيل التقدم الدراسي ونسبة الإنجاز ووقت التعلم لكل دورة تدريبية.
class CourseTimeBreakdownCard extends StatelessWidget {
  final List<Course> enrolledCourses;
  final UserModel currentUser;
  final Map<String, int> minutesByCourse;

  const CourseTimeBreakdownCard({
    super.key,
    required this.enrolledCourses,
    required this.currentUser,
    required this.minutesByCourse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                PhosphorIconsRegular.chartBarHorizontal,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'تفصيل التقدم ووقت التعلم لكل دورة',
                style: AppTextStyles.heading3.copyWith(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < enrolledCourses.length; i++) ...[
            _buildCourseAnalyticsRow(enrolledCourses[i]),
            if (i < enrolledCourses.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCourseAnalyticsRow(Course course) {
    final lessonIds = course.allLessonIds;
    final doneCount = lessonIds
        .where((id) => currentUser.completedLessonIds.contains(id))
        .length;
    final progress = currentUser.calculateCourseProgress(lessonIds);
    final watchedMins = minutesByCourse[course.id] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                course.title,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              watchedMins > 0 ? '$watchedMins د مشاهدة' : 'لم تبدأ المشاهدة',
              style: AppTextStyles.caption.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: progress >= 1.0
                    ? AppColors.successLight
                    : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${(progress * 100).round()}%',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  color: progress >= 1.0
                      ? AppColors.successDark
                      : AppColors.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, val, _) => LinearProgressIndicator(
                    value: val,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceLevel2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1.0 ? AppColors.success : AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$doneCount/${lessonIds.length} محاضرة',
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

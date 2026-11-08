import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_cached_image.dart';
import '../../../../core/widgets/app_lottie_box.dart';
import '../../../../models/course.dart';
import '../../../../models/user_profile.dart';

/// قسم الدورات المفعّلة في ملف المتدرب مع حالة فارغة مدعومة بـ Lottie وشبكة متجاوبة.
class EnrolledCoursesSection extends StatelessWidget {
  final List<Course> enrolledCourses;
  final UserModel? currentUser;
  final VoidCallback? onBrowseCourses;

  const EnrolledCoursesSection({
    super.key,
    required this.enrolledCourses,
    required this.currentUser,
    this.onBrowseCourses,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              PhosphorIconsRegular.books,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text('دوراتي المفعّلة', style: AppTextStyles.heading2),
          ],
        ),
        const SizedBox(height: 12),
        if (enrolledCourses.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderHairline),
            ),
            child: Column(
              children: [
                const AppLottieBox(
                  assetPath: 'assets/lottie/empty_state.json',
                  width: 84,
                  height: 84,
                ),
                const SizedBox(height: 6),
                Text(
                  'لا توجد دورات مفعّلة في حسابك حتى الآن',
                  style: AppTextStyles.heading3.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'تصفح الدورات المتاحة من الصفحة الرئيسية، أو تواصل مع الإدارة لتفعيل اشتراكك فوراً.',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () {
                    if (onBrowseCourses != null) {
                      onBrowseCourses!();
                    } else {
                      context.go('/');
                    }
                  },
                  icon: const Icon(PhosphorIconsRegular.compass, size: 17),
                  label: const Text('استعراض الدورات المتاحة'),
                ),
              ],
            ),
          )
        else
          ResponsiveCardGrid(
            minItemWidth: 340,
            maxColumns: 2,
            children: [
              for (final course in enrolledCourses)
                _EnrolledCourseCard(
                  course: course,
                  progress: currentUser?.calculateCourseProgress(
                        course.allLessonIds,
                      ) ??
                      0.0,
                  onTap: () => context.go('/course/${course.id}'),
                ),
            ],
          ),
      ],
    );
  }
}

class _EnrolledCourseCard extends StatelessWidget {
  final Course course;
  final double progress;
  final VoidCallback onTap;

  const _EnrolledCourseCard({
    required this.course,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final completedPercent = (progress * 100).round();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderHairline),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 78,
                  height: 78,
                  child: AppCachedImage(
                    imageUrl: course.thumbnailUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            course.title,
                            style: AppTextStyles.heading3.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          PhosphorIconsRegular.caretLeft,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('نسبة الإنجاز', style: AppTextStyles.caption),
                        Text(
                          '$completedPercent%',
                          style: AppTextStyles.caption.copyWith(
                            color: progress >= 1.0
                                ? AppColors.successDark
                                : AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceLevel2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 1.0
                              ? AppColors.success
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

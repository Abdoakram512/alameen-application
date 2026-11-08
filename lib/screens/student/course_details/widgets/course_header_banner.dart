import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_cached_image.dart';
import '../../../../models/course.dart';

/// ترويسة تفاصيل الدورة التدريبية بتصميم مؤسسي واضح ومتجاوب.
class CourseHeaderBanner extends StatelessWidget {
  final Course course;
  final bool isEnrolled;

  const CourseHeaderBanner({
    super.key,
    required this.course,
    required this.isEnrolled,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 760;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderHairline),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: isWide
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 320,
                    child: AppCachedImage(
                      imageUrl: course.thumbnailUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _HeaderInfoBody(
                        course: course,
                        isEnrolled: isEnrolled,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: AppCachedImage(
                    imageUrl: course.thumbnailUrl,
                    fit: BoxFit.cover,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: _HeaderInfoBody(
                    course: course,
                    isEnrolled: isEnrolled,
                  ),
                ),
              ],
            ),
    );
  }
}

class _HeaderInfoBody extends StatelessWidget {
  final Course course;
  final bool isEnrolled;

  const _HeaderInfoBody({
    required this.course,
    required this.isEnrolled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                course.category.isNotEmpty ? course.category : 'تخاطب وتأهيل',
                style: AppTextStyles.label.copyWith(color: AppColors.primary),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isEnrolled
                    ? AppColors.successLight
                    : AppColors.secondaryLight,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                isEnrolled ? 'اشتراك مفعّل' : course.priceFormatted,
                style: AppTextStyles.label.copyWith(
                  color: isEnrolled ? AppColors.successDark : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(course.title, style: AppTextStyles.heading1.copyWith(fontSize: 21)),
        const SizedBox(height: 8),
        Text(course.description, style: AppTextStyles.bodyLarge),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _InfoBadge(
              icon: Icons.person_outline_rounded,
              label: course.instructor,
            ),
            _InfoBadge(
              icon: Icons.layers_outlined,
              label: '${course.levels.length} مستويات تدريبية',
            ),
            _InfoBadge(
              icon: Icons.play_lesson_outlined,
              label: '${course.totalLessonsCount} محاضرة مسجلة',
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}


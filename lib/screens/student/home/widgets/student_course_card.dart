import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_cached_image.dart';
import '../../../../models/course.dart';

/// بطاقة دورة تدريبية متجاوبة خالية من المصطلحات التقنية الداخلية.
class StudentCourseCard extends StatelessWidget {
  final Course course;
  final bool isEnrolled;
  final double progress;
  final VoidCallback onTap;

  const StudentCourseCard({
    super.key,
    required this.course,
    required this.isEnrolled,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isEnrolled
                    ? AppColors.success.withValues(alpha: 0.45)
                    : AppColors.borderHairline,
              ),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(17),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AppCachedImage(
                          imageUrl: course.thumbnailUrl,
                          cacheWidth: 480,
                          fit: BoxFit.cover,
                        ),
                        PositionedDirectional(
                          top: 10,
                          start: 10,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 160),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.68),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              course.category.isNotEmpty
                                  ? course.category
                                  : 'تخاطب وتأهيل',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          bottom: 10,
                          end: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isEnrolled
                                  ? AppColors.success
                                  : AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              isEnrolled
                                  ? 'مشترك ومفعّل'
                                  : course.priceFormatted,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        course.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.heading3.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        course.description
                            .replaceAll(RegExp(r'\s+'), ' ')
                            .trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _MetaItem(
                        icon: PhosphorIconsRegular.chalkboardTeacher,
                        text: course.instructor,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (course.levels.isNotEmpty) ...[
                            _MetaItem(
                              icon: PhosphorIconsRegular.stack,
                              text: '${course.levels.length} مستويات',
                            ),
                            const SizedBox(width: 14),
                          ],
                          _MetaItem(
                            icon: PhosphorIconsRegular.playCircle,
                            text: '${course.totalLessonsCount} محاضرة',
                          ),
                        ],
                      ),
                      if (isEnrolled) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'نسبة الإنجاز',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: AppColors.primaryLight,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

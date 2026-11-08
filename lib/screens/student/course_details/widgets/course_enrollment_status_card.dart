import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/access_request.dart';
import '../../../../models/course.dart';

/// بطاقة موحدة لحالة اشتراك المتدرب (مشترك مع شريط إنجاز واحد، قيد المراجعة، مرفوض مع السبب وإعادة الإرسال، أو غير مشترك).
class CourseEnrollmentStatusCard extends StatelessWidget {
  final Course course;
  final bool isEnrolled;
  final double progress;
  final int completedLessonsCount;
  final CourseAccessRequest? accessRequest;
  final bool isSubmittingRequest;
  final VoidCallback onRequestAccess;

  const CourseEnrollmentStatusCard({
    super.key,
    required this.course,
    required this.isEnrolled,
    required this.progress,
    required this.completedLessonsCount,
    required this.accessRequest,
    required this.isSubmittingRequest,
    required this.onRequestAccess,
  });

  @override
  Widget build(BuildContext context) {
    if (isEnrolled) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderHairline),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'تقدمك في هذه الدورة',
                      style: AppTextStyles.heading3.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: AppTextStyles.heading3.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.primaryLight,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'أكملت $completedLessonsCount من أصل ${course.totalLessonsCount} محاضرة في هذه الدورة.',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      );
    }

    final status = accessRequest?.status;

    if (status == AccessStatus.pending) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.warningLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.warningBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.hourglass_top_rounded,
              color: AppColors.warningDark,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'طلب الالتحاق قيد المراجعة',
                    style: AppTextStyles.heading3.copyWith(
                      color: AppColors.warningDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'تم استلام إيصال السداد (${accessRequest?.paymentMethod ?? ''}) وتتم مراجعته من إدارة المركز لتفعيل جميع محاضرات الدورة.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.warningDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (status == AccessStatus.rejected) {
      final adminNote = accessRequest?.adminNotes.trim() ?? '';
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.errorLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.errorBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.errorDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تعذر اعتماد الإيصال السابق',
                    style: AppTextStyles.heading3.copyWith(
                      color: AppColors.errorDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              adminNote.isNotEmpty
                  ? 'ملاحظة الإدارة: $adminNote'
                  : 'يرجى التأكد من وضوح صورة إيصال التحويل ورقم العملية ثم إعادة الإرسال.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.errorDark,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: isSubmittingRequest ? null : onRequestAccess,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('إعادة إرسال إيصال سداد واضح'),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderHairline),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'رسوم الالتحاق بالدورة',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                course.priceFormatted,
                style: AppTextStyles.heading2.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'يمكنك مشاهدة المحاضرات المتاحة للمعاينة مجاناً، أو إرسال إيصال السداد لتفعيل كامل مستويات الدورة والتكليفات العملية.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: isSubmittingRequest ? null : onRequestAccess,
              icon: isSubmittingRequest
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.receipt_long_rounded, size: 19),
              label: const Text('طلب الاشتراك وإرفاق إيصال السداد'),
            ),
          ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/access_request.dart';
import '../../../../models/course.dart';
import '../../../../models/course_access_mode.dart';

/// بطاقة موحدة لحالة اشتراك المتدرب (مشترك مع شريط إنجاز واحد، قيد المراجعة، مرفوض مع السبب وإعادة الإرسال، أو غير مشترك).
class CourseEnrollmentStatusCard extends StatelessWidget {
  final Course course;
  final bool isEnrolled;
  final bool isExpired;
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
    this.isExpired = false,
  });

  @override
  Widget build(BuildContext context) {
    if (course.isEnrollmentClosed && !isEnrolled) {
      return Container(
        padding: const EdgeInsets.all(20),
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
                const Icon(Icons.lock_clock_rounded, color: AppColors.errorDark, size: 22),
                const SizedBox(width: 8),
                Text(
                  'هذه الدورة مغلقة حالياً',
                  style: AppTextStyles.heading3.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.errorDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'تم إغلاق التسجيل والمحتوى لهذه الدورة التدريبية من قبل إدارة المركز.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.errorDark),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.support_agent_rounded, size: 18),
                label: const Text('تواصل مع إدارة المركز للاستفسار'),
                onPressed: () {
                  AppConstants.launchWhatsApp(
                    customMessage: 'السلام عليكم، أود الاستفسار عن موعد فتح التسجيل في دورة "${course.title}".',
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    if (isExpired) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.warningLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.warningBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer_off_rounded, color: AppColors.warningDark, size: 22),
                const SizedBox(width: 8),
                Text(
                  'انتهت صلاحية اشتراكك في هذه الدورة',
                  style: AppTextStyles.heading3.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.warningDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'انتهت مدة الصلاحية المحددة للاشتراك. لتمديد صلاحيتك ومتابعة الدروس، يرجى التواصل مع إدارة المركز.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.warningDark),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.schedule_rounded, size: 18),
                label: const Text('طلب تمديد الصلاحية عبر واتساب'),
                onPressed: () {
                  AppConstants.launchWhatsApp(
                    customMessage: 'السلام عليكم، أرغب في تمديد صلاحية اشتراكي في دورة "${course.title}".',
                  );
                },
              ),
            ),
          ],
        ),
      );
    }
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

    if (course.accessMode == CourseAccessMode.assignedOnly) {
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
              children: [
                const Icon(
                  Icons.lock_person_outlined,
                  color: AppColors.royalNavy,
                ),
                const SizedBox(width: 8),
                Text(
                  'دورة بتسجيل محدد',
                  style: AppTextStyles.heading3.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'هذه الدورة التدريبية مخصصة لطلاب معينين من قبل الأكاديمية فقط. إذا كنت مرشحاً للدورة، يرجى التواصل مع الإدارة لإتاحتها لحسابك.',
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (course.accessMode == CourseAccessMode.open) {
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
                  'الالتحاق بالدورة',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.successBorder),
                  ),
                  child: const Text(
                    'مفتوح ومجاني',
                    style: TextStyle(
                      color: AppColors.successDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'هذه الدورة مفتوحة ومتاحة لجميع الطلاب مجاناً بدون الحاجة لموافقة أو إيصالات سداد.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                ),
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
                    : const Icon(Icons.play_circle_fill_rounded, size: 20),
                label: const Text('ابدأ الدورة الآن مجاناً'),
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


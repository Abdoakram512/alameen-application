import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../features/courses/domain/entities/course_entitlement.dart';
import '../../../../features/payments/domain/entities/payment_receipt.dart';
import '../../../../features/payments/domain/entities/receipt_status.dart';
import '../../../../models/course.dart';
import '../../../../models/course_access_mode.dart';

/// بطاقة موحدة لحالة أهلية المتدرب بالدورة وسجل أحدث إيصال مالي (للعرض فقط).
class CourseEnrollmentStatusCard extends StatelessWidget {
  final Course course;
  final bool isEnrolled;
  final bool isExpired;
  final double progress;
  final int completedLessonsCount;
  final CourseEntitlement? entitlement;
  final PaymentReceipt? latestReceipt;
  final bool isVerifyingEntitlement;
  final VoidCallback onRequestAccess;
  final VoidCallback? onRetryVerification;

  const CourseEnrollmentStatusCard({
    super.key,
    required this.course,
    required this.isEnrolled,
    this.isExpired = false,
    required this.progress,
    required this.completedLessonsCount,
    this.entitlement,
    this.latestReceipt,
    this.isVerifyingEntitlement = false,
    required this.onRequestAccess,
    this.onRetryVerification,
  });

  @override
  Widget build(BuildContext context) {
    if (course.isEnrollmentClosed && !isEnrolled) {
      return _BannerCard(
        backgroundColor: AppColors.errorLight,
        borderColor: AppColors.errorBorder,
        icon: Icons.lock_clock_rounded,
        iconColor: AppColors.errorDark,
        title: 'هذه الدورة مغلقة حالياً',
        titleColor: AppColors.errorDark,
        body: 'تم إغلاق التسجيل والمحتوى لهذه الدورة التدريبية من قبل إدارة المركز.',
        actionLabel: 'تواصل مع إدارة المركز للاستفسار',
        actionIcon: Icons.support_agent_rounded,
        actionColor: const Color(0xFF25D366),
        onAction: () {
          AppConstants.launchWhatsApp(
            customMessage:
                'السلام عليكم، أود الاستفسار عن موعد فتح التسجيل في دورة "${course.title}".',
          );
        },
      );
    }

    if (isExpired) {
      return _BannerCard(
        backgroundColor: AppColors.warningLight,
        borderColor: AppColors.warningBorder,
        icon: Icons.timer_off_rounded,
        iconColor: AppColors.warningDark,
        title: 'انتهت صلاحية اشتراكك في هذه الدورة',
        titleColor: AppColors.warningDark,
        body:
            'انتهت مدة الصلاحية المحددة للاشتراك. لتمديد صلاحيتك ومتابعة الدروس، يرجى التواصل مع إدارة المركز.',
        actionLabel: 'طلب تمديد الصلاحية عبر واتساب',
        actionIcon: Icons.schedule_rounded,
        actionColor: const Color(0xFF25D366),
        onAction: () {
          AppConstants.launchWhatsApp(
            customMessage:
                'السلام عليكم، أرغب في تمديد صلاحية اشتراكي في دورة "${course.title}".',
          );
        },
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

    // التمييز الصارم بين فشل الشبكة المؤقت ورفض الخادم الصريح
    final accessStatus = entitlement?.status;
    if (accessStatus == CourseAccessState.networkUnavailable) {
      return _BannerCard(
        backgroundColor: AppColors.warningLight,
        borderColor: AppColors.warningBorder,
        icon: Icons.wifi_off_rounded,
        iconColor: AppColors.warningDark,
        title: 'تعذر التحقق من الاشتراك مؤقتاً',
        titleColor: AppColors.warningDark,
        body: entitlement?.message ??
            'يوجد انقطاع في الاتصال بالشبكة حالياً، ولا يمكن فتح المحتوى المحمي إلا بعد تأكيد الخادم.',
        actionLabel: 'إعادة المحاولة الآن',
        actionIcon: Icons.refresh_rounded,
        actionColor: AppColors.primary,
        onAction: isVerifyingEntitlement
            ? null
            : (onRetryVerification ?? onRequestAccess),
      );
    }

    if (accessStatus == CourseAccessState.unauthorized) {
      return _BannerCard(
        backgroundColor: AppColors.errorLight,
        borderColor: AppColors.errorBorder,
        icon: Icons.lock_outline_rounded,
        iconColor: AppColors.errorDark,
        title: 'يرجى إعادة تسجيل الدخول',
        titleColor: AppColors.errorDark,
        body: entitlement?.message ??
            'انتهت صلاحية جلسة الطالب الحالية. سجّل الدخول مجدداً للتحقق من اشتراكك.',
      );
    }

    if (accessStatus == CourseAccessState.forbidden) {
      final hasExplicitReason =
          entitlement?.forbiddenReasonCode?.trim().isNotEmpty == true;
      return _BannerCard(
        backgroundColor: AppColors.errorLight,
        borderColor: AppColors.errorBorder,
        icon: Icons.block_rounded,
        iconColor: AppColors.errorDark,
        title: 'الوصول غير متاح حالياً',
        titleColor: AppColors.errorDark,
        body: entitlement?.message ??
            (hasExplicitReason
                ? 'تم رفض الوصول من الخادم (${entitlement!.forbiddenReasonCode}).'
                : 'رفض الخادم طلب الوصول لهذا المحتوى (403). يرجى مراجعة إدارة المركز.'),
        actionLabel: 'تواصل مع الدعم / الإدارة',
        actionIcon: Icons.support_agent_rounded,
        actionColor: const Color(0xFF25D366),
        onAction: () {
          AppConstants.launchWhatsApp(
            customMessage:
                'السلام عليكم، أرجو مراجعة حالة الوصول الخاصة بي في دورة "${course.title}".',
          );
        },
      );
    }

    if (accessStatus == CourseAccessState.failure) {
      return _BannerCard(
        backgroundColor: AppColors.errorLight,
        borderColor: AppColors.errorBorder,
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.errorDark,
        title: 'تعذر إتمام التحقق من الخادم',
        titleColor: AppColors.errorDark,
        body: entitlement?.message ??
            'حدث خطأ مؤقت أثناء التحقق من أهليتك لهذه الدورة.',
        actionLabel: 'إعادة التحقق',
        actionIcon: Icons.refresh_rounded,
        actionColor: AppColors.primary,
        onAction: isVerifyingEntitlement
            ? null
            : (onRetryVerification ?? onRequestAccess),
      );
    }

    // عرض حالة أحدث إيصال مالي كسجل تاريخي فقط (دون اعتباره ترخيصاً بالدخول)
    final receiptStatus = latestReceipt?.status;
    if (receiptStatus == ReceiptStatus.pending) {
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
                    'إيصال السداد قيد المراجعة الإدارية',
                    style: AppTextStyles.heading3.copyWith(
                      color: AppColors.warningDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'تم استلام إيصال السداد (${latestReceipt?.displayMethodLabel ?? ''}) وتتم مراجعته من إدارة المركز لتفعيل اشتراكك على الخادم.',
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

    if (receiptStatus == ReceiptStatus.rejected) {
      final adminNote = latestReceipt?.adminNotes?.trim() ?? '';
      return _BannerCard(
        backgroundColor: AppColors.errorLight,
        borderColor: AppColors.errorBorder,
        icon: Icons.info_outline_rounded,
        iconColor: AppColors.errorDark,
        title: 'تعذر اعتماد الإيصال السابق',
        titleColor: AppColors.errorDark,
        body: adminNote.isNotEmpty
            ? 'ملاحظة الإدارة: $adminNote'
            : 'يرجى التأكد من وضوح صورة إيصال التحويل ورقم العملية ثم إعادة الإرسال.',
        actionLabel: 'إعادة إرسال إيصال سداد واضح',
        actionIcon: Icons.upload_file_rounded,
        actionColor: AppColors.primary,
        onAction: isVerifyingEntitlement ? null : onRequestAccess,
      );
    }

    if (receiptStatus == ReceiptStatus.approved) {
      // إيصال مالي معتمد تاريخياً مع عدم وجود اشتراك نشط على الخادم: لا يمنح دخولاً!
      return _BannerCard(
        backgroundColor: AppColors.warningLight,
        borderColor: AppColors.warningBorder,
        icon: Icons.receipt_long_rounded,
        iconColor: AppColors.warningDark,
        title: 'الاشتراك غير مفعل حالياً على الخادم',
        titleColor: AppColors.warningDark,
        body:
            'يوجد إيصال مالي معتمد سابقاً (#${latestReceipt!.id})، لكن تفعيل الوصول الحالي للدورة غير نشط على الخادم. يمكنك إعادة التحقق أو التواصل مع الإدارة.',
        actionLabel: 'تحديث الحالة من الخادم',
        actionIcon: Icons.refresh_rounded,
        actionColor: AppColors.primary,
        onAction: isVerifyingEntitlement
            ? null
            : (onRetryVerification ?? onRequestAccess),
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
                    'دورة مجانية',
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
              'يتحقق التطبيق من الخادم لتأكيد تسجيلك وإتاحة محاضرات هذه الدورة لحسابك.',
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
                onPressed: isVerifyingEntitlement ? null : onRequestAccess,
                icon: isVerifyingEntitlement
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.play_circle_fill_rounded, size: 20),
                label: const Text('التحقق من الأهلية وبدء الدورة'),
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
              onPressed: isVerifyingEntitlement ? null : onRequestAccess,
              icon: isVerifyingEntitlement
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

class _BannerCard extends StatelessWidget {
  final Color backgroundColor;
  final Color borderColor;
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color titleColor;
  final String body;
  final String? actionLabel;
  final IconData? actionIcon;
  final Color? actionColor;
  final VoidCallback? onAction;

  const _BannerCard({
    required this.backgroundColor,
    required this.borderColor,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.titleColor,
    required this.body,
    this.actionLabel,
    this.actionIcon,
    this.actionColor,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.heading3.copyWith(
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: AppTextStyles.bodyMedium.copyWith(color: titleColor),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: actionColor ?? AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.refresh_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

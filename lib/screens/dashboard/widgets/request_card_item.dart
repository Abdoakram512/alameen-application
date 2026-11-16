import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dialogs/receipt_preview_dialog.dart';
import '../../../core/widgets/student_avatar.dart';
import '../../../logic/requests/admin_requests_cubit.dart';
import '../../../models/access_request.dart';
import 'reject_request_dialog.dart';

/// Alameen Center Clean Payment Request Triage Card
class RequestCardItem extends StatelessWidget {
  final CourseAccessRequest request;

  const RequestCardItem({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final isPending = request.status == AccessStatus.pending;
    final isApproved = request.status == AccessStatus.approved;
    bool isBusy = false;
    try {
      isBusy = context.watch<AdminRequestsCubit>().isRequestBusy(request.id);
    } catch (_) {
      isBusy = false;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending
              ? AppColors.warningAmber
              : (isApproved ? AppColors.successBorder : AppColors.errorBorder),
          width: isPending ? 1.5 : 1.0,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student and Status Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: StudentAvatar(
                    name: request.studentName,
                    photoUrl: request.studentAvatar,
                    radius: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.studentName.isNotEmpty
                            ? request.studentName
                            : 'requests.student_fallback'.tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      if (request.studentEmail.isNotEmpty)
                        Text(
                          request.studentEmail,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isPending
                          ? AppColors.warningLight
                          : (isApproved
                                ? AppColors.successLight
                                : AppColors.errorLight),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isPending
                            ? AppColors.warningBorder
                            : (isApproved
                                  ? AppColors.successBorder
                                  : AppColors.errorBorder),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      isPending
                          ? 'requests.pending'.tr()
                          : (isApproved
                                ? 'requests.approved'.tr()
                                : 'requests.rejected'.tr()),
                      style: TextStyle(
                        color: isPending
                            ? AppColors.warningDark
                            : (isApproved
                                  ? AppColors.successDark
                                  : AppColors.errorDark),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),

            // Requested Course
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceLevel0,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.school_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${'requests.requested_course'.tr()}: ${request.courseTitle}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Payment details
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.payment_outlined,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${'requests.payment_method'.tr()}: ${request.paymentMethod}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            if (request.senderNumberOrRef.isNotEmpty)
              TextButton.icon(
                style: TextButton.styleFrom(
                  alignment: AlignmentDirectional.centerStart,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: request.senderNumberOrRef),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('requests.ref_copied'.tr()),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: Text(
                  '${'requests.transfer_ref'.tr()}: ${request.senderNumberOrRef}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),

            // Receipt preview (optional)
            if (request.receiptUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.royalNavy,
                  side: const BorderSide(color: AppColors.borderHairline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onPressed: () => ReceiptPreviewDialog.show(
                  context,
                  imageUrl: request.receiptUrl,
                ),
                icon: const Icon(Icons.image_outlined, size: 16),
                label: Text(
                  'requests.view_receipt'.tr(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: request.paymentMethod.contains('مباشر')
                      ? AppColors.primaryLight.withValues(alpha: 0.5)
                      : AppColors.surfaceLevel0,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: request.paymentMethod.contains('مباشر')
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : AppColors.borderHairline,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      request.paymentMethod.contains('مباشر')
                          ? Icons.verified_user_outlined
                          : Icons.info_outline_rounded,
                      size: 14,
                      color: request.paymentMethod.contains('مباشر')
                          ? AppColors.primary
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      request.paymentMethod.contains('مباشر')
                          ? 'طلب مباشر بدون إيصال (بانتظار موافقة الإدارة)'
                          : 'requests.no_receipt'.tr(),
                      style: TextStyle(
                        fontSize: 11,
                        color: request.paymentMethod.contains('مباشر')
                            ? AppColors.primary
                            : AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action Buttons for Pending
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.successDark,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: isBusy
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              context.read<AdminRequestsCubit>().approveRequest(
                                requestId: request.id,
                                studentId: request.studentId,
                                courseId: request.courseId,
                                studentName: request.studentName,
                                levelId: request.levelId,
                              );
                            },
                      child: isBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'requests.approve_btn'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.errorBorder),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: isBusy
                        ? null
                        : () =>
                            RejectRequestDialog.show(context, request: request),
                    child: Text(
                      'requests.reject_btn'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ] else if (isApproved) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.successLight.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.successBorder),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppColors.successDark,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'تم اعتماد الطلب وتفعيل الكورس للطالب بنجاح',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.successDark,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (request.status == AccessStatus.rejected) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.errorLight.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.errorBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.cancel_rounded,
                      size: 16,
                      color: AppColors.errorDark,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تم رفض الطلب: ${request.adminNotes.isNotEmpty ? request.adminNotes : "لم يُحدد سبب"}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.errorDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

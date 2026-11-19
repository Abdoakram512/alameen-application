import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_directional_icons.dart';
import '../../../../features/payments/domain/entities/payment_receipt.dart';
import '../../../../features/payments/domain/entities/receipt_status.dart';
import '../../../../features/payments/presentation/cubits/receipts/receipts_cubit.dart';
import '../../../../features/payments/presentation/cubits/receipts/receipts_state.dart';

/// قسم متابعة سجل الإيصالات المالية الخاصة بالمتدرب (للتدقيق المالي فقط، ولا يمنح أهلية).
class StudentRequestsStatusSection extends StatelessWidget {
  const StudentRequestsStatusSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReceiptsCubit, ReceiptsState>(
      builder: (context, state) {
        final receipts = state.historyOrNull?.receipts ?? const <PaymentReceipt>[];
        if (receipts.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    PhosphorIconsRegular.receipt,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.locale.languageCode == 'ar'
                        ? 'سجل إيصالات السداد'
                        : 'Payment Receipts History',
                    style: AppTextStyles.heading2,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < receipts.length; i++) ...[
                _ReceiptHistoryTile(receipt: receipts[i]),
                if (i < receipts.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ReceiptHistoryTile extends StatelessWidget {
  final PaymentReceipt receipt;

  const _ReceiptHistoryTile({required this.receipt});

  @override
  Widget build(BuildContext context) {
    final isAr = context.locale.languageCode == 'ar';
    final (label, bgColor, fgColor, icon) = switch (receipt.status) {
      ReceiptStatus.approved => (
          isAr ? 'تم اعتماد الإيصال' : 'Receipt Approved',
          AppColors.successLight,
          AppColors.successDark,
          PhosphorIconsFill.checkCircle,
        ),
      ReceiptStatus.rejected => (
          isAr ? 'يحتاج مراجعة' : 'Needs Review',
          AppColors.errorLight,
          AppColors.errorDark,
          PhosphorIconsFill.warningCircle,
        ),
      ReceiptStatus.pending => (
          isAr ? 'قيد المراجعة' : 'Pending',
          AppColors.warningLight,
          AppColors.warningDark,
          PhosphorIconsFill.clockCountdown,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receipt.displayCourseTitle,
                      style: AppTextStyles.heading3.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (receipt.id > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        'إيصال سداد #${receipt.id}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    receipt.status == ReceiptStatus.approved
                        ? AppDirectionalIcons.checkCircle(
                            size: 13,
                            color: fgColor,
                          )
                        : Icon(icon, size: 13, color: fgColor),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: AppTextStyles.caption.copyWith(
                        color: fgColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                'وسيلة السداد: ${receipt.displayMethodLabel}',
                style: AppTextStyles.caption,
              ),
              if (receipt.displaySenderReference.trim().isNotEmpty)
                Text(
                  'مرجع التحويل: ${receipt.displaySenderReference}',
                  style: AppTextStyles.caption.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              Text(
                (receipt.receiptImageUrl ?? '').trim().isNotEmpty
                    ? 'مرفق صورة إيصال'
                    : 'بدون صورة إيصال',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          if ((receipt.adminNotes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.scaffoldBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderHairline),
              ),
              child: Text(
                'ملاحظة الإدارة: ${receipt.adminNotes}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

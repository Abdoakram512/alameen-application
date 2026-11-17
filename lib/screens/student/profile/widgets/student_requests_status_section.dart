import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_directional_icons.dart';
import '../../../../logic/access/access_cubit.dart';
import '../../../../logic/access/access_state.dart';
import '../../../../models/access_request.dart';

/// قسم متابعة طلبات الاشتراك الخاصة بالمتدرب (يظهر تلقائياً عند وجود طلبات سابقة أو قيد المراجعة).
class StudentRequestsStatusSection extends StatelessWidget {
  const StudentRequestsStatusSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccessCubit, AccessState>(
      builder: (context, state) {
        final List<CourseAccessRequest> requests;
        if (state is AccessLoaded && state.allRequests.isNotEmpty) {
          requests = state.allRequests;
        } else if (state is AccessLoading && state.allRequests.isNotEmpty) {
          requests = state.allRequests;
        } else {
          Map<String, CourseAccessRequest> map = const {};
          if (state is AccessLoaded) {
            map = state.requestsByCourse;
          } else if (state is AccessLoading) {
            map = state.requestsByCourse;
          }
          if (map.isEmpty) return const SizedBox.shrink();
          requests = map.values.toList()..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
        }

        if (requests.isEmpty) return const SizedBox.shrink();

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
                        ? 'متابعة طلبات الاشتراك'
                        : 'Enrollment Requests Status',
                    style: AppTextStyles.heading2,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < requests.length; i++) ...[
                _StudentRequestTile(request: requests[i]),
                if (i < requests.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StudentRequestTile extends StatelessWidget {
  final CourseAccessRequest request;

  const _StudentRequestTile({required this.request});

  @override
  Widget build(BuildContext context) {
    final isAr = context.locale.languageCode == 'ar';
    final (label, bgColor, fgColor, icon) = switch (request.status) {
      AccessStatus.approved => (
          isAr ? 'تم التفعيل' : 'Active',
          AppColors.successLight,
          AppColors.successDark,
          PhosphorIconsFill.checkCircle,
        ),
      AccessStatus.rejected => (
          isAr ? 'يحتاج مراجعة' : 'Needs Review',
          AppColors.errorLight,
          AppColors.errorDark,
          PhosphorIconsFill.warningCircle,
        ),
      AccessStatus.pending => (
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
                      request.courseTitle,
                      style: AppTextStyles.heading3.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (request.id.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'إيصال سداد #${request.id}',
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
                    request.status == AccessStatus.approved
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
                'وسيلة السداد: ${request.paymentMethod}',
                style: AppTextStyles.caption,
              ),
              if (request.senderNumberOrRef.trim().isNotEmpty)
                Text(
                  'مرجع التحويل: ${request.senderNumberOrRef}',
                  style: AppTextStyles.caption.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              Text(
                request.receiptUrl.trim().isNotEmpty
                    ? 'مرفق صورة إيصال'
                    : 'بدون صورة إيصال',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          if (request.adminNotes.trim().isNotEmpty) ...[
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
                'ملاحظة الإدارة: ${request.adminNotes}',
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


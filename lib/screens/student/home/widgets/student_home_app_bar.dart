import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../../../core/widgets/student_avatar.dart';
import '../../../../features/payments/domain/entities/payment_receipt.dart';
import '../../../../features/payments/domain/entities/receipt_history.dart';
import '../../../../features/payments/domain/entities/receipt_status.dart';
import '../../../../features/payments/presentation/cubits/receipts/receipts_cubit.dart';
import '../../../../features/payments/presentation/cubits/receipts/receipts_state.dart';
import '../../../../logic/auth/auth_cubit.dart';
import '../../../../logic/auth/auth_state.dart';
import '../../../../repositories/student_notifications_repository.dart';
import '../../../../widgets/language_switch_button.dart';

/// الشريط العلوي لبوابة المتدرب مع عداد فعلي لحالة طلبات الالتحاق (بدلاً من الأرقام الوهمية).
class StudentHomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? displayName;
  final String? photoUrl;

  const StudentHomeAppBar({
    super.key,
    this.displayName,
    this.photoUrl,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final effectiveName =
        displayName ??
        context.select<AuthCubit, String>((c) {
          final s = c.state;
          if (s is Authenticated) {
            return s.user.displayName.trim().isNotEmpty
                ? s.user.displayName
                : 'home.student_fallback'.tr();
          }
          return 'home.student_fallback'.tr();
        });
    final effectivePhoto =
        photoUrl ??
        context.select<AuthCubit, String>((c) {
          final s = c.state;
          return s is Authenticated ? s.user.photoUrl : '';
        });

    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      titleSpacing: 16,
      title: Row(
        children: [
          StudentAvatar(
            name: effectiveName,
            photoUrl: effectivePhoto,
            radius: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('home.welcome_back'.tr(), style: AppTextStyles.caption),
                Text(
                  effectiveName,
                  style: AppTextStyles.heading3.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        const LanguageSwitchButton(compact: true),
        const SizedBox(width: 4),
        // زر متابعة إيصالات السداد المالي
        BlocBuilder<ReceiptsCubit, ReceiptsState>(
          builder: (context, receiptsState) {
            final history = receiptsState.historyOrNull ?? ReceiptHistory.empty;
            final activeCount = history.activeActionableCount;

            return IconButton(
              tooltip: 'سجل إيصالات السداد',
              icon: Badge(
                isLabelVisible: activeCount > 0,
                backgroundColor: AppColors.warning,
                textColor: Colors.white,
                label: Text(
                  '$activeCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Icon(
                  PhosphorIconsRegular.receipt,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              onPressed: () {
                final authState = context.read<AuthCubit>().state;
                if (authState is Authenticated) {
                  unawaited(
                    context.read<ReceiptsCubit>().loadReceipts(
                      studentId: authState.user.uid,
                      silent: history.receipts.isNotEmpty,
                    ),
                  );
                }
                _showReceiptsStatusSheet(context);
              },
            );
          },
        ),
        // جرس الإشعارات والتنبيهات المربوط بـ Laravel Notifications REST API
        if (sl.isRegistered<StudentNotificationsRepository>())
          ValueListenableBuilder<int>(
            valueListenable:
                sl<StudentNotificationsRepository>().unreadCountListenable,
            builder: (context, unreadCount, _) {
              return IconButton(
                tooltip: 'الإشعارات والتنبيهات',
                icon: Badge(
                  isLabelVisible: unreadCount > 0,
                  backgroundColor: AppColors.primary,
                  textColor: Colors.white,
                  label: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Icon(
                    PhosphorIconsRegular.bell,
                    color: AppColors.primary,
                    size: 23,
                  ),
                ),
                onPressed: () {
                  context.push('/notifications');
                },
              );
            },
          )
        else
          IconButton(
            tooltip: 'الإشعارات والتنبيهات',
            icon: const Icon(
              PhosphorIconsRegular.bell,
              color: AppColors.primary,
              size: 23,
            ),
            onPressed: () {
              context.push('/notifications');
            },
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  void _showReceiptsStatusSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return BlocBuilder<ReceiptsCubit, ReceiptsState>(
          bloc: context.read<ReceiptsCubit>(),
          builder: (context, receiptsState) {
            final receipts =
                receiptsState.historyOrNull?.receipts ??
                const <PaymentReceipt>[];
            final sorted = List<PaymentReceipt>.from(receipts)
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            final isLoading =
                receiptsState is ReceiptsLoading && sorted.isEmpty;

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 560,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.88,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4.5,
                        margin: const EdgeInsets.only(top: 14, bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              PhosphorIconsRegular.receipt,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'سجل إيصالات السداد المالي',
                              style: AppTextStyles.heading3.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(PhosphorIconsRegular.x, size: 20),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Divider(height: 1, color: AppColors.divider),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(
                          child: AppLoadingIndicator(
                            message: 'جاري تحميل سجل إيصالات السداد...',
                          ),
                        ),
                      )
                    else if (sorted.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 32,
                        ),
                        child: Center(
                          child: Text(
                            'لا توجد إيصالات سداد مسجلة حالياً.',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                          itemCount: sorted.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              final receipt = sorted[index];
                              final (
                                label,
                                color,
                                bg,
                              ) = switch (receipt.status) {
                                ReceiptStatus.approved => (
                                  'تم اعتماد الإيصال',
                                  AppColors.successDark,
                                  AppColors.successLight,
                                ),
                                ReceiptStatus.rejected => (
                                  'يحتاج مراجعة الإيصال',
                                  AppColors.errorDark,
                                  AppColors.errorLight,
                                ),
                                ReceiptStatus.pending => (
                                  'قيد المراجعة',
                                  AppColors.warningDark,
                                  AppColors.warningLight,
                                ),
                              };

                              return InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  context.go('/course/${receipt.courseId}');
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.scaffoldBackground,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.borderHairline,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              receipt.displayCourseTitle,
                                              style: AppTextStyles.bodyLarge
                                                  .copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            if (receipt.status ==
                                                    ReceiptStatus.rejected &&
                                                (receipt.adminNotes ?? '')
                                                    .trim()
                                                    .isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                'ملاحظة الإدارة: ${receipt.adminNotes}',
                                                style: AppTextStyles.caption
                                                    .copyWith(
                                                      color:
                                                          AppColors.errorDark,
                                                    ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: bg,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          label,
                                          style: AppTextStyles.label.copyWith(
                                            color: color,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    }
  }

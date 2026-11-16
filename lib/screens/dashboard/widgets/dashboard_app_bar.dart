import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/language_switch_button.dart';

/// شريط علوي تنفيذي نظيف يعرض الهوية المؤسسية وعدد الطلبات المعلقة الفعلي فقط.
class DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int pendingCount;
  final VoidCallback? onOpenRequests;

  const DashboardAppBar({
    super.key,
    this.pendingCount = 0,
    this.onOpenRequests,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 64,
      titleSpacing: 16,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: AppColors.borderHairline,
          height: 1,
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: AppColors.borderHairline, width: 1.2),
            ),
            padding: const EdgeInsets.all(2),
            child: ClipOval(
              child: Image.asset(
                AppConstants.logoAsset,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: AppColors.royalNavy,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppConstants.appName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.royalNavy,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  AppConstants.appNameAr,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        const AdminLanguageSwitchButton(compact: true),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'app_bar.pending_summary_tooltip'.tr(),
          icon: Badge(
            isLabelVisible: pendingCount > 0,
            backgroundColor: AppColors.warningDark,
            label: Text(
              pendingCount > 99 ? '99+' : '$pendingCount',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            child: const Icon(
              Icons.notifications_outlined,
              color: AppColors.royalNavy,
              size: 24,
            ),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            _showPendingRequestsSummary(context);
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  void _showPendingRequestsSummary(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderHairline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.fact_check_outlined,
                          color: AppColors.royalNavy,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'app_bar.pending_sheet_title'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: pendingCount > 0
                          ? AppColors.warningLight
                          : AppColors.surfaceLevel0,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: pendingCount > 0
                            ? AppColors.warningBorder
                            : AppColors.borderHairline,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          pendingCount > 0
                              ? Icons.receipt_long_rounded
                              : Icons.check_circle_outline_rounded,
                          color: pendingCount > 0
                              ? AppColors.warningDark
                              : AppColors.successDark,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            pendingCount > 0
                                ? 'app_bar.pending_sheet_msg'.tr(args: ['$pendingCount'])
                                : 'app_bar.pending_sheet_empty'.tr(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (pendingCount > 0 && onOpenRequests != null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.royalNavy,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          onOpenRequests?.call();
                        },
                        icon: Icon(
                          Directionality.of(context) == TextDirection.rtl
                              ? Icons.arrow_back_rounded
                              : Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                        label: Text(
                          'app_bar.go_to_requests'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }
  }


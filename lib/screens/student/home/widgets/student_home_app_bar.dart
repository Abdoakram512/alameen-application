import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/student_avatar.dart';
import '../../../../logic/access/access_cubit.dart';
import '../../../../logic/access/access_state.dart';
import '../../../../models/access_request.dart';
import '../../../../widgets/language_switch_button.dart';

/// الشريط العلوي لبوابة المتدرب مع عداد فعلي لحالة طلبات الالتحاق (بدلاً من الأرقام الوهمية).
class StudentHomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String displayName;
  final String photoUrl;

  const StudentHomeAppBar({
    super.key,
    required this.displayName,
    required this.photoUrl,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      titleSpacing: 16,
      title: Row(
        children: [
          StudentAvatar(
            name: displayName,
            photoUrl: photoUrl,
            radius: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('مرحباً بعودتك', style: AppTextStyles.caption),
                Text(
                  displayName,
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
        BlocBuilder<AccessCubit, AccessState>(
          builder: (context, accessState) {
            final requests = accessState is AccessLoaded
                ? accessState.requestsByCourse.values.toList()
                : const <CourseAccessRequest>[];
            final activeCount = requests
                .where(
                  (r) =>
                      r.status == AccessStatus.pending ||
                      r.status == AccessStatus.rejected,
                )
                .length;

            return IconButton(
              tooltip: 'متابعة طلبات الالتحاق',
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
                  PhosphorIconsRegular.bell,
                  color: AppColors.primary,
                  size: 23,
                ),
              ),
              onPressed: () => _showRequestsStatusSheet(context, requests),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  void _showRequestsStatusSheet(
    BuildContext context,
    List<CourseAccessRequest> requests,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        final sorted = List<CourseAccessRequest>.from(requests)
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

        return SafeArea(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        PhosphorIconsRegular.receipt,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'حالة طلبات الالتحاق بالدورات',
                          style: AppTextStyles.heading3.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(PhosphorIconsRegular.x, size: 19),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  if (sorted.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'لا توجد طلبات التحاق معلقة حالياً.',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: sorted.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final req = sorted[index];
                          final (label, color, bg) = switch (req.status) {
                            AccessStatus.approved => (
                              'مقبول ومفعّل',
                              AppColors.successDark,
                              AppColors.successLight,
                            ),
                            AccessStatus.rejected => (
                              'يحتاج مراجعة الإيصال',
                              AppColors.errorDark,
                              AppColors.errorLight,
                            ),
                            AccessStatus.pending => (
                              'قيد المراجعة',
                              AppColors.warningDark,
                              AppColors.warningLight,
                            ),
                          };

                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              context.go('/course/${req.courseId}');
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
                                          req.courseTitle,
                                          style: AppTextStyles.bodyLarge
                                              .copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        if (req.status ==
                                                AccessStatus.rejected &&
                                            req.adminNotes
                                                .trim()
                                                .isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'ملاحظة الإدارة: ${req.adminNotes}',
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                  color: AppColors.errorDark,
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
                                      borderRadius: BorderRadius.circular(999),
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
          ),
        );
      },
    );
  }
}


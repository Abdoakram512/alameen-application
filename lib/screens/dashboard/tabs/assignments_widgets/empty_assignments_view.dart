import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/feedback/app_empty_state.dart';

/// واجهة الحالة الفارغة لقسم التكليفات والواجبات عند عدم وجود تسليمات أو عند عدم تطابق الفلتر.
class EmptyAssignmentsView extends StatelessWidget {
  final bool isAr;
  final bool isFilterEmpty;

  const EmptyAssignmentsView({
    super.key,
    required this.isAr,
    this.isFilterEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isFilterEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                PhosphorIconsRegular.magnifyingGlass,
                size: 40,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 12),
              Text(
                isAr
                    ? 'لا توجد تسليمات مطابقة للفلتر المحدد'
                    : 'No matching submissions found',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: AppEmptyState(
        title: isAr
            ? 'لا توجد تسليمات حتى الآن'
            : 'No Submissions Yet',
        subtitle: isAr
            ? 'سوف تظهر هنا تسليمات المتدربين ومرفقاتهم فور إرسالها من التطبيق.'
            : 'Student practical submissions will appear here once sent.',
        icon: PhosphorIconsRegular.tray,
      ),
    );
  }
}

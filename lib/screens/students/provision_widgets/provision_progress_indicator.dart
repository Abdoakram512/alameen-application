import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';

/// زر وحالة تنفيذ تهيئة حسابات المتدربين مع مؤشر التقدم.
class ProvisionProgressIndicatorButton extends StatelessWidget {
  final bool isSubmitting;
  final int completedCount;
  final int totalCount;
  final int activeTabIndex;
  final VoidCallback onSubmit;

  const ProvisionProgressIndicatorButton({
    super.key,
    required this.isSubmitting,
    required this.completedCount,
    required this.totalCount,
    required this.activeTabIndex,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: isSubmitting ? null : onSubmit,
        icon: isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(PhosphorIconsRegular.checkCircle, size: 19),
        label: Text(
          isSubmitting
              ? 'جاري تجهيز الحساب $completedCount من $totalCount...'
              : (activeTabIndex == 0
                  ? 'إنشاء حساب المتدرب وتفعيل الدورات'
                  : 'إنشاء وتفعيل جميع الحسابات المضافة'),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/student_provisioning_service.dart';

/// وحدة التحكم بسطر إدخال بيانات متدرب في الإضافة الجماعية.
class BulkRowControllers {
  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController password;

  BulkRowControllers({
    String initialName = '',
    String initialEmail = '',
    String? initialPassword,
  })  : name = TextEditingController(text: initialName),
        email = TextEditingController(text: initialEmail),
        password = TextEditingController(
          text: initialPassword ??
              StudentProvisioningService.generateStrongPassword(),
        );

  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
  }
}

/// محرر إضافة مجموعة متدربين دفعة واحدة مع دعم لصق القوائم السريعة (CSV/النص المنسوخ).
class BulkStudentsProvisionEditor extends StatelessWidget {
  final List<BulkRowControllers> bulkRows;
  final bool isSubmitting;
  final VoidCallback onAddRow;
  final ValueChanged<int> onRemoveRow;
  final VoidCallback onQuickPaste;

  const BulkStudentsProvisionEditor({
    super.key,
    required this.bulkRows,
    required this.isSubmitting,
    required this.onAddRow,
    required this.onRemoveRow,
    required this.onQuickPaste,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'قائمة المتدربين (${bulkRows.length})',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton.icon(
              onPressed: isSubmitting ? null : onQuickPaste,
              icon: const Icon(PhosphorIconsRegular.clipboardText, size: 17),
              label: const Text(
                'لصق قائمة دفعة واحدة',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (int i = 0; i < bulkRows.length; i++) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderHairline),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentCobaltLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'متدرب ${i + 1}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (bulkRows.length > 1)
                      IconButton(
                        tooltip: 'حذف السطر',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          PhosphorIconsRegular.trash,
                          size: 17,
                          color: AppColors.error,
                        ),
                        onPressed: () => onRemoveRow(i),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bulkRows[i].name,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل *',
                    isDense: true,
                    prefixIcon: Icon(PhosphorIconsRegular.user, size: 18),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: bulkRows[i].email,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني *',
                          isDense: true,
                          prefixIcon: Icon(
                            PhosphorIconsRegular.envelopeSimple,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: TextField(
                        controller: bulkRows[i].password,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        decoration: const InputDecoration(
                          labelText: 'كلمة المرور *',
                          isDense: true,
                          prefixIcon: Icon(PhosphorIconsRegular.key, size: 17),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: isSubmitting ? null : onAddRow,
          icon: const Icon(PhosphorIconsRegular.plus, size: 17),
          label: const Text('إضافة متدرب آخر للقائمة'),
        ),
      ],
    );
  }
}

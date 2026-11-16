import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_lottie_box.dart';
import '../../../models/course.dart';
import '../../../services/student_provisioning_service.dart';

/// نافذة ملخص الحسابات التي تم تجهيزها مع نسخ فوري لبيانات الدخول لإرسالها للطلاب.
class ProvisionedCredentialsDialog extends StatelessWidget {
  final List<ProvisionStudentOutcome> outcomes;
  final List<Course> unlockedCourses;

  const ProvisionedCredentialsDialog({
    super.key,
    required this.outcomes,
    required this.unlockedCourses,
  });

  static Future<void> show(
    BuildContext context, {
    required List<ProvisionStudentOutcome> outcomes,
    required List<Course> unlockedCourses,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ProvisionedCredentialsDialog(
        outcomes: outcomes,
        unlockedCourses: unlockedCourses,
      ),
    );
  }

  String _formatShareableSummary() {
    final buffer = StringBuffer();
    buffer.writeln('بيانات الدخول لمنصة مركز الأمين للتخاطب:');
    if (unlockedCourses.isNotEmpty) {
      buffer.writeln(
        'الدورات المفعلة: ${unlockedCourses.map((c) => c.title).join("، ")}',
      );
    }
    buffer.writeln('────────────────────────');
    for (final item in outcomes.where((o) => o.succeeded)) {
      buffer.writeln('الاسم: ${item.name}');
      buffer.writeln('البريد الإلكتروني: ${item.email}');
      if (item.createdNewAccount) {
        buffer.writeln('كلمة المرور: ${item.password}');
      }
      buffer.writeln('────────────────────────');
    }
    return buffer.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final successCount = outcomes.where((o) => o.succeeded).length;
    final failedCount = outcomes.length - successCount;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: AppLottieBox(
                  assetPath: 'assets/lottie/success_pulse.json',
                  size: 76,
                  repeat: false,
                  fallbackIcon: PhosphorIconsFill.checkCircle,
                  fallbackColor: AppColors.success,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                failedCount == 0
                    ? 'تم تجهيز وتفعيل حسابات المتدربين بنجاح ($successCount)'
                    : 'اكتمل تجهيز $successCount من أصل ${outcomes.length} حساب',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (unlockedCourses.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'الكورسات الممنوحة: ${unlockedCourses.map((c) => c.title).join(" • ")}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: outcomes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = outcomes[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: item.succeeded
                            ? AppColors.surfaceLevel0
                            : AppColors.errorLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: item.succeeded
                              ? AppColors.borderHairline
                              : AppColors.errorBorder,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            item.succeeded
                                ? PhosphorIconsFill.checkCircle
                                : PhosphorIconsFill.warningCircle,
                            size: 19,
                            color: item.succeeded
                                ? AppColors.success
                                : AppColors.error,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                SelectableText(
                                  item.createdNewAccount
                                      ? '${item.email}  •  كلمة المرور: ${item.password}'
                                      : item.email,
                                  textDirection: TextDirection.ltr,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                if (item.message != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    item.message!,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: item.succeeded
                                          ? AppColors.successDark
                                          : AppColors.errorDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (item.succeeded)
                            IconButton(
                              tooltip: 'نسخ بيانات هذا المتدرب',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                PhosphorIconsRegular.copy,
                                size: 17,
                              ),
                              onPressed: () {
                                final text =
                                    'الاسم: ${item.name}\nالبريد: ${item.email}\nكلمة المرور: ${item.password}';
                                Clipboard.setData(ClipboardData(text: text));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'تم نسخ بيانات دخول ${item.name}',
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (successCount > 0) ...[
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: _formatShareableSummary()),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'تم نسخ جميع بيانات الدخول جاهزة للإرسال',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(PhosphorIconsRegular.copy, size: 18),
                        label: const Text('نسخ كل البيانات'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('إغلاق'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


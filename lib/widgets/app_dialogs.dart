import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/app_validators.dart';

class AppDialogs {
  AppDialogs._();

  /// عرض نافذة نجاح واضحة ومتجاوبة.
  static Future<void> showSuccess(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'حسناً',
    VoidCallback? onOk,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _BaseAppDialog(
        icon: Icons.check_circle_rounded,
        iconColor: AppColors.success,
        iconBgColor: AppColors.successLight,
        title: title,
        message: message,
        primaryButtonText: buttonText,
        onPrimaryPressed: () {
          Navigator.of(ctx).pop();
          onOk?.call();
        },
      ),
    );
  }

  /// عرض نافذة تنبيه أو خطأ واضحة.
  static Future<void> showError(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'إغلاق',
    VoidCallback? onOk,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => _BaseAppDialog(
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.error,
        iconBgColor: AppColors.errorLight,
        title: title,
        message: message,
        primaryButtonText: buttonText,
        onPrimaryPressed: () {
          Navigator.of(ctx).pop();
          onOk?.call();
        },
      ),
    );
  }

  /// نافذة تأكيد بزرين (تأكيد / إلغاء).
  static Future<bool> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'تأكيد',
    String cancelText = 'تراجع',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _BaseAppDialog(
        icon: isDestructive
            ? Icons.warning_amber_rounded
            : Icons.help_outline_rounded,
        iconColor: isDestructive ? AppColors.warning : AppColors.primary,
        iconBgColor:
            isDestructive ? AppColors.warningLight : AppColors.primaryLight,
        title: title,
        message: message,
        primaryButtonText: confirmText,
        secondaryButtonText: cancelText,
        isDestructive: isDestructive,
        onPrimaryPressed: () => Navigator.of(ctx).pop(true),
        onSecondaryPressed: () => Navigator.of(ctx).pop(false),
      ),
    );
    return result ?? false;
  }

  /// نافذة استعادة كلمة المرور مع إدارة سليمة لدورة حياة الـ Controller.
  static Future<void> showForgotPassword(
    BuildContext context, {
    required Future<void> Function(String email) onSend,
  }) {
    return showDialog(
      context: context,
      builder: (_) => _ForgotPasswordDialog(onSend: onSend),
    );
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  final Future<void> Function(String email) onSend;

  const _ForgotPasswordDialog({required this.onSend});

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await widget.onSend(_emailController.text.trim());
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppDialogs.showError(
          context,
          title: 'تعذر إرسال الرابط',
          message: e.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderHairline),
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    color: AppColors.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'استعادة كلمة المرور',
                  style: AppTextStyles.heading2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'أدخل بريدك الإلكتروني المسجل في مركز الأمين وسنرسل لك رابطاً لإعادة تعيين كلمة المرور.',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    hintText: 'name@example.com',
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: AppColors.scaffoldBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.borderHairline,
                      ),
                    ),
                  ),
                  validator: AppValidators.validateEmail,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('إرسال الرابط'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BaseAppDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String message;
  final String primaryButtonText;
  final String? secondaryButtonText;
  final bool isDestructive;
  final VoidCallback onPrimaryPressed;
  final VoidCallback? onSecondaryPressed;

  const _BaseAppDialog({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.message,
    required this.primaryButtonText,
    this.secondaryButtonText,
    this.isDestructive = false,
    required this.onPrimaryPressed,
    this.onSecondaryPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Icon(icon, color: iconColor, size: 32),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: AppTextStyles.heading2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              if (secondaryButtonText != null)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onSecondaryPressed,
                        child: Text(secondaryButtonText!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: isDestructive
                              ? AppColors.error
                              : AppColors.primary,
                        ),
                        onPressed: onPrimaryPressed,
                        child: Text(primaryButtonText),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onPrimaryPressed,
                    child: Text(primaryButtonText),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

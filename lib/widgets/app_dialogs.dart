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

  /// نافذة استعادة كلمة المرور عبر رمز OTP مع إدارة سليمة لدورة حياة الـ Controller.
  static Future<void> showForgotPassword(
    BuildContext context, {
    required Future<void> Function(String email) onSend,
    Future<void> Function(String email, String otp, String password, String confirmPassword)? onReset,
  }) {
    return showDialog(
      context: context,
      builder: (_) => _ForgotPasswordDialog(onSend: onSend, onReset: onReset),
    );
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  final Future<void> Function(String email) onSend;
  final Future<void> Function(String email, String otp, String password, String confirmPassword)? onReset;

  const _ForgotPasswordDialog({
    required this.onSend,
    this.onReset,
  });

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int _step = 1; // 1 = إرسال رمز OTP، 2 = إدخال OTP وكلمة المرور الجديدة
  bool _isLoading = false;
  bool _isPasswordObscured = true;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitStep1() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await widget.onSend(_emailController.text.trim());
      if (mounted) {
        if (widget.onReset != null) {
          setState(() {
            _isLoading = false;
            _step = 2;
          });
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppDialogs.showError(
          context,
          title: 'تعذر إرسال الرمز',
          message: e.toString(),
        );
      }
    }
  }

  Future<void> _submitStep2() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      AppDialogs.showError(
        context,
        title: 'خطأ',
        message: 'كلمتا المرور غير متطابقتين.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await widget.onReset!(
        _emailController.text.trim(),
        _otpController.text.trim(),
        _passwordController.text,
        _confirmPasswordController.text,
      );
      if (mounted) {
        Navigator.of(context).pop();
        AppDialogs.showSuccess(
          context,
          title: 'تم بنجاح',
          message: 'تمت إعادة تعيين كلمة المرور بنجاح. يمكنك الآن تسجيل الدخول.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppDialogs.showError(
          context,
          title: 'فشل تعيين كلمة المرور',
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
                  _step == 1 ? 'استعادة كلمة المرور' : 'إعادة تعيين كلمة المرور',
                  style: AppTextStyles.heading2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _step == 1
                      ? 'أدخل بريدك الإلكتروني المسجل في مركز الأمين وسنرسل لك رمز OTP للتحقق.'
                      : 'أدخل رمز التحقق (OTP) المكون من 6 أرقام المرسل إلى بريدك، ثم اكتب كلمة المرور الجديدة.',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                if (_step == 1) ...[
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
                ] else ...[
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    decoration: InputDecoration(
                      hintText: 'رمز التحقق (6 أرقام)',
                      counterText: '',
                      prefixIcon: const Icon(
                        Icons.pin_outlined,
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
                    validator: (v) {
                      if (v == null || v.trim().length < 4) {
                        return 'يرجى إدخال رمز التحقق بشكل صحيح.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _isPasswordObscured,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      hintText: 'كلمة المرور الجديدة',
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
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
                    validator: (v) {
                      if (v == null || v.length < 6) {
                        return 'كلمة المرور يجب ألا تقل عن 6 أحرف.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _isPasswordObscured,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      hintText: 'تأكيد كلمة المرور الجديدة',
                      prefixIcon: const Icon(
                        Icons.verified_user_outlined,
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
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'يرجى تأكيد كلمة المرور.';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isLoading ? null : (_step == 1 ? _submitStep1 : _submitStep2),
                        child: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_step == 1 ? 'إرسال الرمز' : 'تأكيد التغيير'),
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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_password_field.dart';
import '../../../../logic/auth/auth_cubit.dart';
import '../../../../logic/auth/auth_state.dart';
import '../../../../repositories/student_profile_repository.dart';

class ChangePasswordSheet extends StatefulWidget {
  final StudentProfileRepository? repository;
  final bool isGoogleAccount;

  const ChangePasswordSheet({
    super.key,
    this.repository,
    this.isGoogleAccount = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    StudentProfileRepository? repository,
    bool? isGoogleAccount,
  }) {
    bool resolvedGoogle = isGoogleAccount ?? false;
    if (isGoogleAccount == null) {
      final auth = context.read<AuthCubit>().state;
      if (auth is Authenticated) {
        final photo = auth.user.photoUrl.toLowerCase();
        resolvedGoogle = photo.contains('googleusercontent.com') ||
            photo.contains('google') ||
            auth.user.email.endsWith('@gmail.com');
      }
    }

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ChangePasswordSheet(
          repository: repository,
          isGoogleAccount: resolvedGoogle,
        ),
      ),
    );
  }

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  late final StudentProfileRepository _repository;
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (!widget.isGoogleAccount) {
      _repository = widget.repository ?? sl<StudentProfileRepository>();
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitChangePassword() async {
    if (widget.isGoogleAccount) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _repository.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
        newPasswordConfirmation: _confirmPasswordController.text,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث كلمة المرور بنجاح'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'تعذر تحديث كلمة المرور: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGoogleAccount) {
      return _buildGoogleAccountNotice();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    PhosphorIconsRegular.lockKey,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تغيير كلمة المرور',
                        style: AppTextStyles.heading3.copyWith(fontSize: 17),
                      ),
                      Text(
                        'أدخل كلمة المرور الحالية ثم اختر كلمة مرور جديدة قوية.',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(PhosphorIconsRegular.warningCircle, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTextStyles.caption.copyWith(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // كلمة المرور الحالية
            AppPasswordField(
              label: 'كلمة المرور الحالية',
              hintText: 'أدخل كلمة المرور الحالية',
              controller: _currentPasswordController,
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'يرجى إدخال كلمة المرور الحالية';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // كلمة المرور الجديدة
            AppPasswordField(
              label: 'كلمة المرور الجديدة',
              hintText: '8 أحرف على الأقل',
              controller: _newPasswordController,
              validator: (val) {
                if (val == null || val.length < 8) {
                  return 'يجب أن لا تقل كلمة المرور عن 8 أحرف';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // تأكيد كلمة المرور الجديدة
            AppPasswordField(
              label: 'تأكيد كلمة المرور الجديدة',
              hintText: 'أعد إدخال كلمة المرور الجديدة',
              controller: _confirmPasswordController,
              validator: (val) {
                if (val != _newPasswordController.text) {
                  return 'كلمتا المرور غير متطابقتين';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // زر الحفظ
            AppButton(
              text: 'حفظ كلمة المرور الجديدة',
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submitChangePassword,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleAccountNotice() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              PhosphorIconsRegular.shieldCheck,
              size: 36,
              color: Color(0xFF0369A1),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'حسابك موثق عبر Google',
            style: AppTextStyles.heading3.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'حسابك مسجل عبر تسجيل دخول Google الموحد ولا يتطلب كلمة مرور محلية في مركز الأمين.\nيمكنك إدارة أمان حسابك وكلمة المرور مباشرة عبر إعدادات حساب Google الخاص بك.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            text: 'فهمت ذلك',
            variant: AppButtonVariant.primary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

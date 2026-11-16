import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/utils/network_error_mapper.dart';
import '../../../../logic/auth/auth_cubit.dart';

/// نافذة سفلية لتحديث بيانات المتدرب الشخصية وإرسال رابط تغيير كلمة المرور بأمان.
class EditStudentProfileSheet extends StatefulWidget {
  final String initialName;
  final String initialPhone;
  final String email;

  const EditStudentProfileSheet({
    super.key,
    required this.initialName,
    required this.initialPhone,
    required this.email,
  });

  static Future<void> show(
    BuildContext context, {
    required String initialName,
    required String initialPhone,
    required String email,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<AuthCubit>(),
        child: EditStudentProfileSheet(
          initialName: initialName,
          initialPhone: initialPhone,
          email: email,
        ),
      ),
    );
  }

  @override
  State<EditStudentProfileSheet> createState() =>
      _EditStudentProfileSheetState();
}

class _EditStudentProfileSheetState extends State<EditStudentProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  bool _isSaving = false;
  bool _isSendingReset = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      final normalizedPhone = AppValidators.cleanEgyptianPhone(_phoneController.text);
      await context.read<AuthCubit>().updateProfileInfo(
            displayName: widget.initialName,
            phone: normalizedPhone,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث بيانات ملفك التدريبي بنجاح.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      final msg = NetworkErrorMapper.toArabicMessage(
        e,
        defaultMessage: 'تعذر حفظ التعديلات حالياً، يرجى المحاولة مرة أخرى.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _sendPasswordReset() async {
    if (widget.email.trim().isEmpty) return;
    setState(() => _isSendingReset = true);
    try {
      await context.read<AuthCubit>().sendPasswordReset(widget.email.trim());
      if (!mounted) return;
      setState(() => _isSendingReset = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إرسال رابط تغيير كلمة المرور إلى ${widget.email.trim()}',
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingReset = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.borderHairline,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            PhosphorIconsRegular.userGear,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'إعدادات الحساب الشخصي',
                                style: AppTextStyles.heading3.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'تحديث الاسم ورقم التواصل أو استعادة كلمة المرور',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(PhosphorIconsRegular.x, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Text('الاسم الثلاثي المعتمد', style: AppTextStyles.label),
                        const SizedBox(width: 6),
                        const Icon(
                          PhosphorIconsRegular.lockSimple,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      readOnly: true,
                      enabled: false,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surfaceLevel2,
                        prefixIcon: const Icon(PhosphorIconsRegular.user, size: 19),
                        suffixIcon: const Tooltip(
                          message: 'الاسم مقفل للاعتماد بالشهادات',
                          child: Icon(PhosphorIconsRegular.lockKey, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            PhosphorIconsRegular.info,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'الاسم المعتمد في الشهادات والبطاقات لا يمكن تغييره. في حال وجود خطأ يرجى التواصل مع الدعم الفني.',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('رقم الهاتف / واتساب', style: AppTextStyles.label),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null; // optional on profile update if not modifying
                        return AppValidators.validateEgyptianPhone(v, 'رقم الهاتف');
                      },
                      decoration: const InputDecoration(
                        hintText: '01XXXXXXXXX',
                        prefixIcon: Icon(PhosphorIconsRegular.phone, size: 19),
                      ),
                    ),
                    if (widget.email.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.scaffoldBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.borderHairline),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              PhosphorIconsRegular.lockKey,
                              color: AppColors.textSecondary,
                              size: 19,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'تغيير كلمة المرور',
                                    style: AppTextStyles.label.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'إرسال رابط آمن إلى ${widget.email}',
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  _isSendingReset ? null : _sendPasswordReset,
                              child: _isSendingReset
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('إرسال الرابط'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveProfile,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                PhosphorIconsRegular.checkCircle,
                                size: 19,
                              ),
                        label: Text(
                          _isSaving ? 'جارٍ الحفظ...' : 'حفظ التعديلات',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/utils/app_validators.dart';
import '../../../services/student_provisioning_service.dart';

/// نموذج بيانات المتدرب الفردي لتسجيله وتوليد بيانات دخوله.
class SingleStudentProvisionForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController phoneController;

  const SingleStudentProvisionForm({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.phoneController,
  });

  @override
  State<SingleStudentProvisionForm> createState() =>
      _SingleStudentProvisionFormState();
}

class _SingleStudentProvisionFormState
    extends State<SingleStudentProvisionForm> {
  bool _obscurePassword = false;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: widget.nameController,
            decoration: const InputDecoration(
              labelText: 'الاسم الكامل للمتدرب *',
              hintText: 'مثال: د. مريم طارق',
              prefixIcon: Icon(PhosphorIconsRegular.user, size: 19),
            ),
            validator: (v) => AppValidators.validateRequired(v, 'اسم المتدرب'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: widget.emailController,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            decoration: const InputDecoration(
              labelText: 'البريد الإلكتروني للحساب *',
              hintText: 'student@example.com',
              prefixIcon: Icon(PhosphorIconsRegular.envelopeSimple, size: 19),
            ),
            validator: AppValidators.validateEmail,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: widget.passwordController,
                  obscureText: _obscurePassword,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور (6 أحرف فأكثر) *',
                    prefixIcon: const Icon(PhosphorIconsRegular.key, size: 19),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword ? 'إظهار' : 'إخفاء',
                      icon: Icon(
                        _obscurePassword
                            ? PhosphorIconsRegular.eye
                            : PhosphorIconsRegular.eyeSlash,
                        size: 18,
                      ),
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                    ),
                  ),
                  validator: AppValidators.validatePassword,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      widget.passwordController.text =
                          StudentProvisioningService.generateStrongPassword();
                    });
                  },
                  icon:
                      const Icon(PhosphorIconsRegular.arrowsClockwise, size: 16),
                  label: const Text('توليد'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: widget.phoneController,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف أو واتساب (اختياري)',
              hintText: '010XXXXXXXX',
              prefixIcon: Icon(PhosphorIconsRegular.phone, size: 19),
            ),
            validator: (v) => (v != null && v.trim().isNotEmpty)
                ? AppValidators.validateEgyptianPhone(v)
                : null,
          ),
        ],
      ),
    );
  }
}

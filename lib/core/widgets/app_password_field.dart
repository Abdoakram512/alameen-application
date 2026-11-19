import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';
import 'app_text_field.dart';

class AppPasswordField extends StatefulWidget {
  final String? label;
  final String? hintText;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;

  const AppPasswordField({
    super.key,
    this.label = 'كلمة المرور',
    this.hintText = 'أدخل كلمة المرور',
    this.controller,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.enabled = true,
  });

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      hintText: widget.hintText,
      controller: widget.controller,
      validator: widget.validator,
      obscureText: _obscureText,
      enabled: widget.enabled,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      prefixIcon: const Icon(PhosphorIconsRegular.lock, color: AppColors.textMuted, size: 20),
      suffixIcon: IconButton(
        icon: Icon(
          _obscureText ? PhosphorIconsRegular.eyeSlash : PhosphorIconsRegular.eye,
          color: AppColors.textMuted,
          size: 20,
        ),
        onPressed: () => setState(() => _obscureText = !_obscureText),
      ),
    );
  }
}

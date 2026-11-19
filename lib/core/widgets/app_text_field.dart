import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AppTextField extends StatelessWidget {
  final String? label;
  final String? hintText;
  final TextEditingController? controller;
  final String? initialValue;
  final FormFieldValidator<String>? validator;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final int maxLines;
  final int? minLines;
  final bool readOnly;
  final bool enabled;
  final TextDirection? textDirection;
  final FocusNode? focusNode;

  const AppTextField({
    super.key,
    this.label,
    this.hintText,
    this.controller,
    this.initialValue,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onFieldSubmitted,
    this.maxLines = 1,
    this.minLines,
    this.readOnly = false,
    this.enabled = true,
    this.textDirection,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null && label!.isNotEmpty) ...[
          Text(
            label!,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          validator: validator,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          maxLines: maxLines,
          minLines: minLines,
          readOnly: readOnly,
          enabled: enabled,
          textDirection: textDirection,
          focusNode: focusNode,
          style: AppTextStyles.bodyLarge.copyWith(
            color: enabled ? AppColors.textPrimary : AppColors.textMuted,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
            filled: true,
            fillColor: enabled ? const Color(0xFFF9FAFB) : const Color(0xFFF3F4F6),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderHairline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderHairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

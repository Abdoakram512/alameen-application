import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_validators.dart';
import '../../logic/auth/auth_cubit.dart';
import '../../logic/auth/auth_state.dart';
import '../../navigation/student_route_policy.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/language_switch_button.dart';
import 'widgets/auth_brand_header.dart';
import 'widgets/auth_labeled_text_field.dart';
import 'widgets/auth_side_showcase_panel.dart';
import 'widgets/auth_switch_prompt_card.dart';
import 'widgets/google_sign_in_button.dart';

class StudentRegisterScreen extends StatefulWidget {
  const StudentRegisterScreen({super.key});

  @override
  State<StudentRegisterScreen> createState() => _StudentRegisterScreenState();
}

class _StudentRegisterScreenState extends State<StudentRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitRegister() {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      AppDialogs.showError(
        context,
        title: 'dialogs.error_title'.tr(),
        message: 'validation.passwords_mismatch'.tr(),
      );
      return;
    }

    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();

    context.read<AuthCubit>().signUpWithEmailAndPassword(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          phone: AppValidators.cleanEgyptianPhone(_phoneController.text),
        );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = context.screenWidth >= 920 && context.screenHeight >= 560;

    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          AppDialogs.showError(
            context,
            title: 'dialogs.error_title'.tr(),
            message: state.message,
          );
        } else if (state is AuthPendingApproval) {
          AppDialogs.showSuccess(
            context,
            title: 'طلب التسجيل قيد المراجعة',
            message: state.message,
            buttonText: 'تسجيل الدخول',
            onOk: () {
              context.go('/login');
            },
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        final returnFrom = GoRouterState.of(context).uri.queryParameters['from'];

        final formCard = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: const LanguageSwitchButton(compact: true),
            ),
            const SizedBox(height: 12),
            if (!isWide) ...[
              AuthBrandHeader(
                title: 'auth.register_title'.tr(),
                subtitle: 'auth.register_subtitle'.tr(),
                compact: true,
              ),
              const SizedBox(height: 18),
            ],
            Container(
              padding: EdgeInsets.all(context.isCompactPhone ? 18 : 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderHairline),
                boxShadow: AppColors.cardShadow,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isWide) ...[
                      Text('auth.register_title'.tr(), style: AppTextStyles.heading1),
                      const SizedBox(height: 4),
                      Text(
                        'auth.register_subtitle'.tr(),
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: 18),
                    ],
                    AuthLabeledTextField(
                      label: 'auth.full_name'.tr(),
                      hintText: 'auth.full_name_hint'.tr(),
                      controller: _nameController,
                      prefixIcon: Icons.person_outline_rounded,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().length < 3) {
                          return 'validation.name_required'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    AuthLabeledTextField(
                      label: 'auth.email'.tr(),
                      hintText: 'auth.email_hint'.tr(),
                      controller: _emailController,
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'validation.email_required'.tr();
                        }
                        if (!v.contains('@') || !v.contains('.')) {
                          return 'validation.email_invalid'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    AuthLabeledTextField(
                      label: 'auth.phone'.tr(),
                      hintText: 'auth.phone_hint'.tr(),
                      controller: _phoneController,
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'validation.phone_required'.tr();
                        }
                        return AppValidators.validateEgyptianPhone(v, 'رقم الهاتف');
                      },
                    ),
                    const SizedBox(height: 14),
                    AuthLabeledTextField(
                      label: 'auth.password'.tr(),
                      hintText: 'auth.password_hint'.tr(),
                      controller: _passwordController,
                      prefixIcon: Icons.lock_outline_rounded,
                      textDirection: TextDirection.ltr,
                      obscureText: _isPasswordObscured,
                      onToggleObscure: () => setState(
                        () => _isPasswordObscured = !_isPasswordObscured,
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.length < 6) {
                          return 'validation.password_min_length'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    AuthLabeledTextField(
                      label: 'auth.confirm_password'.tr(),
                      hintText: 'auth.password_hint'.tr(),
                      controller: _confirmPasswordController,
                      prefixIcon: Icons.verified_user_outlined,
                      textDirection: TextDirection.ltr,
                      obscureText: _isConfirmPasswordObscured,
                      onToggleObscure: () => setState(
                        () => _isConfirmPasswordObscured =
                            !_isConfirmPasswordObscured,
                      ),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submitRegister(),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'validation.confirm_password_required'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: isLoading ? null : _submitRegister,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.4,
                                ),
                              )
                            : Text(
                                'auth.register_btn'.tr(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'auth.or_continue_with'.tr(),
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                    ),
                    GoogleSignInButton(
                      isLoading: isLoading,
                      onPressed: () =>
                          context.read<AuthCubit>().signInWithGoogle(),
                      label: 'auth.google_login_btn'.tr(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            AuthSwitchPromptCard(
              promptText: 'auth.already_have_account'.tr(),
              actionText: 'auth.login_btn'.tr(),
              onPressed: isLoading
                  ? null
                  : () => context.go(
                        studentAuthLocation('/login', returnFrom),
                      ),
            ),
          ],
        );

        return Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: context.horizontalPagePadding,
                  vertical: 20,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isWide ? 1000 : 480),
                  child: isWide
                      ? IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Expanded(
                                flex: 5,
                                child: AuthSideShowcasePanel(),
                              ),
                              const SizedBox(width: 28),
                              Expanded(flex: 5, child: formCard),
                            ],
                          ),
                        )
                      : formCard,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

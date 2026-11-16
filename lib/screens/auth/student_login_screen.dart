import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
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

class StudentLoginScreen extends StatefulWidget {
  const StudentLoginScreen({super.key});

  @override
  State<StudentLoginScreen> createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends State<StudentLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordObscured = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitEmailLogin() {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    context.read<AuthCubit>().signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = context.screenWidth >= 900 && context.screenHeight >= 540;

    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          AppDialogs.showError(
            context,
            title: 'dialogs.error_title'.tr(),
            message: state.message,
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
                subtitle: 'auth.login_title'.tr(),
              ),
              const SizedBox(height: 22),
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
                      Text('auth.login_title'.tr(), style: AppTextStyles.heading1),
                      const SizedBox(height: 4),
                      Text(
                        'auth.register_subtitle'.tr(),
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                    ],
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
                    const SizedBox(height: 16),
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
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submitEmailLogin(),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'validation.password_required'.tr();
                        }
                        if (v.length < 6) {
                          return 'validation.password_min_length'.tr();
                        }
                        return null;
                      },
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                AppDialogs.showForgotPassword(
                                  context,
                                  onSend: (email) async {
                                    await context
                                        .read<AuthCubit>()
                                        .sendPasswordReset(email);
                                    if (context.mounted) {
                                      AppDialogs.showSuccess(
                                        context,
                                        title: 'dialogs.reset_link_sent_title'.tr(),
                                        message: 'dialogs.reset_link_sent_desc'.tr(),
                                      );
                                    }
                                  },
                                );
                              },
                        child: Text(
                          'auth.forgot_password'.tr(),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: isLoading ? null : _submitEmailLogin,
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
                                'auth.login_btn'.tr(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'auth.or_continue_with'.tr(),
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12.5,
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
                      label: 'auth.google_login_btn'.tr(),
                      onPressed: () =>
                          context.read<AuthCubit>().signInWithGoogle(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            AuthSwitchPromptCard(
              promptText: 'auth.new_student'.tr(),
              actionText: 'auth.create_account'.tr(),
              onPressed: isLoading
                  ? null
                  : () => context.go(
                        studentAuthLocation('/register', returnFrom),
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
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isWide ? 980 : 460),
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

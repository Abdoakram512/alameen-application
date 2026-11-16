import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../logic/auth/admin_auth_cubit.dart';
import '../../logic/auth/admin_auth_state.dart';
import '../../widgets/language_switch_button.dart';
import 'widgets/login_features_card.dart';
import 'widgets/login_form_card.dart';
import 'widgets/login_header.dart';
import 'widgets/login_security_footer.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    // عدم تعبئة البريد الإداري مسبقاً لمنع كشف هوية حساب المشرف على الواجهة.
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      context.read<AdminAuthCubit>().signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminAuthCubit, AdminAuthState>(
      listener: (context, state) {
        if (state is AdminAuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state.message,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AdminAuthLoading;

        return Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWideLayout = constraints.maxWidth >= 920;

                final formSection = Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Align(
                        alignment: AlignmentDirectional.topEnd,
                        child: AdminLanguageSwitchButton(compact: true),
                      ),
                      const SizedBox(height: 12),
                      LoginHeader(compact: isWideLayout),
                      const SizedBox(height: 24),
                      LoginFormCard(
                        formKey: _formKey,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        isLoading: isLoading,
                        onSubmit: _submitLogin,
                      ),
                      const SizedBox(height: 18),
                      const LoginSecurityFooter(),
                    ],
                  ),
                );

                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.horizontalPagePadding,
                      vertical: 24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isWideLayout ? 1020 : 460,
                      ),
                      child: isWideLayout
                          ? IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Expanded(
                                    flex: 5,
                                    child: LoginFeaturesCard(),
                                  ),
                                  const SizedBox(width: 28),
                                  Expanded(
                                    flex: 5,
                                    child: Center(child: formSection),
                                  ),
                                ],
                              ),
                            )
                          : formSection,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

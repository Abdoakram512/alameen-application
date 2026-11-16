import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../logic/auth/auth_cubit.dart';
import '../../logic/auth/auth_state.dart';

class SuspendedAccountScreen extends StatelessWidget {
  const SuspendedAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final user = authState is Authenticated ? authState.user : null;
    final studentId = user?.uid ?? '';
    final reason = user?.suspensionReason?.trim();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          AppConstants.appName,
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Suspended Animated Lottie Badge with graceful fallback
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: Lottie.asset(
                      'assets/lottie/account_suspended.json',
                      repeat: true,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppColors.errorLight,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.errorBorder,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          PhosphorIconsRegular.prohibit,
                          size: 46,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Heading
                  Text(
                    'تم تعليق هذا الحساب',
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: AppColors.errorDark,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),

                  Text(
                    'تم إيقاف تفعيل حسابك على منصة مركز الأمين للتخاطب من قبل إدارة المركز.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Suspension Reason Box if provided
                  if (reason != null && reason.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.errorBorder),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                PhosphorIconsRegular.warningCircle,
                                size: 18,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'سبب التعليق الإداري:',
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.errorDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            reason,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Student reference code card
                  if (studentId.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderHairline),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            PhosphorIconsRegular.identificationCard,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'كود الطالب: $studentId',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              PhosphorIconsRegular.copy,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            tooltip: 'نسخ الكود',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: studentId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم نسخ كود الطالب'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // WhatsApp Contact Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(PhosphorIconsRegular.whatsappLogo, size: 22),
                      label: const Text(
                        'تواصل مع الإدارة عبر واتساب',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        AppConstants.launchWhatsApp(
                          customMessage:
                              'السلام عليكم، أود الاستفسار بخصوص تعليق حسابي في منصة مركز الأمين للتخاطب.\nكود الطالب: $studentId\nالاسم: ${user?.displayName ?? ''}',
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Direct Call Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(PhosphorIconsRegular.phoneCall, size: 20),
                      label: Text(
                        'اتصال هاتفي (${AppConstants.supportPhone})',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () => AppConstants.launchPhoneCall(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sign out button
                  TextButton.icon(
                    onPressed: () => context.read<AuthCubit>().signOut(),
                    icon: const Icon(PhosphorIconsRegular.signOut, size: 18),
                    label: const Text(
                      'تسجيل الخروج والتبديل لحساب آخر',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

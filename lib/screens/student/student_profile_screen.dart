import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_directional_icons.dart';
import '../../logic/access/access_cubit.dart';
import '../../logic/auth/auth_cubit.dart';
import '../../logic/auth/auth_state.dart';
import '../../logic/courses/courses_cubit.dart';
import '../../logic/courses/courses_state.dart';
import '../../models/course.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/language_switch_button.dart';
import '../onboarding/onboarding_screen.dart';
import 'profile/widgets/edit_student_profile_sheet.dart';
import 'profile/widgets/enrolled_courses_section.dart';
import 'profile/widgets/student_profile_header_card.dart';
import 'profile/widgets/student_requests_status_section.dart';

class StudentProfileScreen extends StatelessWidget {
  final VoidCallback? onBrowseCourses;

  const StudentProfileScreen({super.key, this.onBrowseCourses});

  Future<void> _handleSignOut(BuildContext context) async {
    final confirm = await AppDialogs.showConfirm(
      context,
      title: 'تسجيل الخروج',
      message: 'هل أنت متأكد من تسجيل الخروج من حسابك في مركز الأمين للتخاطب؟',
      confirmText: 'تسجيل الخروج',
      cancelText: 'إلغاء',
      isDestructive: true,
    );
    if (confirm && context.mounted) {
      context.read<AccessCubit>().clear();
      await context.read<AuthCubit>().signOut();
    }
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(PhosphorIconsRegular.warningOctagon, color: AppColors.error),
              SizedBox(width: 8),
              Text('حذف الحساب نهائياً', style: TextStyle(color: AppColors.error)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تحذير شديد: حذف الحساب سيؤدي إلى مسح جميع بياناتك وسجلات تقدمك وتسليماتك نهائياً من سنتر الأمين ولا يمكن التراجع عن ذلك.\n\nلتأكيد الحذف الأمني، يرجى كتابة كلمة المرور الحالية:',
                style: TextStyle(height: 1.5, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور الحالية',
                  prefixIcon: const Icon(PhosphorIconsRegular.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword
                          ? PhosphorIconsRegular.eyeSlash
                          : PhosphorIconsRegular.eye,
                    ),
                    onPressed: () => setDialogState(
                      () => obscurePassword = !obscurePassword,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد الحذف النهائي'),
            ),
          ],
        ),
      ),
    );

    final enteredPassword = passwordController.text.trim();
    passwordController.dispose();

    if (confirm == true && context.mounted) {
      context.read<AccessCubit>().clear();
      await context.read<AuthCubit>().deleteAccount(password: enteredPassword);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final currentUser = authState is Authenticated ? authState.user : null;
        final displayName = currentUser?.displayName.trim().isNotEmpty == true
            ? currentUser!.displayName
            : 'متدرب مركز الأمين';
        final displayEmail = currentUser?.email.trim().isNotEmpty == true
            ? currentUser!.email
            : '';
        final displayPhone = currentUser?.phone ?? '';
        final avatarUrl = currentUser?.photoUrl ?? '';

        return BlocBuilder<CoursesCubit, CoursesState>(
          builder: (context, coursesState) {
            final enrolledCourses = <Course>[];
            if (coursesState is CoursesLoaded && currentUser != null) {
              enrolledCourses.addAll(
                coursesState.allCourses.where(
                  (c) => c.isDetailedFromAuthServer
                      ? c.hasEnrolled
                      : (c.hasEnrolled || currentUser.isEnrolled(c.id)),
                ),
              );
            }

            return Scaffold(
              backgroundColor: AppColors.scaffoldBackground,
              appBar: AppBar(
                title: Text('profile.title'.tr()),
                actions: [
                  const LanguageSwitchButton(compact: true),
                  const SizedBox(width: 4),
                  if (currentUser != null)
                    IconButton(
                      tooltip: 'profile.app_settings'.tr(),
                      icon: const Icon(
                        PhosphorIconsRegular.slidersHorizontal,
                        size: 21,
                      ),
                      onPressed: () {
                        EditStudentProfileSheet.show(
                          context,
                          initialName: displayName,
                          initialPhone: displayPhone,
                          email: displayEmail,
                        );
                      },
                    ),
                  IconButton(
                    tooltip: 'auth.sign_out'.tr(),
                    icon: const Icon(
                      PhosphorIconsRegular.signOut,
                      color: AppColors.error,
                      size: 21,
                    ),
                    onPressed: () => _handleSignOut(context),
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: [
                  ResponsiveCenter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StudentProfileHeaderCard(
                          displayName: displayName,
                          email: displayEmail,
                          phone: displayPhone,
                          avatarUrl: avatarUrl,
                          onEditTap: currentUser == null
                              ? null
                              : () {
                                  EditStudentProfileSheet.show(
                                    context,
                                    initialName: displayName,
                                    initialPhone: displayPhone,
                                    email: displayEmail,
                                  );
                                },
                        ),
                        const SizedBox(height: 20),
                        EnrolledCoursesSection(
                          enrolledCourses: enrolledCourses,
                          currentUser: currentUser,
                          onBrowseCourses: onBrowseCourses,
                        ),
                        const SizedBox(height: 20),
                        const StudentRequestsStatusSection(),
                        const SizedBox(height: 20),

                        // ══════════════════════════════════════════════════════
                        // خدمة الدعم الفني الرسمية
                        // ══════════════════════════════════════════════════════
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.borderHairline),
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      PhosphorIconsRegular.headset,
                                      size: 20,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'خدمة الدعم الفني المباشر',
                                          style: AppTextStyles.bodyMedium.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'فريق مركز الأمين متاح للرد على استفساراتك',
                                          style: AppTextStyles.caption,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    alignment: Alignment.center,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(
                                    PhosphorIconsRegular.whatsappLogo,
                                    size: 20,
                                  ),
                                  label: Text(
                                    'تواصل مع الدعم الفني (${AppConstants.supportPhone})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  onPressed: () {
                                    AppConstants.launchWhatsApp(
                                      customMessage:
                                          'السلام عليكم، أود التواصل مع دعم مركز الأمين للتخاطب بخصوص حسابي.\nالاسم: $displayName',
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // ══════════════════════════════════════════════════════
                        // روابط المعلومات والسياسات
                        // ══════════════════════════════════════════════════════
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.borderHairline),
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: Column(
                            children: [
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    PhosphorIconsRegular.buildings,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ),
                                title: const Text(
                                  'من نحن - مركز الأمين للتخاطب',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                trailing: Icon(
                                  AppDirectionalIcons.chevronDetail(context),
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                                onTap: () => context.push('/about'),
                              ),
                              const Divider(
                                height: 1,
                                color: AppColors.divider,
                                indent: 56,
                              ),
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    PhosphorIconsRegular.shieldCheck,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ),
                                title: const Text(
                                  'سياسة الخصوصية والاستخدام',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                trailing: Icon(
                                  AppDirectionalIcons.chevronDetail(context),
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                                onTap: () => context.push('/privacy-policy'),
                              ),
                              const Divider(
                                height: 1,
                                color: AppColors.divider,
                                indent: 56,
                              ),
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    PhosphorIconsRegular.question,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ),
                                title: const Text(
                                  'الأسئلة الشائعة والإرشادات',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                trailing: Icon(
                                  AppDirectionalIcons.chevronDetail(context),
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                                onTap: () => context.push('/faqs'),
                              ),
                              const Divider(
                                height: 1,
                                color: AppColors.divider,
                                indent: 56,
                              ),
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    PhosphorIconsRegular.compass,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ),
                                title: const Text(
                                  'جولة تعريفية بالمنصة',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                trailing: Icon(
                                  AppDirectionalIcons.chevronDetail(context),
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (pageContext) =>
                                          OnboardingScreen(
                                        onComplete: () async {
                                          Navigator.of(pageContext).pop();
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (kDebugMode) ...[
                                const Divider(
                                  height: 1,
                                  color: AppColors.divider,
                                  indent: 56,
                                ),
                                ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      PhosphorIconsRegular.terminalWindow,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  title: const Text(
                                    'أداة فحص تكامل الـ API (Debug)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'فحص مسارات Laravel API الموثقة بالجلسة الحية',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  trailing: Icon(
                                    AppDirectionalIcons.chevronDetail(context),
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  onTap: () => context.push('/debug-api-test'),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ══════════════════════════════════════════════════════
                        // إجراءات الحساب (تسجيل خروج بارز وحذف حساب نهائي)
                        // ══════════════════════════════════════════════════════
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.borderHairline),
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Prominent Sign Out Button
                              SizedBox(
                                height: 46,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    side: const BorderSide(
                                      color: AppColors.errorBorder,
                                    ),
                                    alignment: Alignment.center,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(
                                    PhosphorIconsRegular.signOut,
                                    size: 19,
                                  ),
                                  label: const Text(
                                    'تسجيل الخروج من الحساب',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () => _handleSignOut(context),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Account Deletion
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary,
                                  alignment: Alignment.center,
                                ),
                                icon: const Icon(
                                  PhosphorIconsRegular.trash,
                                  size: 16,
                                  color: AppColors.error,
                                ),
                                label: const Text(
                                  'حذف الحساب نهائياً من المنصة',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.error,
                                  ),
                                ),
                                onPressed: () => _handleDeleteAccount(context),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        Center(
                          child: Text(
                            'مركز الأمين للتخاطب والتأهيل',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: kBottomNavigationBarHeight + 24,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/responsive/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../logic/auth/admin_auth_cubit.dart';
import '../../../logic/auth/admin_auth_state.dart';
import '../admin_welcome.dart';
import 'profile_widgets/admin_identity_card.dart';
import 'profile_widgets/admins_management_card.dart';
import 'profile_widgets/center_content_management_dialog.dart';
import 'admins_tab.dart';

/// صفحة الملف الشخصي والإعدادات الإدارية لمركز الأمين.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Future<void> _confirmSignOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('profile.sign_out_dialog_title'.tr()),
        content: Text(
          'profile.sign_out_dialog_msg'.tr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('dialogs.cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('auth.sign_out'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await context.read<AdminAuthCubit>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminAuthCubit, AdminAuthState>(
      builder: (context, authState) {
        final adminEmail = authState is AdminAuthenticated
            ? authState.user.email
            : '';

        return ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 88),
          children: [
            ResponsiveCenter(
              maxWidth: 920,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AdminIdentityCard(
                        adminEmail: adminEmail,
                        onOpenGuide: () =>
                            showAdminWelcome(context, force: true),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionHeader('profile.team_rbac_section'.tr()),
                      const SizedBox(height: 8),
                      AdminsManagementCard(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar: AppBar(
                                  title: Text('profile.team_rbac_title'.tr()),
                                ),
                                body: const AdminsTab(),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildSectionHeader('محتوى التطبيق والتعريف بالمركز'),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderHairline),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.article_outlined,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          title: const Text(
                            'إدارة من نحن، سياسة الخصوصية، والأسئلة الشائعة',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: const Text(
                            'تعديل النصوص التعريفية وسياسات الاستخدام الظاهرة في تطبيق الطلاب',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          onTap: () => CenterContentManagementDialog.show(context),
                        ),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(
                            color: AppColors.errorBorder,
                            width: 1.2,
                          ),
                          backgroundColor: AppColors.errorLight.withValues(
                            alpha: 0.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _confirmSignOut(context),
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: Text(
                          'profile.sign_out_btn'.tr(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

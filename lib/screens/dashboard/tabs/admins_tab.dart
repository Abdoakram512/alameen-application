import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/responsive/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../logic/admins/admin_admins_cubit.dart';
import '../../../logic/admins/admin_admins_state.dart';
import '../../../logic/auth/admin_auth_cubit.dart';
import '../../../logic/auth/admin_auth_state.dart';
import '../../../models/admin_model.dart';
import 'admins_widgets/add_admin_dialog.dart';
import 'admins_widgets/admin_user_card.dart';
import 'admins_widgets/admins_filter_bar.dart';
import 'admins_widgets/edit_admin_permissions_dialog.dart';

class AdminsTab extends StatefulWidget {
  const AdminsTab({super.key});

  @override
  State<AdminsTab> createState() => _AdminsTabState();
}

class _AdminsTabState extends State<AdminsTab> {
  final _searchController = TextEditingController();
  String _selectedFilter = 'all'; // all, active, inactive

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentAdminState = context.watch<AdminAuthCubit>().state;
    final currentAdmin = currentAdminState is AdminAuthenticated
        ? currentAdminState.user
        : null;
    final canManageAdmins =
        currentAdmin?.hasPermission(AdminPermission.manageAdmins) ?? false;

    if (!canManageAdmins) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 48,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'admin_management.no_access_title'.tr(),
                style: AppTextStyles.heading2,
              ),
              const SizedBox(height: 8),
              Text(
                'admin_management.no_access_desc'.tr(),
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(fontSize: 13.5),
              ),
            ],
          ),
        ),
      );
    }

    return BlocConsumer<AdminAdminsCubit, AdminAdminsState>(
      listener: (context, state) {
        if (state is AdminAdminsActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state is AdminAdminsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is AdminAdminsLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final admins =
            state is AdminAdminsLoaded ? state.admins : <AdminModel>[];
        final query = _searchController.text.trim().toLowerCase();

        final filtered = admins.where((admin) {
          if (_selectedFilter == 'active' && !admin.isActive) return false;
          if (_selectedFilter == 'inactive' && admin.isActive) return false;

          if (query.isNotEmpty) {
            final nameMatch = admin.name.toLowerCase().contains(query);
            final emailMatch = admin.email.toLowerCase().contains(query);
            final phoneMatch = admin.phone.toLowerCase().contains(query);
            return nameMatch || emailMatch || phoneMatch;
          }
          return true;
        }).toList();

        final totalCount = admins.length;
        final activeCount = admins.where((a) => a.isActive).length;
        final isAr = Directionality.of(context) == TextDirection.rtl;

        return RefreshIndicator(
          onRefresh: () async {
            context.read<AdminAdminsCubit>().loadAdmins();
          },
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: context.horizontalPagePadding,
              vertical: 20,
            ),
            children: [
              // Header & Add Admin Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'admin_management.title'.tr(),
                          style: AppTextStyles.heading1,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'admin_management.subtitle'.tr(),
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      AddAdminDialog.show(
                        context,
                        onAdd: ({
                          required String name,
                          required String email,
                          required String phone,
                          required AdminRole role,
                          required List<String> permissions,
                        }) {
                          context.read<AdminAdminsCubit>().addAdmin(
                                name: name,
                                email: email,
                                phone: phone,
                                role: role,
                                permissions: permissions,
                                createdBy: currentAdmin?.email ?? 'admin',
                              );
                        },
                      );
                    },
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: Text('admin_management.add_admin_btn'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // KPI Cards
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      label: isAr ? 'إجمالي المشرفين' : 'Total Admins',
                      count: totalCount,
                      icon: Icons.group_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiCard(
                      label: isAr ? 'المشرفين النشطين' : 'Active Admins',
                      count: activeCount,
                      icon: Icons.check_circle_rounded,
                      color: AppColors.success,
                      textColor: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Search & Filter Bar
              AdminsFilterBar(
                searchController: _searchController,
                selectedFilter: _selectedFilter,
                onFilterChanged: (filter) =>
                    setState(() => _selectedFilter = filter),
                onClearSearch: () {
                  _searchController.clear();
                  setState(() {});
                },
                onSearchChanged: (_) => setState(() {}),
                isAr: isAr,
              ),
              const SizedBox(height: 16),

              // Admins List
              if (filtered.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 48,
                    horizontal: 24,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderHairline),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 48,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'لا يوجد مشرفين يطابقون البحث',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...filtered.map((admin) {
                  return AdminUserCard(
                    admin: admin,
                    onToggleStatus: (val) {
                      context.read<AdminAdminsCubit>().toggleAdminStatus(
                            adminId: admin.id,
                            role: admin.role,
                            isActive: val,
                          );
                    },
                    onEditPermissions: () {
                      EditAdminPermissionsDialog.show(
                        context,
                        admin: admin,
                        onSave: ({
                          required AdminRole role,
                          required List<String> permissions,
                        }) {
                          context.read<AdminAdminsCubit>().updateAdminPermissions(
                                adminId: admin.id,
                                role: role,
                                permissions: permissions,
                              );
                        },
                      );
                    },
                    onDelete: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dlgContext) => AlertDialog(
                          title: const Text('حذف المشرف'),
                          content: Text(
                            'هل أنت متأكد من حذف المشرف "${admin.name}" نهائياً من النظام؟ لن يتمكن من تسجيل الدخول بعد الآن.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dlgContext).pop(false),
                              child: const Text('إلغاء'),
                            ),
                            ElevatedButton(
                              onPressed: () =>
                                  Navigator.of(dlgContext).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('تأكيد الحذف'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true && context.mounted) {
                        await context.read<AdminAdminsCubit>().deleteAdmin(
                              adminId: admin.id,
                              role: admin.role,
                            );
                      }
                    },
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    Color? textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderHairline),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption),
                Text(
                  '$count',
                  style: AppTextStyles.heading1.copyWith(
                    fontSize: 22,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

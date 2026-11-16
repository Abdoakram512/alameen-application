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

  Color _getRoleColor(AdminRole role) {
    switch (role) {
      case AdminRole.superAdmin:
        return const Color(0xFF7C3AED); // Purple
      case AdminRole.instructor:
        return AppColors.primary; // Blue
      case AdminRole.supervisor:
        return const Color(0xFF0D9488); // Teal
      case AdminRole.assistant:
        return const Color(0xFF4F46E5); // Indigo
      case AdminRole.custom:
        return const Color(0xFFD97706); // Amber
    }
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

        final admins = state is AdminAdminsLoaded
            ? state.admins
            : <AdminModel>[];
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
              // Header & KPI Row
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
                        onAdd:
                            ({
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
                    child: Container(
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
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.group_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isAr ? 'إجمالي المشرفين' : 'Total Admins',
                                  style: AppTextStyles.caption,
                                ),
                                Text(
                                  '$totalCount',
                                  style: AppTextStyles.heading1.copyWith(
                                    fontSize: 22,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
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
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isAr ? 'المشرفين النشطين' : 'Active Admins',
                                  style: AppTextStyles.caption,
                                ),
                                Text(
                                  '$activeCount',
                                  style: AppTextStyles.heading1.copyWith(
                                    fontSize: 22,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Search & Filter Bar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderHairline),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: isAr
                            ? 'البحث باسم المشرف، بريده، أو رقم هاتفه...'
                            : 'Search by admin name, email, or phone...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 22),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                    const Divider(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        FilterChip(
                          label: Text('requests.all'.tr()),
                          selected: _selectedFilter == 'all',
                          onSelected: (_) =>
                              setState(() => _selectedFilter = 'all'),
                        ),
                        FilterChip(
                          label: Text('admin_management.active'.tr()),
                          selected: _selectedFilter == 'active',
                          onSelected: (_) =>
                              setState(() => _selectedFilter = 'active'),
                        ),
                        FilterChip(
                          label: Text('admin_management.inactive'.tr()),
                          selected: _selectedFilter == 'inactive',
                          onSelected: (_) =>
                              setState(() => _selectedFilter = 'inactive'),
                        ),
                      ],
                    ),
                  ],
                ),
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
                  final isProtectedSuperAdmin = admin.isSuperAdmin;
                  final roleColor = _getRoleColor(admin.role);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: admin.isActive
                            ? AppColors.borderHairline
                            : AppColors.error.withValues(alpha: 0.2),
                      ),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: roleColor.withValues(
                                alpha: 0.12,
                              ),
                              child: Text(
                                admin.name.isNotEmpty ? admin.name[0] : 'أ',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: roleColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        admin.name,
                                        style: AppTextStyles.heading3,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: roleColor.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          admin.role.labelAr,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: roleColor,
                                          ),
                                        ),
                                      ),
                                      if (isProtectedSuperAdmin)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: const Text(
                                            'حساب رئيسي',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFFB45309),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    admin.email,
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (admin.phone.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'هاتف: ${admin.phone}',
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: admin.isActive,
                              activeTrackColor: AppColors.success,
                              onChanged: isProtectedSuperAdmin
                                  ? null
                                  : (val) {
                                      context
                                          .read<AdminAdminsCubit>()
                                          .toggleAdminStatus(
                                            adminId: admin.id,
                                            role: admin.role,
                                            isActive: val,
                                          );
                                    },
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Text(
                          'الصلاحيات المفعلة (${admin.permissions.length}):',
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: admin.permissions.map((p) {
                            return Chip(
                              label: Text(
                                AdminPermission.getLabelAr(p),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.06,
                              ),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide(
                                color: AppColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: isProtectedSuperAdmin
                                  ? null
                                  : () {
                                      EditAdminPermissionsDialog.show(
                                        context,
                                        admin: admin,
                                        onSave:
                                            ({
                                              required AdminRole role,
                                              required List<String> permissions,
                                            }) {
                                              context
                                                  .read<AdminAdminsCubit>()
                                                  .updateAdminPermissions(
                                                    adminId: admin.id,
                                                    role: role,
                                                    permissions: permissions,
                                                  );
                                            },
                                      );
                                    },
                              icon: const Icon(
                                Icons.edit_note_rounded,
                                size: 18,
                              ),
                              label: const Text('تعديل الصلاحيات'),
                            ),
                            if (!isProtectedSuperAdmin) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                                tooltip: 'حذف المشرف',
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (dlgContext) => AlertDialog(
                                      title: const Text('حذف المشرف'),
                                      content: Text(
                                        'هل أنت متأكد من حذف المشرف "${admin.name}" نهائياً من النظام؟ لن يتمكن من تسجيل الدخول بعد الآن.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(
                                            dlgContext,
                                          ).pop(false),
                                          child: const Text('إلغاء'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.of(
                                            dlgContext,
                                          ).pop(true),
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
                                    await context
                                        .read<AdminAdminsCubit>()
                                        .deleteAdmin(
                                          adminId: admin.id,
                                          role: admin.role,
                                        );
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

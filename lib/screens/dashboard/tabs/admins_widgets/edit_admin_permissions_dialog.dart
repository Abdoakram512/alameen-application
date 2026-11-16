import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/admin_model.dart';

class EditAdminPermissionsDialog extends StatefulWidget {
  final AdminModel admin;
  final Function({
    required AdminRole role,
    required List<String> permissions,
  }) onSave;

  const EditAdminPermissionsDialog({
    super.key,
    required this.admin,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required AdminModel admin,
    required Function({
      required AdminRole role,
      required List<String> permissions,
    }) onSave,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditAdminPermissionsDialog(admin: admin, onSave: onSave),
    );
  }

  @override
  State<EditAdminPermissionsDialog> createState() =>
      _EditAdminPermissionsDialogState();
}

class _EditAdminPermissionsDialogState
    extends State<EditAdminPermissionsDialog> {
  late AdminRole _selectedRole;
  late Set<String> _selectedPermissions;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.admin.role;
    _selectedPermissions = Set.from(widget.admin.permissions);
  }

  void _onRoleChanged(AdminRole? newRole) {
    if (newRole == null) return;
    setState(() {
      _selectedRole = newRole;
      if (newRole != AdminRole.custom) {
        _selectedPermissions = Set.from(AdminPermission.defaultForRole(newRole));
      }
    });
  }

  void _togglePermission(String perm, bool? value) {
    setState(() {
      if (value == true) {
        _selectedPermissions.add(perm);
      } else {
        _selectedPermissions.remove(perm);
      }
      _selectedRole = AdminRole.custom;
    });
  }

  void _submit() {
    if (_selectedPermissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب اختيار صلاحية واحدة على الأقل للمشرف.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    widget.onSave(
      role: _selectedRole,
      permissions: _selectedPermissions.toList(),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.security_rounded, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('تعديل صلاحيات المشرف', style: AppTextStyles.heading2),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.admin.name} (${widget.admin.email})',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 28),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('الدور الوظيفي المحدد (Preset Role)', style: AppTextStyles.bodyMedium),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.borderHairline),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<AdminRole>(
                            value: _selectedRole,
                            isExpanded: true,
                            items: AdminRole.values.map((role) {
                              return DropdownMenuItem<AdminRole>(
                                value: role,
                                child: Text(role.labelAr),
                              );
                            }).toList(),
                            onChanged: widget.admin.isSuperAdmin ? null : _onRoleChanged,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text('الصلاحيات الممنوحة:', style: AppTextStyles.bodyMedium),
                      const SizedBox(height: 8),
                      ...AdminPermission.all.map((perm) {
                        final isChecked = _selectedPermissions.contains(perm);
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            AdminPermission.getLabelAr(perm),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
                              color: isChecked ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                          ),
                          value: isChecked,
                          activeColor: AppColors.primary,
                          onChanged: widget.admin.isSuperAdmin
                              ? null
                              : (val) => _togglePermission(perm, val),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.admin.isSuperAdmin ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('حفظ التعديلات'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


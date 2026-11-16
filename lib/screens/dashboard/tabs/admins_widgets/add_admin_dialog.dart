import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../models/admin_model.dart';

class AddAdminDialog extends StatefulWidget {
  final Function({
    required String name,
    required String email,
    required String phone,
    required AdminRole role,
    required List<String> permissions,
  })
  onAdd;

  const AddAdminDialog({super.key, required this.onAdd});

  static Future<void> show(
    BuildContext context, {
    required Function({
      required String name,
      required String email,
      required String phone,
      required AdminRole role,
      required List<String> permissions,
    })
    onAdd,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddAdminDialog(onAdd: onAdd),
    );
  }

  @override
  State<AddAdminDialog> createState() => _AddAdminDialogState();
}

class _AddAdminDialogState extends State<AddAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  AdminRole _selectedRole = AdminRole.assistant;
  late Set<String> _selectedPermissions;

  @override
  void initState() {
    super.initState();
    _selectedPermissions = Set.from(
      AdminPermission.defaultForRole(_selectedRole),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onRoleChanged(AdminRole? newRole) {
    if (newRole == null) return;
    setState(() {
      _selectedRole = newRole;
      if (newRole != AdminRole.custom) {
        _selectedPermissions = Set.from(
          AdminPermission.defaultForRole(newRole),
        );
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
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPermissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب اختيار صلاحية واحدة على الأقل للمشرف.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    widget.onAdd(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: AppValidators.cleanEgyptianPhone(_phoneController.text),
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
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
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
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إضافة مشرف إداري جديد',
                          style: AppTextStyles.heading2,
                        ),
                        SizedBox(height: 2),
                        Text(
                          'منح صلاحيات محددة لإدارة الكورسات أو الطلاب أو الطلبات',
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'اسم المشرف الكامل *',
                            hintText: 'مثال: أ. محمود كمال',
                            prefixIcon: const Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().length < 3)
                              ? 'يرجى إدخال اسم المشرف'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'البريد الإلكتروني للـ Firebase Auth *',
                            hintText: 'admin@elameen.com',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: AppValidators.validateEmail,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'رقم الهاتف / واتساب (اختياري)',
                            hintText: '010XXXXXXXX',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            return AppValidators.validateEgyptianPhone(v, 'رقم الهاتف');
                          },
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'الدور الوظيفي المحدد (Preset Role)',
                          style: AppTextStyles.bodyMedium,
                        ),
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
                              onChanged: _onRoleChanged,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'الصلاحيات الممنوحة للمشرف:',
                          style: AppTextStyles.bodyMedium,
                        ),
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
                                fontWeight: isChecked
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isChecked
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                            value: isChecked,
                            activeColor: AppColors.primary,
                            onChanged: (val) => _togglePermission(perm, val),
                          );
                        }),
                      ],
                    ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('حفظ وإضافة المشرف'),
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

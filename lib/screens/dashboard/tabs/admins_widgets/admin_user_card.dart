import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/admin_model.dart';
import 'admin_role_badge.dart';

/// بطاقة عرض بيانات المشرف الإداري، وصلاحياته، وحالته مع إجراءات التعديل والحذف.
class AdminUserCard extends StatelessWidget {
  final AdminModel admin;
  final ValueChanged<bool>? onToggleStatus;
  final VoidCallback? onEditPermissions;
  final VoidCallback? onDelete;

  const AdminUserCard({
    super.key,
    required this.admin,
    this.onToggleStatus,
    this.onEditPermissions,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isProtectedSuperAdmin = admin.isSuperAdmin;
    final roleColor = AdminRoleBadge.getRoleColor(admin.role);

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
                backgroundColor: roleColor.withValues(alpha: 0.12),
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
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          admin.name,
                          style: AppTextStyles.heading3,
                        ),
                        AdminRoleBadge(
                          role: admin.role,
                          isProtectedSuperAdmin: isProtectedSuperAdmin,
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
                onChanged: isProtectedSuperAdmin ? null : onToggleStatus,
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
                backgroundColor: AppColors.primary.withValues(alpha: 0.06),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: isProtectedSuperAdmin ? null : onEditPermissions,
                icon: const Icon(
                  Icons.edit_note_rounded,
                  size: 18,
                ),
                label: const Text('تعديل الصلاحيات'),
              ),
              if (!isProtectedSuperAdmin && onDelete != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                  tooltip: 'حذف المشرف',
                  onPressed: onDelete,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

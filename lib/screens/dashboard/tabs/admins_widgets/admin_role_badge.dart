import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/admin_model.dart';

/// شارة توضيح دور المشرف الإداري في النظام وألوانه المميزة.
class AdminRoleBadge extends StatelessWidget {
  final AdminRole role;
  final bool isProtectedSuperAdmin;

  const AdminRoleBadge({
    super.key,
    required this.role,
    this.isProtectedSuperAdmin = false,
  });

  static Color getRoleColor(AdminRole role) {
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
    final roleColor = getRoleColor(role);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: roleColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            role.labelAr,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: roleColor,
            ),
          ),
        ),
        if (isProtectedSuperAdmin)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(6),
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
    );
  }
}

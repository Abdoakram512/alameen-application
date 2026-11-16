import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/painters/executive_quick_action_painter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bouncing_card.dart';
import '../../../logic/courses/admin_courses_cubit.dart';
import '../../../logic/requests/admin_requests_cubit.dart';
import '../../../logic/students/admin_students_cubit.dart';
import '../../students/provision_students_sheet.dart';
import '../tabs/admins_tab.dart';

/// إجراءات الإدارة السريعة بتصميم تنفيذي فخم يقدم عمليات حقيقية غير مكررة مع التبويبات.
class DashboardQuickActions extends StatelessWidget {
  final VoidCallback onGoToRequests;
  final VoidCallback onGoToAnalytics;
  final VoidCallback? onGoToAssignments;
  final int pendingRequestsCount;

  const DashboardQuickActions({
    super.key,
    required this.onGoToRequests,
    required this.onGoToAnalytics,
    this.onGoToAssignments,
    this.pendingRequestsCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;

    final actions = [
      _QuickActionSpec(
        label: isAr ? 'تسجيل متدربين' : 'Register Students',
        subtitle: isAr ? 'تسجيل دفعة طلاب وتفعيلهم' : 'Bulk add & enroll students',
        icon: PhosphorIconsRegular.userPlus,
        color: const Color(0xFF059669),
        gradient: const [Color(0xFF059669), Color(0xFF10B981)],
        onTap: () {
          final courses = context.read<AdminCoursesCubit>().state.courses;
          ProvisionStudentsSheet.show(context, availableCourses: courses);
        },
      ),
      _QuickActionSpec(
        label: isAr ? 'تسليمات المهام' : 'Tasks & Submissions',
        subtitle: isAr ? 'متابعة تسليمات وملاحظات الطلاب' : 'Review practical submissions',
        icon: PhosphorIconsRegular.notebook,
        color: const Color(0xFF7C3AED),
        gradient: const [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
        onTap: onGoToAssignments ?? () {},
      ),
      _QuickActionSpec(
        label: isAr ? 'فريق العمل' : 'Admin Team',
        subtitle: isAr ? 'إدارة المشرفين والصلاحيات' : 'Manage admins & permissions',
        icon: PhosphorIconsRegular.shieldCheck,
        color: AppColors.royalNavy,
        gradient: const [Color(0xFF0B192C), Color(0xFF1E3E62)],
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(
                  title: Text(isAr ? 'فريق العمل والصلاحيات' : 'Admin Team & Roles'),
                ),
                body: const AdminsTab(),
              ),
            ),
          );
        },
      ),
      _QuickActionSpec(
        label: isAr ? 'طلبات الاشتراك' : 'Access Requests',
        subtitle: isAr ? 'مراجعة واعتماد إيصالات الدفع' : 'Review receipts & grant',
        icon: PhosphorIconsRegular.receipt,
        color: const Color(0xFFD97706),
        gradient: const [Color(0xFFD97706), Color(0xFFF59E0B)],
        badgeCount: pendingRequestsCount,
        onTap: onGoToRequests,
      ),
      _QuickActionSpec(
        label: isAr ? 'مزامنة المنصة' : 'Sync Platform',
        subtitle: isAr ? 'تحديث لحظي لجميع البيانات' : 'Force refresh all records',
        icon: PhosphorIconsRegular.arrowsClockwise,
        color: const Color(0xFF2563EB),
        gradient: const [Color(0xFF2563EB), Color(0xFF3B82F6)],
        onTap: () {
          HapticFeedback.lightImpact();
          context.read<AdminCoursesCubit>().loadCourses();
          context.read<AdminStudentsCubit>().loadStudents();
          context.read<AdminRequestsCubit>().loadRequests();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isAr ? 'تمت مزامنة جميع بيانات المنصة بنجاح.' : 'Platform data synced successfully.'),
              backgroundColor: AppColors.successDark,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3.5,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.royalNavy,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'dashboard.quick_actions_title'.tr(),
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 420;
            if (isCompact) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildActionItem(actions[0])),
                      const SizedBox(width: 10),
                      Expanded(child: _buildActionItem(actions[1])),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildActionItem(actions[2])),
                      const SizedBox(width: 10),
                      Expanded(child: _buildActionItem(actions[3])),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                for (int i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: _buildActionItem(actions[i])),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionItem(_QuickActionSpec spec) {
    return BouncingCard(
      onTap: () {
        HapticFeedback.selectionClick();
        spec.onTap();
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 104),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: spec.color.withValues(alpha: 0.18),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: spec.color.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CustomPaint(
            painter: ExecutiveQuickActionPainter(baseColor: spec.color),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon Bubble with optional Live Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: spec.gradient,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: spec.color.withValues(alpha: 0.30),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            spec.icon,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      ),
                      if (spec.badgeCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.error.withValues(alpha: 0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            '${spec.badgeCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: spec.color.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    spec.label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                    textAlign: TextAlign.start,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    spec.subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary.withValues(alpha: 0.85),
                    ),
                    textAlign: TextAlign.start,
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

class _QuickActionSpec {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Color> gradient;
  final int badgeCount;
  final VoidCallback onTap;

  const _QuickActionSpec({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.gradient,
    this.badgeCount = 0,
    required this.onTap,
  });
}

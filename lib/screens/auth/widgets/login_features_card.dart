import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/painters/geometric_background_painter.dart';
import '../../../core/theme/app_colors.dart';

/// لوحة تعريفية مؤسسية تظهر على الشاشات العريضة (Desktop / Tablet Landscape)
/// لتوفير تخطيط ثنائي الأعمدة متوازن دون ازدحام على شاشة الهاتف.
class LoginFeaturesCard extends StatelessWidget {
  const LoginFeaturesCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.royalNavy,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.heroShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: CustomPaint(
          painter: const GeometricBackgroundPainter(
            strokeColor: Color(0x14FFFFFF),
            spacing: 32,
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'auth.features_title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  Directionality.of(context) == TextDirection.rtl
                      ? AppConstants.appNameAr
                      : AppConstants.appName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'auth.portal_desc'.tr(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 13.5,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                _buildItem(
                  icon: Icons.menu_book_rounded,
                  title: 'auth.curriculum_feature'.tr(),
                  subtitle: 'auth.curriculum_feature_desc'.tr(),
                ),
                const SizedBox(height: 16),
                _buildItem(
                  icon: Icons.fact_check_outlined,
                  title: 'auth.triage_feature'.tr(),
                  subtitle: 'auth.triage_feature_desc'.tr(),
                ),
                const SizedBox(height: 16),
                _buildItem(
                  icon: Icons.groups_outlined,
                  title: 'auth.students_feature'.tr(),
                  subtitle: 'auth.students_feature_desc'.tr(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

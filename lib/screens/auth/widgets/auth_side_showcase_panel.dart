import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// اللوحة الجانبية المؤسسية لشاشات الدخول والتسجيل على الشاشات العريضة (التابلت وسطح المكتب).
class AuthSideShowcasePanel extends StatelessWidget {
  const AuthSideShowcasePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.heroShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Image.asset(
              'assets/images/website-logo.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'منصة مركز الأمين\nللتخاطب وتنمية المهارات',
            style: AppTextStyles.displayLarge.copyWith(
              color: Colors.white,
              fontSize: 26,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'مناهج تأهيلية متكاملة في النطق واللغة وتعديل السلوك، مصممة لتمكين الأخصائيين وأولياء الأمور من متابعة المحاضرات والتدريبات التطبيقية بوضوح.',
            style: AppTextStyles.bodyLarge.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.7,
            ),
          ),
          const SizedBox(height: 28),
          const _FeatureBullet(
            icon: Icons.menu_book_rounded,
            text: 'دورات مقسمة إلى مستويات تدريجية واضحة',
          ),
          const SizedBox(height: 12),
          const _FeatureBullet(
            icon: Icons.play_lesson_rounded,
            text: 'استئناف تلقائي للمحاضرات من آخر موضع مشاهدة',
          ),
          const SizedBox(height: 12),
          const _FeatureBullet(
            icon: Icons.assignment_turned_in_rounded,
            text: 'متابعة التكليفات العملية والتقييمات أولاً بأول',
          ),
        ],
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureBullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}


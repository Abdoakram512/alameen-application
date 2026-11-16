import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/firestore_service.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('من نحن'),
        centerTitle: true,
      ),
      body: StreamBuilder(
        stream: FirestoreService().streamAppContent('about_us'),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          final content = data?['content'] as String? ??
              'مرحباً بكم في مركز الأمين للتخاطب والتأهيل.\n\nصرح تدريبي واستشاري رائد ومتخصص في إعداد وتأهيل أخصائيي التخاطب وصعوبات التعلم وتعديل السلوك وتنمية المهارات بأعلى معايير الجودة المهنية.\n\nيقدم المركز برامج تدريبية ودورات معتمدة بإشراف نخبة من كبار الخبراء والاستشاريين بهدف تزويد المتدربين بالمهارات التطبيقية والعملية اللازمة للتميز في سوق العمل وخدمة أصحاب الهمم وأولياء الأمور بكفاءة واقتدار.';
          final title = data?['title'] as String? ?? 'مركز الأمين للتخاطب والتأهيل';

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderHairline),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          PhosphorIconsRegular.buildings,
                          size: 36,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: AppColors.divider),
                      const SizedBox(height: 16),
                      Text(
                        content,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.8,
                        ),
                        textAlign: TextAlign.justify,
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              PhosphorIconsRegular.phoneCall,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'للتواصل والاستفسار: ${AppConstants.supportPhone}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => AppConstants.launchWhatsApp(),
                              child: const Text('واتساب'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

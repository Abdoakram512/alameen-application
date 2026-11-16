import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/firestore_service.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('سياسة الخصوصية'),
        centerTitle: true,
      ),
      body: StreamBuilder(
        stream: FirestoreService().streamAppContent('privacy_policy'),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          final content = data?['content'] as String? ??
              'نولي في مركز الأمين للتخاطب والتأهيل أولوية قصوى لحماية خصوصيتك وسرية بياناتك الشخصية.\n\n١. جمع البيانات:\nنقوم بجمع بيانات الاسم ورقم الهاتف والبريد الإلكتروني فقط لأغراض التوثيق الأكاديمي، إصدار الشهادات المعتمدة، وتوفير الدعم الفني اللازم.\n\n٢. سرية المحتوى والأمان:\nجميع الدروس والمحاضرات الرقمية والتسجيلات محمية بحقوق ملكية فكرية بموجب القانون. يُمنع تصوير الشاشة أو تسجيل المحاضرات أو مشاركة الحسابات مع أطراف أخرى.\n\n٣. مشاركة البيانات:\nنلتزم التزاماً كاملاً بعدم بيع أو مشاركة بياناتك الشخصية مع أي أطراف ثالثة أو شركات تسويقية إطلاقاً.\n\n٤. حذف الحساب والبيانات:\nيحق للمتدرب في أي وقت طلب حذف حسابه بالكامل من التطبيق عبر الذهاب للملف الشخصي واختيار "حذف الحساب نهائياً"، وسيتم مسح جميع بياناته فوراً وبشكل دائم.';
          final title = data?['title'] as String? ?? 'سياسة الخصوصية والأمان';

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
                          PhosphorIconsRegular.shieldCheck,
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
                              PhosphorIconsRegular.lockKey,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'حماية تامة وأمان رقمي معتمد لدى مركز الأمين',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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

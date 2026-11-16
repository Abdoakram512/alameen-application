import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/firestore_service.dart';

class FaqsScreen extends StatelessWidget {
  const FaqsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('الأسئلة الشائعة'),
        centerTitle: true,
      ),
      body: StreamBuilder(
        stream: FirestoreService().streamAppContent('faqs'),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          final rawItems = data?['items'] as List<dynamic>?;
          final List<Map<String, String>> items = rawItems != null
              ? rawItems.map((item) {
                  final map = Map<String, dynamic>.from(item as Map);
                  return {
                    'question': (map['question'] ?? '').toString(),
                    'answer': (map['answer'] ?? '').toString(),
                  };
                }).toList()
              : [
                  {
                    'question': 'كيف أحصل على شهادة التخرج واجتياز الكورس؟',
                    'answer':
                        'تحصل على الشهادة المعتمدة تلقائياً عند إتمامك لكافة المحاضرات بنسبة 100%، وتسليم جميع التكليفات والمهام المقررة واعتماد درجاتها من قِبل إدارة المركز.',
                  },
                  {
                    'question': 'هل المحاضرات مسجلة أم بث مباشر؟',
                    'answer':
                        'المحاضرات مسجلة بجودة عالية ومرفوعة على خوادم آمنة لتتمكن من دراستها والرجوع إليها في أي وقت يناسب جدولك اليومي.',
                  },
                  {
                    'question': 'كيف أقوم بتسليم التكليفات والتطبيقات العملية؟',
                    'answer':
                        'من داخل صفحة كل درس، ستجد نموذج تسليم التكليف المطلوب. قم برفع رابط أو نص الحل وسيتم تصحيحه من قِبل الإدارة ورصد الدرجة فوراً في ملفك التدريبي.',
                  },
                  {
                    'question': 'هل يمكنني تغيير اسمي المسجل في الشهادة؟',
                    'answer':
                        'الاسم المسجل معتمد رسمياً في استخراج الشهادات لمنع التلاعب. في حال وجود خطأ إملائي، يرجى التواصل فوراً مع الدعم الفني لتعديله بعد التحقق من الهوية.',
                  },
                  {
                    'question': 'كيف أتواصل مع الدعم الفني وإدارة المركز؟',
                    'answer':
                        'يمكنك التواصل عبر محادثة واتساب المباشرة أو الاتصال على الرقم: 01115240237 طوال أيام الأسبوع.',
                  },
                ];

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderHairline),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            PhosphorIconsRegular.chatsCircle,
                            size: 28,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'إجابات على أكثر الاستفسارات شيوعاً',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'لم تجد إجابة لسؤالك؟ فريق الدعم متاح دائماً لمساعدتك.',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.borderHairline),
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                            ),
                            child: ExpansionTile(
                              iconColor: AppColors.primary,
                              collapsedIconColor: AppColors.textSecondary,
                              title: Text(
                                item['question']!,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      item['answer']!,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                        height: 1.6,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(PhosphorIconsRegular.whatsappLogo, size: 20),
                        label: const Text(
                          'تحدث مع الدعم الفني عبر واتساب',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => AppConstants.launchWhatsApp(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

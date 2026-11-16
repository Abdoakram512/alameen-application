import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../services/firestore_service.dart';

class CenterContentManagementDialog extends StatefulWidget {
  const CenterContentManagementDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CenterContentManagementDialog(),
    );
  }

  @override
  State<CenterContentManagementDialog> createState() =>
      _CenterContentManagementDialogState();
}

class _CenterContentManagementDialogState
    extends State<CenterContentManagementDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _aboutCtrl = TextEditingController();
  final _privacyCtrl = TextEditingController();
  List<Map<String, String>> _faqs = [];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialContent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _aboutCtrl.dispose();
    _privacyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialContent() async {
    try {
      final fs = FirestoreService();
      final aboutSnap = await fs.streamAppContent('about_us').first;
      if (aboutSnap.exists && aboutSnap.data() != null) {
        _aboutCtrl.text = aboutSnap.data()?['content'] as String? ?? '';
      } else {
        _aboutCtrl.text =
            'مرحباً بكم في مركز الأمين للتخاطب والتأهيل.\n\nصرح تدريبي واستشاري رائد ومتخصص في إعداد وتأهيل أخصائيي التخاطب وصعوبات التعلم وتعديل السلوك وتنمية المهارات بأعلى معايير الجودة المهنية.\n\nيقدم المركز برامج تدريبية ودورات معتمدة بإشراف نخبة من كبار الخبراء والاستشاريين بهدف تزويد المتدربين بالمهارات التطبيقية والعملية اللازمة للتميز في سوق العمل وخدمة أصحاب الهمم وأولياء الأمور بكفاءة واقتدار.';
      }

      final privSnap = await fs.streamAppContent('privacy_policy').first;
      if (privSnap.exists && privSnap.data() != null) {
        _privacyCtrl.text = privSnap.data()?['content'] as String? ?? '';
      } else {
        _privacyCtrl.text =
            'نولي في مركز الأمين للتخاطب والتأهيل أولوية قصوى لحماية خصوصيتك وسرية بياناتك الشخصية.\n\n١. جمع البيانات:\nنقوم بجمع بيانات الاسم ورقم الهاتف والبريد الإلكتروني فقط لأغراض التوثيق الأكاديمي، إصدار الشهادات المعتمدة، وتوفير الدعم الفني اللازم.\n\n٢. سرية المحتوى والأمان:\nجميع الدروس والمحاضرات الرقمية والتسجيلات محمية بحقوق ملكية فكرية بموجب القانون. يُمنع تصوير الشاشة أو تسجيل المحاضرات أو مشاركة الحسابات مع أطراف أخرى.\n\n٣. مشاركة البيانات:\nنلتزم التزاماً كاملاً بعدم بيع أو مشاركة بياناتك الشخصية مع أي أطراف ثالثة أو شركات تسويقية إطلاقاً.\n\n٤. حذف الحساب والبيانات:\nيحق للمتدرب في أي وقت طلب حذف حسابه بالكامل من التطبيق عبر الذهاب للملف الشخصي واختيار "حذف الحساب نهائياً"، وسيتم مسح جميع بياناته فوراً وبشكل دائم.';
      }

      final faqsSnap = await fs.streamAppContent('faqs').first;
      if (faqsSnap.exists && faqsSnap.data() != null) {
        final raw = faqsSnap.data()?['items'] as List<dynamic>? ?? [];
        _faqs = raw.map((item) {
          final m = Map<String, dynamic>.from(item as Map);
          return {
            'question': (m['question'] ?? '').toString(),
            'answer': (m['answer'] ?? '').toString(),
          };
        }).toList();
      } else {
        _faqs = [
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
            'question': 'كيف أتواصل مع الدعم الفني وإدارة المركز؟',
            'answer':
                'يمكنك التواصل عبر محادثة واتساب المباشرة أو الاتصال على الرقم: 01115240237 طوال أيام الأسبوع.',
          },
        ];
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveContent() async {
    setState(() => _isSaving = true);
    try {
      final fs = FirestoreService();
      await fs.saveAppContent(
        docId: 'about_us',
        title: 'من نحن - مركز الأمين للتخاطب',
        content: _aboutCtrl.text.trim(),
      );
      await fs.saveAppContent(
        docId: 'privacy_policy',
        title: 'سياسة الخصوصية والاستخدام',
        content: _privacyCtrl.text.trim(),
      );
      await fs.saveAppContent(
        docId: 'faqs',
        title: 'الأسئلة الشائعة والإرشادات',
        content: _faqs,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث وحفظ محتوى المركز بنجاح.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر حفظ المحتوى: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _addOrEditFaqItem({int? index}) {
    final qCtrl = TextEditingController(
      text: index != null ? _faqs[index]['question'] : '',
    );
    final aCtrl = TextEditingController(
      text: index != null ? _faqs[index]['answer'] : '',
    );

    showDialog<void>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(index != null ? 'تعديل السؤال' : 'إضافة سؤال جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qCtrl,
              decoration: const InputDecoration(
                labelText: 'نص السؤال',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: aCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'نص الإجابة التوضيحية',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final q = qCtrl.text.trim();
              final a = aCtrl.text.trim();
              if (q.isEmpty || a.isEmpty) return;
              setState(() {
                if (index != null) {
                  _faqs[index] = {'question': q, 'answer': a};
                } else {
                  _faqs.add({'question': q, 'answer': a});
                }
              });
              Navigator.pop(dCtx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      PhosphorIconsRegular.pencilSimple,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'إدارة محتوى المنصة ومعلومات المركز',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(PhosphorIconsRegular.x),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: const [
                  Tab(text: 'من نحن'),
                  Tab(text: 'سياسة الخصوصية'),
                  Tab(text: 'الأسئلة الشائعة'),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          // Tab 1: About Us
                          TextField(
                            controller: _aboutCtrl,
                            maxLines: 15,
                            decoration: const InputDecoration(
                              hintText: 'اكتب نبذة تعريفية عن المركز وأهدافه...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          // Tab 2: Privacy Policy
                          TextField(
                            controller: _privacyCtrl,
                            maxLines: 15,
                            decoration: const InputDecoration(
                              hintText: 'اكتب بنود سياسة الخصوصية وحماية البيانات...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          // Tab 3: FAQs
                          Column(
                            children: [
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: TextButton.icon(
                                  icon: const Icon(PhosphorIconsRegular.plus, size: 16),
                                  label: const Text('إضافة سؤال وجواب'),
                                  onPressed: _addOrEditFaqItem,
                                ),
                              ),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: _faqs.length,
                                  separatorBuilder: (_, index) => const Divider(height: 1),
                                  itemBuilder: (ctx, i) {
                                    final faq = _faqs[i];
                                    return ListTile(
                                      title: Text(
                                        faq['question'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      subtitle: Text(
                                        faq['answer'] ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 16),
                                            onPressed: () => _addOrEditFaqItem(index: i),
                                          ),
                                          IconButton(
                                            icon: const Icon(PhosphorIconsRegular.trash, size: 16, color: AppColors.error),
                                            onPressed: () {
                                              setState(() => _faqs.removeAt(i));
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: _isSaving ? null : _saveContent,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(PhosphorIconsRegular.floppyDisk, size: 18),
                    label: Text(_isSaving ? 'جارٍ الحفظ...' : 'حفظ التعديلات ونشرها'),
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

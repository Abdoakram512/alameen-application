import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/support_ticket.dart';
import '../../../../repositories/student_support_repository.dart';

class CreateTicketSheet extends StatefulWidget {
  final StudentSupportRepository? repository;
  final int? preselectedCourseId;
  final ValueChanged<SupportTicket>? onTicketCreated;

  const CreateTicketSheet({
    super.key,
    this.repository,
    this.preselectedCourseId,
    this.onTicketCreated,
  });

  static Future<SupportTicket?> show(
    BuildContext context, {
    StudentSupportRepository? repository,
    int? preselectedCourseId,
  }) {
    return showModalBottomSheet<SupportTicket>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CreateTicketSheet(
          repository: repository,
          preselectedCourseId: preselectedCourseId,
        ),
      ),
    );
  }

  @override
  State<CreateTicketSheet> createState() => _CreateTicketSheetState();
}

class _CreateTicketSheetState extends State<CreateTicketSheet> {
  late final StudentSupportRepository _repository;
  final _formKey = GlobalKey<FormState>();

  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  String _selectedCategory = 'clinical';
  String _selectedPriority = 'normal';
  int? _courseId;
  final List<String> _attachmentPaths = [];

  bool _isSubmitting = false;
  String? _errorMessage;

  final ImagePicker _picker = ImagePicker();

  final List<Map<String, String>> _categories = const [
    {'value': 'clinical', 'label': 'استفسار سريري / أكاديمي'},
    {'value': 'technical', 'label': 'دعم فني وتطبيقي'},
    {'value': 'payment', 'label': 'استفسار مالي أو اشتراك'},
    {'value': 'certificate', 'label': 'شهادات وإتمام المساق'},
    {'value': 'other', 'label': 'استفسار عام / أخرى'},
  ];

  final List<Map<String, String>> _priorities = const [
    {'value': 'low', 'label': 'منخفضة'},
    {'value': 'normal', 'label': 'عادية'},
    {'value': 'high', 'label': 'عالية'},
    {'value': 'urgent', 'label': 'طارئة'},
  ];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? sl<StudentSupportRepository>();
    _courseId = widget.preselectedCourseId;
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file != null) {
        setState(() {
          _attachmentPaths.add(file.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر اختيار الملف: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachmentPaths.removeAt(index);
    });
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final ticket = await _repository.createTicket(
        subject: _subjectController.text.trim(),
        category: _selectedCategory,
        message: _messageController.text.trim(),
        priority: _selectedPriority,
        courseId: _courseId,
        attachmentPaths: _attachmentPaths.isNotEmpty ? _attachmentPaths : null,
      );

      if (!mounted) return;
      widget.onTicketCreated?.call(ticket);
      Navigator.of(context).pop(ticket);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      PhosphorIconsRegular.chatTeardropDots,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'فتح تذكرة دعم فني جديدة',
                          style: AppTextStyles.heading3.copyWith(fontSize: 17),
                        ),
                        Text(
                          'سيقوم الفريق الأكاديمي أو التقني بالرد عليك في أقرب وقت.',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(PhosphorIconsRegular.warningCircle, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTextStyles.caption.copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // عنوان التذكرة
              Text('موضوع التذكرة', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  hintText: 'مثال: استفسار حول التكليف السريري الثاني',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderHairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderHairline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  prefixIcon: const Icon(PhosphorIconsRegular.textbox, color: AppColors.textMuted),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 4) {
                    return 'يرجى كتابة موضوع واضح للتذكرة (على الأقل 4 أحرف)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // تصنيف التذكرة
              Text('التصنيف', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderHairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderHairline),
                  ),
                  prefixIcon: const Icon(PhosphorIconsRegular.tag, color: AppColors.textMuted),
                ),
                items: _categories.map((c) {
                  return DropdownMenuItem<String>(
                    value: c['value'],
                    child: Text(c['label']!, style: AppTextStyles.bodyMedium),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 16),

              // الأولوية
              Text('مستوى الأهمية', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedPriority,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderHairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderHairline),
                  ),
                  prefixIcon: const Icon(PhosphorIconsRegular.flag, color: AppColors.textMuted),
                ),
                items: _priorities.map((p) {
                  return DropdownMenuItem<String>(
                    value: p['value'],
                    child: Text(p['label']!, style: AppTextStyles.bodyMedium),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPriority = val);
                },
              ),
              const SizedBox(height: 16),

              // الرسالة التفصيلية
              Text('تفاصيل الاستفسار', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _messageController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'اكتب تفاصيل استفسارك أو المشكلة التي تواجهها بوضوح...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderHairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderHairline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 10) {
                    return 'يرجى تقديم تفاصيل كافية (على الأقل 10 أحرف)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // المرفقات
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'مرفقات توضيحية (اختياري)',
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                  ),
                  TextButton.icon(
                    onPressed: _pickAttachment,
                    icon: const Icon(PhosphorIconsRegular.paperclip, size: 16),
                    label: const Text('إضافة صورة', style: TextStyle(fontSize: 12.5)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              if (_attachmentPaths.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_attachmentPaths.length, (index) {
                    final path = _attachmentPaths[index];
                    final name = path.split(Platform.pathSeparator).last;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(PhosphorIconsRegular.fileImage, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => _removeAttachment(index),
                            child: const Icon(PhosphorIconsRegular.x, size: 14, color: AppColors.error),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ],
              const SizedBox(height: 24),

              // زر الإرسال
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'إرسال التذكرة',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_validators.dart';
import '../../../core/utils/network_error_mapper.dart';
import '../../../models/assignment.dart';
import '../../../models/assignment_submission.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/student_learning_repository.dart';

class SubmitAssignmentSheet extends StatefulWidget {
  final Assignment assignment;
  final UserModel user;

  const SubmitAssignmentSheet({
    super.key,
    required this.assignment,
    required this.user,
  });

  @override
  State<SubmitAssignmentSheet> createState() => _SubmitAssignmentSheetState();
}

class _SubmitAssignmentSheetState extends State<SubmitAssignmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _solutionController = TextEditingController();
  final _linkController = TextEditingController();
  File? _pickedImageAttachment;
  bool _isSubmitting = false;
  String _statusMessage = 'جاري إرسال تسليم التكليف...';

  StudentLearningRepository get _repository =>
      sl.isRegistered<StudentLearningRepository>()
          ? sl<StudentLearningRepository>()
          : StudentLearningRepositoryImpl();

  @override
  void dispose() {
    _solutionController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachmentImage() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('تنبيه المرفقات المباشرة'),
          ],
        ),
        content: const Text(
          'ميزة الرفع المباشر لملفات الصور من الجهاز غير مدعومة حالياً في واجهة خادم المنصة (تقتصر الواجهة على التسجيلات الصوتية).\n\n'
          'يمكنك بكل سهولة إرفاق رابط خارجي لملف ورقة العمل أو الصور (عبر Google Drive أو OneDrive) في حقل (رابط ملف خارجي) أدناه ليتمكن المشرف من مراجعته.',
          style: TextStyle(height: 1.5, fontSize: 13.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً، سأستخدم الرابط'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final solution = _solutionController.text.trim();
    final link = _linkController.text.trim();
    final parentMessenger = ScaffoldMessenger.of(context);

    setState(() {
      _isSubmitting = true;
      _statusMessage = _pickedImageAttachment != null
          ? 'جاري ضغط ورفع المرفق وحفظ التسليم...'
          : 'جاري تسجيل تسليم التكليف سحابياً...';
    });

    try {
      final newSub = AssignmentSubmission(
        id: 'sub_${widget.user.uid}_${widget.assignment.id}',
        assignmentId: widget.assignment.id,
        assignmentTitle: widget.assignment.title,
        courseId: widget.assignment.courseId,
        studentId: widget.user.uid,
        studentName: widget.user.displayName,
        studentEmail: widget.user.email,
        solutionText: solution,
        attachmentUrl: link,
        maxScore: widget.assignment.maxScore,
        submittedAt: DateTime.now(),
      );

      await _repository.submitAssignment(
        submission: newSub,
        attachmentFile: _pickedImageAttachment,
      );

      if (mounted) {
        Navigator.pop(context);
      }
      parentMessenger.showSnackBar(
        const SnackBar(
          content: Text(
            'تم تسليم المهمة التطبيقية بنجاح، ويمكنك الآن متابعة الدرس التالي فوراً.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final arabicMsg = NetworkErrorMapper.toArabicMessage(
          e,
          defaultMessage: 'تعذر إرسال التكليف حالياً، يرجى المحاولة مرة أخرى.',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(arabicMsg),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.assignment_turned_in_outlined,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تسليم تكليف: ${widget.assignment.title}',
                            style: AppTextStyles.heading3.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    if (widget.assignment.instructions.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.scaffoldBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderHairline),
                        ),
                        child: Text(
                          widget.assignment.instructions,
                          style: AppTextStyles.bodyMedium,
                        ),
                      ),
                    ],
                    if (widget.assignment.hasAttachment) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.picture_as_pdf_rounded,
                              color: Color(0xFFDC2626),
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.assignment.pdfAttachmentName ?? 'ملف ورقة عمل التكليف (PDF)',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF991B1B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'مرفق معتمد من المدرب لمساعدتك في إنجاز المهمة',
                                    style: AppTextStyles.caption.copyWith(
                                      color: const Color(0xFFB91C1C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                                side: const BorderSide(color: Color(0xFFDC2626)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                alignment: Alignment.center,
                              ),
                              icon: const Icon(Icons.download_rounded, size: 16),
                              label: const Text('فتح / تنزيل'),
                              onPressed: () {
                                final uri = Uri.tryParse(widget.assignment.attachmentUrl);
                                if (uri != null) {
                                  launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'الإجابة أو ملاحظات الجلسة التطبيقية *',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _solutionController,
                      enabled: !_isSubmitting,
                      maxLines: 4,
                      validator: (v) => AppValidators.validateRequired(v, 'إجابتك على التكليف'),
                      decoration: const InputDecoration(
                        hintText:
                            'اكتب خطوات التدريب التطبيقي أو ملاحظات الحالة بالتفصيل...',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              alignment: Alignment.center,
                            ),
                            onPressed: _isSubmitting ? null : _pickAttachmentImage,
                            icon: const Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                            label: const Text(
                              'إرفاق صورة مباشرة (غير متاح حالياً - استخدم الرابط أدناه)',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        if (_pickedImageAttachment != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'إزالة المرفق',
                            onPressed: _isSubmitting
                                ? null
                                : () => setState(() => _pickedImageAttachment = null),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _linkController,
                      enabled: !_isSubmitting,
                      textDirection: TextDirection.ltr,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        return AppValidators.validateUrl(v, 'الملف الخارجي');
                      },
                      decoration: const InputDecoration(
                        labelText: 'رابط ملف خارجي مثل Google Drive (اختياري)',
                        hintText: 'https://drive.google.com/...',
                        prefixIcon: Icon(Icons.link_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isSubmitting) ...[
                      Center(
                        child: Text(
                          _statusMessage,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          alignment: Alignment.center,
                        ),
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('إرسال التكليف للتقييم'),
                      ),
                    ),
                    if (_isSubmitting) ...[
                      const SizedBox(height: 6),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('إغلاق والمتابعة في الخلفية'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

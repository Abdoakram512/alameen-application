import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1280,
      maxHeight: 1600,
    );
    if (picked != null && mounted) {
      setState(() => _pickedImageAttachment = File(picked.path));
    }
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final solution = _solutionController.text.trim();
    final link = _linkController.text.trim();

    setState(() => _isSubmitting = true);

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم إرسال التكليف بنجاح، وستظهر نتيجة التقييم فور مراجعته من المحاضر.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
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
                            onPressed: _isSubmitting ? null : _pickAttachmentImage,
                            icon: Icon(
                              _pickedImageAttachment != null
                                  ? Icons.check_circle_rounded
                                  : Icons.attach_file_rounded,
                              size: 18,
                            ),
                            label: Text(
                              _pickedImageAttachment != null
                                  ? 'تم إرفاق صورة للتكليف'
                                  : 'إرفاق صورة ورقة عمل (اختياري)',
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
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
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

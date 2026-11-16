import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/painters/dashed_border_painter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_validators.dart';
import '../../../logic/access/access_cubit.dart';
import '../../../logic/access/access_state.dart';
import '../../../models/course.dart';
import '../../../models/user_profile.dart';

class RequestAccessSheet extends StatefulWidget {
  final Course course;
  final UserModel user;
  final bool isResubmission;

  const RequestAccessSheet({
    super.key,
    required this.course,
    required this.user,
    this.isResubmission = false,
  });

  @override
  State<RequestAccessSheet> createState() => _RequestAccessSheetState();
}

class _RequestAccessSheetState extends State<RequestAccessSheet> {
  final _formKey = GlobalKey<FormState>();
  String _selectedMethod = 'فودافون كاش (Vodafone Cash)';
  final _refController = TextEditingController();
  File? _pickedReceiptFile;
  bool _isSubmitting = false;

  static const _paymentMethods = [
    'طلب انضمام مباشر (بدون إيصال / موافقة الإدارة)',
    'فودافون كاش (Vodafone Cash)',
    'أورنج كاش (Orange Cash)',
    'اتصالات كاش (Etisalat Cash)',
    'وي باي (WE Pay)',
    'إنستاباي (InstaPay)',
    'تحويل بنكي مباشر',
    'سداد نقدي بمقر المركز',
  ];

  bool get _isDirectRequest => _selectedMethod.startsWith('طلب انضمام مباشر');
  bool get _isCashAtCenter => _selectedMethod == 'سداد نقدي بمقر المركز';

  @override
  void initState() {
    super.initState();
    _selectedMethod = _paymentMethods.first;
  }

  @override
  void dispose() {
    _refController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 55,
      maxWidth: 720,
      maxHeight: 960,
    );
    if (image != null && mounted) {
      setState(() => _pickedReceiptFile = File(image.path));
    }
  }

  void _submitDirectRequest() {
    HapticFeedback.mediumImpact();
    if (_isSubmitting) return;

    final rawRef = _refController.text.trim();
    setState(() => _isSubmitting = true);

    context.read<AccessCubit>().sendRequest(
          course: widget.course,
          user: widget.user,
          paymentMethod: 'طلب انضمام مباشر (موافقة الإدارة)',
          senderNumberOrRef: rawRef.isNotEmpty
              ? rawRef
              : (widget.user.phone.isNotEmpty
                  ? widget.user.phone
                  : 'طلب مباشر عبر التطبيق'),
          receiptFile: null,
        );
  }

  void _submit() {
    if (_isDirectRequest) {
      _submitDirectRequest();
      return;
    }

    HapticFeedback.mediumImpact();
    if (_isSubmitting) return;

    if (!_isCashAtCenter) {
      final isValid = _formKey.currentState?.validate() ?? false;
      if (!isValid) return;
    }

    final rawRef = _refController.text.trim();
    final normalizedRef = AppValidators.normalizeDigits(rawRef);

    setState(() => _isSubmitting = true);

    context.read<AccessCubit>().sendRequest(
          course: widget.course,
          user: widget.user,
          paymentMethod: _selectedMethod,
          senderNumberOrRef: normalizedRef.isNotEmpty
              ? normalizedRef
              : (_isCashAtCenter ? 'مراجعة خزينة المركز' : 'طلب بدون إيصال'),
          receiptFile: _pickedReceiptFile,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AccessCubit, AccessState>(
      listener: (context, state) {
        if (state is AccessActionSuccess) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop(true);
        } else if (state is AccessError) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      child: SafeArea(
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
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
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              PhosphorIconsRegular.receipt,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.isResubmission
                                  ? (context.locale.languageCode == 'ar'
                                      ? 'إعادة إرسال طلب التفعيل'
                                      : 'Resubmit Enrollment Request')
                                  : 'requests.sheet_title'.tr(),
                              style: AppTextStyles.heading3.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'dialogs.cancel'.tr(),
                            icon: const Icon(PhosphorIconsRegular.x, size: 20),
                            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderHairline),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'البرنامج التدريبي المختار',
                                    style: AppTextStyles.caption,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.course.title,
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                widget.course.priceFormatted,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'وسيلة السداد',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedMethod,
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: _paymentMethods
                            .map(
                              (m) => DropdownMenuItem<String>(
                                value: m,
                                child: Text(m),
                              ),
                            )
                            .toList(),
                        onChanged: _isSubmitting
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() => _selectedMethod = val);
                                }
                              },
                      ),
                      if (_isDirectRequest) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.successLight.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.successBorder),
                          ),
                          child: Row(
                            children: const [
                              Icon(
                                PhosphorIconsRegular.checkCircle,
                                color: AppColors.success,
                                size: 22,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'طلب مباشر بدون إيصال: سيصل طلبك فورياً لإدارة سنتر الأمين لتفعيله لك مباشرة دون الحاجة لرفع أي إيصالات.',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 12.5,
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        _isDirectRequest
                            ? 'رقم الهاتف للتواصل أو ملاحظة للمركز (اختياري)'
                            : (_isCashAtCenter
                                ? 'اسم السداد أو ملاحظة المقر (اختياري)'
                                : 'رقم المحفظة المحوّل منها أو الرقم المرجعي'),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _refController,
                        enabled: !_isSubmitting,
                        keyboardType: _isCashAtCenter || _isDirectRequest ? TextInputType.text : TextInputType.phone,
                        validator: (value) {
                          if (_isDirectRequest || _isCashAtCenter) return null;
                          if (_pickedReceiptFile != null && (value == null || value.trim().isEmpty)) {
                            // If receipt is attached, ref is optional
                            return null;
                          }
                          return AppValidators.validatePaymentIdentifier(value, _selectedMethod);
                        },
                        decoration: InputDecoration(
                          hintText: _isDirectRequest
                              ? (widget.user.phone.isNotEmpty ? widget.user.phone : 'مثال: 010XXXXXXXX أو اكتب ملاحظة للإدارة')
                              : (_isCashAtCenter
                                  ? 'مثال: تم السداد بفرع المركز أو رقم الإيصال الورقي'
                                  : 'مثال: 010XXXXXXXX أو اسم المستخدم بإنستاباي'),
                          prefixIcon: const Icon(
                            PhosphorIconsRegular.hash,
                            size: 19,
                          ),
                        ),
                      ),
                      if (!_isDirectRequest) ...[
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Text(
                              'صورة إيصال السداد',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.scaffoldBackground,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppColors.borderHairline),
                              ),
                              child: Text(
                                'اختياري مع الرقم',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_pickedReceiptFile != null) ...[
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(
                                  _pickedReceiptFile!,
                                  height: 148,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Material(
                                  color: Colors.black54,
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    tooltip: 'حذف الصورة',
                                    icon: const Icon(
                                      PhosphorIconsRegular.trash,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    onPressed: _isSubmitting
                                        ? null
                                        : () => setState(() => _pickedReceiptFile = null),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else
                          CustomPaint(
                            painter: DashedBorderPainter(
                              color: AppColors.borderHairline,
                              strokeWidth: 1.4,
                              dashLength: 7,
                              dashGap: 5,
                              radius: 14,
                            ),
                            child: InkWell(
                              onTap: _isSubmitting ? null : _pickImage,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryLight,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        PhosphorIconsRegular.cloudArrowUp,
                                        size: 22,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'إرفاق صورة الإيصال (اختياري)',
                                            style: AppTextStyles.bodyMedium.copyWith(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'يمكنك إرفاق لقطة شاشة للتحويل البنكي أو رسالة المحفظة لتسريع اعتماد الطلب',
                                            style: AppTextStyles.caption.copyWith(
                                              fontSize: 11.5,
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
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
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
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      PhosphorIconsRegular.paperPlaneTilt,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.isResubmission
                                          ? (context.locale.languageCode == 'ar'
                                              ? 'إعادة إرسال الطلب للمراجعة'
                                              : 'Resubmit for Review')
                                          : (_isDirectRequest
                                              ? 'إرسال طلب الانضمام المباشر للأدمن'
                                              : 'requests.submit_btn'.tr()),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

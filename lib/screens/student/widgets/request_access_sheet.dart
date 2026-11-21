import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/painters/dashed_border_painter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../features/payments/domain/entities/payment_method.dart';
import '../../../features/payments/domain/entities/receipt_submission_input.dart';
import '../../../features/payments/presentation/cubits/receipt_submission/receipt_submission_cubit.dart';
import '../../../features/payments/presentation/cubits/receipt_submission/receipt_submission_state.dart';
import '../../../models/course.dart';
import '../../../models/user_profile.dart';

enum _SheetPaymentOption {
  vodafoneCash('فودافون كاش ومحافظ المحمول (Vodafone Cash)'),
  instapay('إنستاباي (InstaPay)'),
  cashAtCenter('سداد نقدي بمقر سنتر الأمين');

  final String label;
  const _SheetPaymentOption(this.label);
}

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
  _SheetPaymentOption _selectedOption = _SheetPaymentOption.vodafoneCash;
  late final TextEditingController _nameController;
  late final TextEditingController _accountController;
  late final TextEditingController _amountController;
  late final TextEditingController _refController;
  File? _pickedReceiptFile;

  bool get _isCashAtCenter =>
      _selectedOption == _SheetPaymentOption.cashAtCenter;
  bool get _isInstaPay => _selectedOption == _SheetPaymentOption.instapay;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.displayName);
    // لا يتم ملء حساب المحول تلقائياً برقم هاتف الحساب لتفادي الإرسال الوهمي
    _accountController = TextEditingController();
    _amountController = TextEditingController(
      text: widget.course.price > 0
          ? widget.course.price.toStringAsFixed(
              widget.course.price.truncateToDouble() == widget.course.price
                  ? 0
                  : 2,
            )
          : '',
    );
    _refController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accountController.dispose();
    _amountController.dispose();
    _refController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 65,
        maxWidth: 1200,
        maxHeight: 1600,
      );
      if (image != null && mounted) {
        setState(() => _pickedReceiptFile = File(image.path));
      }
    } on PlatformException {
      if (mounted) {
        _showErrorSnackBar(
          context,
          '\u062a\u0639\u0630\u0631 \u0627\u062e\u062a\u064a\u0627\u0631 \u0627\u0644\u0635\u0648\u0631\u0629. \u062a\u062d\u0642\u0642 \u0645\u0646 \u0635\u0644\u0627\u062d\u064a\u0627\u062a \u0627\u0644\u0635\u0648\u0631 \u0648\u062d\u0627\u0648\u0644 \u0645\u062c\u062f\u062f\u0627.',
        );
      }
    }
  }

  void _submit() {
    if (context.read<ReceiptSubmissionCubit>().state
        is ReceiptSubmissionInProgress) {
      return;
    }
    if (_isCashAtCenter) {
      AppConstants.launchWhatsApp(
        customMessage:
            'السلام عليكم، أود سداد رسوم دورة "${widget.course.title}" بمقر السنتر لحساب الطالب ${widget.user.displayName}.',
      );
      Navigator.pop(context);
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final parsedAmount = double.tryParse(
      AppValidators.normalizeDigits(_amountController.text.trim()),
    );

    final courseSlug =
        (widget.course.slug != null && widget.course.slug!.trim().isNotEmpty)
        ? widget.course.slug!.trim()
        : widget.course.id;

    final input = ReceiptSubmissionInput(
      courseSlug: courseSlug,
      courseId: widget.course.id,
      courseTitle: widget.course.title,
      paymentMethod: _isInstaPay
          ? PaymentMethod.instapay
          : PaymentMethod.vodafoneCash,
      senderName: _nameController.text.trim(),
      senderAccount: AppValidators.normalizeDigits(
        _accountController.text.trim(),
      ),
      amount: parsedAmount,
      receiptFilePath: _pickedReceiptFile?.path ?? '',
      transactionReference: _refController.text.trim().isNotEmpty
          ? _refController.text.trim()
          : null,
    );

    HapticFeedback.mediumImpact();
    context.read<ReceiptSubmissionCubit>().submit(input);
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReceiptSubmissionCubit, ReceiptSubmissionState>(
      listener: (context, state) {
        switch (state) {
          case ReceiptSubmissionSuccess(message: final msg):
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.of(context).pop(true);
          case ReceiptSubmissionValidationFailure(message: final msg):
            _showErrorSnackBar(context, msg);
          case ReceiptSubmissionNetworkFailure(message: final msg):
            _showErrorSnackBar(context, msg);
          case ReceiptSubmissionFailure(failure: final failure):
            _showErrorSnackBar(context, failure.message);
          default:
            break;
        }
      },
      builder: (context, state) {
        final isSubmitting = state is ReceiptSubmissionInProgress;

        return SafeArea(
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 540,
                maxHeight: MediaQuery.sizeOf(context).height * 0.90,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      margin: const EdgeInsets.only(top: 14, bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    child: Row(
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
                                      ? 'إعادة إرسال إيصال السداد'
                                      : 'Resubmit Payment Receipt')
                                : 'requests.sheet_title'.tr(),
                            style: AppTextStyles.heading3.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'dialogs.cancel'.tr(),
                          icon: const Icon(
                            PhosphorIconsRegular.x,
                            size: 20,
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Divider(height: 1, color: AppColors.divider),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        top: 16,
                        left: 20,
                        right: 20,
                        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(
                              alpha: 0.65,
                            ),
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
                        const SizedBox(height: 16),
                        Text(
                          'وسيلة السداد المعتمدة',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<_SheetPaymentOption>(
                          initialValue: _selectedOption,
                          isExpanded: true,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          items: _SheetPaymentOption.values
                              .map(
                                (m) => DropdownMenuItem<_SheetPaymentOption>(
                                  value: m,
                                  child: Text(m.label),
                                ),
                              )
                              .toList(),
                          onChanged: isSubmitting
                              ? null
                              : (val) {
                                  if (val != null) {
                                    setState(() => _selectedOption = val);
                                  }
                                },
                        ),
                        const SizedBox(height: 16),
                        if (_isCashAtCenter) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.warningLight.withValues(
                                alpha: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.warningBorder,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      PhosphorIconsRegular.mapPin,
                                      color: AppColors.warningDark,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'السداد النقدي بمقر المركز',
                                      style: TextStyle(
                                        color: AppColors.warningDark,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'يمكنك زيارة مقر سنتر الأمين للتخاطب والسداد نقداً في الخزينة، وسيتم تفعيل الدورة التدريبية لحسابك فوراً من قبل الإدارة.',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF25D366),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    icon: const Icon(
                                      PhosphorIconsRegular.whatsappLogo,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'تواصل معنا عبر واتساب للتنسيق',
                                    ),
                                    onPressed: () {
                                      AppConstants.launchWhatsApp(
                                        customMessage:
                                            'السلام عليكم، أرغب في الحضور لمقر المركز لسداد رسوم دورة "${widget.course.title}".',
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Text(
                            'اسم المحوّل / صاحب الحساب',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            enabled: !isSubmitting,
                            keyboardType: TextInputType.name,
                            validator: (value) =>
                                AppValidators.validateRequired(
                                  value,
                                  'اسم صاحب الحساب المحول منه',
                                ),
                            decoration: const InputDecoration(
                              hintText: 'مثال: أحمد محمد علي',
                              prefixIcon: Icon(
                                PhosphorIconsRegular.user,
                                size: 19,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isInstaPay
                                ? 'عنوان الدفع اللحظي (IPA) أو رقم الهاتف بإنستاباي'
                                : 'رقم محفظة فودافون كاش المحول منها',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _accountController,
                            enabled: !isSubmitting,
                            keyboardType: _isInstaPay
                                ? TextInputType.text
                                : TextInputType.phone,
                            validator: (value) {
                              return AppValidators.validatePaymentIdentifier(
                                value,
                                _selectedOption.label,
                              );
                            },
                            decoration: InputDecoration(
                              hintText: _isInstaPay
                                  ? 'مثال: username@instapay أو 010XXXXXXXX'
                                  : 'مثال: 010XXXXXXXX',
                              prefixIcon: const Icon(
                                PhosphorIconsRegular.deviceMobile,
                                size: 19,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'المبلغ المدفوع (ج.م)',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _amountController,
                                      enabled: !isSubmitting,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      validator: (value) =>
                                          AppValidators.validateNumber(
                                            value,
                                            'المبلغ المدفوع',
                                            1,
                                          ),
                                      decoration: const InputDecoration(
                                        hintText: 'أدخل المبلغ الفعلي',
                                        prefixIcon: Icon(
                                          PhosphorIconsRegular.currencyDollar,
                                          size: 19,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'رقم العملية (اختياري)',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _refController,
                                      enabled: !isSubmitting,
                                      keyboardType: TextInputType.text,
                                      decoration: const InputDecoration(
                                        hintText: 'المرجع أو Ref',
                                        prefixIcon: Icon(
                                          PhosphorIconsRegular.hash,
                                          size: 19,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Text(
                                'صورة إيصال السداد أو لقطة الشاشة',
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
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'مطلوب',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
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
                                    height: 160,
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
                                      onPressed: isSubmitting
                                          ? null
                                          : () => setState(
                                              () => _pickedReceiptFile = null,
                                            ),
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
                                onTap: isSubmitting ? null : _pickImage,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                    horizontal: 16,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Icon(
                                          PhosphorIconsRegular.cloudArrowUp,
                                          size: 24,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'اضغط لإرفاق صورة إيصال التحويل',
                                              style: AppTextStyles.bodyMedium
                                                  .copyWith(
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              'لقطة شاشة للتحويل من تطبيق إنستاباي أو رسالة المحفظة (JPG, PNG, WEBP حتى 5 ميجابايت)',
                                              style: AppTextStyles.caption
                                                  .copyWith(fontSize: 11.5),
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
                        if (state is ReceiptSubmissionValidationFailure ||
                            state is ReceiptSubmissionNetworkFailure ||
                            state is ReceiptSubmissionFailure)
                          Text(switch (state) {
                            ReceiptSubmissionValidationFailure(
                              :final message,
                            ) =>
                              message,
                            ReceiptSubmissionNetworkFailure(:final message) =>
                              message,
                            ReceiptSubmissionFailure(:final failure) =>
                              failure.message,
                            _ => '',
                          }, style: const TextStyle(color: AppColors.error)),
                        const SizedBox(height: 24),
                        AppButton(
                          text: widget.isResubmission
                              ? (context.locale.languageCode == 'ar'
                                    ? 'إعادة إرسال الإيصال للمراجعة'
                                    : 'Resubmit Receipt for Review')
                              : (_isCashAtCenter
                                    ? 'تواصل لتأكيد السداد بالمقر'
                                    : 'requests.submit_btn'.tr()),
                          isLoading: isSubmitting,
                          height: 50,
                          icon: Icon(
                            _isCashAtCenter
                                ? PhosphorIconsRegular.whatsappLogo
                                : PhosphorIconsRegular.paperPlaneTilt,
                            size: 18,
                            color: Colors.white,
                          ),
                          onPressed: isSubmitting ? null : _submit,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
      },
    );
  }
}

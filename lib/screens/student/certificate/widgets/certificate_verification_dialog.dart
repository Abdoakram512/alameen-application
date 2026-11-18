import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/course_certificate.dart';
import '../../../../repositories/student_certificates_repository.dart';

/// نافذة منبثقة للتحقق العام من مصداقية الشهادة مباشرة عبر واجهة خادم Laravel
/// GET /public/certificates/verify/{code}
class CertificateVerificationDialog extends StatefulWidget {
  final String certificateCode;

  const CertificateVerificationDialog({
    super.key,
    required this.certificateCode,
  });

  static Future<void> show(BuildContext context, String certificateCode) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => CertificateVerificationDialog(
        certificateCode: certificateCode,
      ),
    );
  }

  @override
  State<CertificateVerificationDialog> createState() =>
      _CertificateVerificationDialogState();
}

class _CertificateVerificationDialogState
    extends State<CertificateVerificationDialog> {
  bool _isLoading = true;
  CertificateVerificationResult? _result;
  String? _errorMessage;

  StudentCertificatesRepository get _repository =>
      sl.isRegistered<StudentCertificatesRepository>()
          ? sl<StudentCertificatesRepository>()
          : StudentCertificatesRepositoryImpl();

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _repository.verifyCertificate(widget.certificateCode);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _result = res;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'تعذر الاتصال بخادم التحقق من الشهادات. تحقق من اتصالك بالإنترنت وأعد المحاولة.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B192C).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.verified_outlined,
                      color: Color(0xFF0B192C),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'التحقق الأكاديمي من الشهادة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0B192C),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              if (_isLoading) ...[
                const SizedBox(height: 20),
                const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFC5A059),
                    strokeWidth: 2.5,
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'جاري التحقق من السجل الرسمي في قاعدة بيانات مركز الأمين...',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 20),
              ] else if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                const Icon(
                  Icons.wifi_off_rounded,
                  color: AppColors.error,
                  size: 46,
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.error),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: _verify,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('إعادة المحاولة'),
                ),
              ] else if (_result != null) ...[
                if (_result!.valid) ...[
                  // الشهادة صالحة ومعتمدة
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF059669),
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _result!.message,
                            style: const TextStyle(
                              color: Color(0xFF065F46),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (_result!.certificate != null) ...[
                    _buildInfoRow('رقم الاعتماد:', _result!.certificate!.certificateCode),
                    if (_result!.certificate!.studentName.isNotEmpty)
                      _buildInfoRow('المتدرب:', _result!.certificate!.studentName),
                    if (_result!.certificate!.courseTitle.isNotEmpty)
                      _buildInfoRow('البرنامج:', _result!.certificate!.courseTitle),
                    _buildInfoRow(
                      'تاريخ الاعتماد:',
                      DateFormat('yyyy/MM/dd', 'ar').format(_result!.certificate!.issuedAt),
                    ),
                    if (_result!.certificate!.signatoryName != null)
                      _buildInfoRow('المعتمد:', _result!.certificate!.signatoryName!),
                  ],

                  const SizedBox(height: 16),
                  if (_result!.certificate?.verificationUrl.isNotEmpty == true)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0B192C),
                        side: const BorderSide(color: Color(0xFF0B192C)),
                      ),
                      onPressed: () {
                        final uri = Uri.tryParse(_result!.certificate!.verificationUrl);
                        if (uri != null) {
                          launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('عرض صفحة التحقق العامة'),
                    ),
                ] else ...[
                  // الشهادة غير صالحة أو غير مسجلة
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cancel_rounded,
                          color: Color(0xFFDC2626),
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _result!.message,
                            style: const TextStyle(
                              color: Color(0xFF991B1B),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'الرمز الذي تم التحقق منه: ${widget.certificateCode}',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF111827),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:printing/printing.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/course_certificate.dart';
import '../../../repositories/student_certificates_repository.dart';
import 'widgets/certificate_verification_dialog.dart';

/// شاشة عرض وتحميل ومشاركة شهادة إتمام الدورة المعتمدة رسمياً عبر خادم Laravel
class CourseCertificateScreen extends StatefulWidget {
  final CourseCertificate certificate;

  const CourseCertificateScreen({
    super.key,
    required this.certificate,
  });

  @override
  State<CourseCertificateScreen> createState() =>
      _CourseCertificateScreenState();
}

class _CourseCertificateScreenState extends State<CourseCertificateScreen> {
  bool _isExporting = false;

  StudentCertificatesRepository get _repository =>
      sl.isRegistered<StudentCertificatesRepository>()
          ? sl<StudentCertificatesRepository>()
          : StudentCertificatesRepositoryImpl();

  Future<void> _downloadPdf() async {
    if (_isExporting) return;

    final fileUrl = widget.certificate.fileUrl;
    if (fileUrl == null || fileUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ملف الـ PDF الرسمي للشهادة لم يصدر بعد على خادم المنصة. يرجى مراجعة إدارة المركز.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      HapticFeedback.mediumImpact();
      final pdfBytes = await _repository.downloadOfficialCertificatePdf(fileUrl);
      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'شهادة_مركز_الأمين_${widget.certificate.certificateCode}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحميل ملف الشهادة الرسمي: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _sharePdf() async {
    if (_isExporting) return;

    final fileUrl = widget.certificate.fileUrl;
    if (fileUrl == null || fileUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ملف الـ PDF الرسمي للشهادة غير متاح للمشاركة حالياً من الخادم.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      HapticFeedback.lightImpact();
      final pdfBytes = await _repository.downloadOfficialCertificatePdf(fileUrl);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'شهادة_مركز_الأمين_${widget.certificate.certificateCode}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر مشاركة الشهادة: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cert = widget.certificate;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final formattedDate =
        DateFormat('yyyy/MM/dd', 'ar').format(cert.issuedAt);

    return Scaffold(
      backgroundColor: const Color(0xFF0B192C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          isAr ? 'الشهادة المعتمدة' : 'Official Certificate',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.shareNetwork),
            tooltip: isAr ? 'مشاركة' : 'Share',
            onPressed: _isExporting ? null : _sharePdf,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              // Certificate Canvas Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFFCFCF9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFC5A059),
                    width: 3.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF0B192C),
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Column(
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Verification ID
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'رقم الاعتماد:',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    cert.serialNumber,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0B192C),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(
                                        ClipboardData(text: cert.serialNumber),
                                      );
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('تم نسخ رقم الاعتماد'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                    child: const Icon(
                                      Icons.copy_rounded,
                                      size: 14,
                                      color: Color(0xFFC5A059),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Center Logo
                          Image.asset(
                            'assets/images/logo.png',
                            width: 46,
                            height: 46,
                            errorBuilder: (context, error, stackTrace) => Image.asset(
                              'assets/images/website-logo.png',
                              width: 46,
                              height: 46,
                              errorBuilder: (ctx, err, st) => const Icon(
                                Icons.school_rounded,
                                size: 40,
                                color: Color(0xFF0B192C),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Center Title
                      const Text(
                        'مـركـز الأمـيـن لـلـتـخـاطـب',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0B192C),
                        ),
                      ),
                      const Text(
                        'AL-AMEEN CENTER FOR SPEECH TRAINING & REHABILITATION',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFC5A059),
                          letterSpacing: 1.1,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Certificate Banner
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B192C),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'شـهـادة إتـمـام دورة تـدريـبـيـة',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFC5A059),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      const Text(
                        'يشهد مركز الأمين للتخاطب بأن المتدرب / ـة:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Student Name
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Color(0xFFC5A059),
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          cert.studentName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0B192C),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'قد اجتاز/ت بنجاح واقتدار متطلبات البرنامج التدريبي المتخصص:',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Course Name Box
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Text(
                          cert.courseTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3E62),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        'بنسبة حضور وإنجاز متميزة بلغت ${cert.completionPercentage.toStringAsFixed(0)}% من إجمالي البرنامج',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFC5A059),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Bottom Signatures Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Date
                          Column(
                            children: [
                              const Text(
                                'تاريخ الاعتماد',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formattedDate,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0B192C),
                                ),
                              ),
                            ],
                          ),

                          // Seal Badge
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFC5A059),
                                width: 2,
                              ),
                            ),
                            child: const Column(
                              children: [
                                Text(
                                  'الختم الرسمي',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Color(0xFFC5A059),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'مـعـتـمـد',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0B192C),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Director
                          Column(
                            children: [
                              const Text(
                                'المشرف العام',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                cert.instructorName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0B192C),
                                ),
                              ),
                              Container(
                                width: 80,
                                height: 1,
                                color: const Color(0xFFC5A059),
                                margin: const EdgeInsets.only(top: 2),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC5A059),
                    foregroundColor: const Color(0xFF0B192C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isExporting ? null : _downloadPdf,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0B192C),
                          ),
                        )
                      : const Icon(
                          PhosphorIconsFill.filePdf,
                          size: 22,
                        ),
                  label: Text(
                    _isExporting
                        ? 'جاري تنزيل ملف PDF الرسمي...'
                        : (isAr
                            ? 'تحميل الشهادة الرسمية من الخادم (PDF)'
                            : 'Download Official Certificate PDF'),
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFC5A059)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isExporting ? null : _sharePdf,
                  icon: const Icon(PhosphorIconsRegular.shareNetwork, size: 20),
                  label: Text(
                    isAr ? 'مشاركة ملف الشهادة' : 'Share Certificate',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC5A059),
                    side: const BorderSide(color: Color(0xFFC5A059), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => CertificateVerificationDialog.show(
                    context,
                    widget.certificate.certificateCode,
                  ),
                  icon: const Icon(Icons.verified_user_outlined, size: 20),
                  label: Text(
                    isAr
                        ? 'التحقق الأكاديمي المباشر من الخادم (Verify)'
                        : 'Verify Authenticity on Laravel',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/course_certificate.dart';

/// خدمة توليد وتصدير وتحميل شهادات إتمام الدورات التدريبية كملف PDF رسمي عالي الدقة
class CertificatePdfService {
  static const PdfColor royalNavy = PdfColor.fromInt(0xFF0B192C);
  static const PdfColor darkNavy = PdfColor.fromInt(0xFF1E3E62);
  static const PdfColor luxuryGold = PdfColor.fromInt(0xFFC5A059);
  static const PdfColor lightGold = PdfColor.fromInt(0xFFE8D4A2);
  static const PdfColor creamBackground = PdfColor.fromInt(0xFFFCFCF9);
  static const PdfColor textDark = PdfColor.fromInt(0xFF1F2937);
  static const PdfColor textMuted = PdfColor.fromInt(0xFF6B7280);

  /// توليد بايتات ملف الـ PDF للشهادة المعتمدة بدقة Vector
  static Future<Uint8List> generateCertificatePdf(
    CourseCertificate certificate,
  ) async {
    final pdf = pw.Document();

    // تحميل خط القاهرة العربي للأجهزة
    final fontData = await rootBundle.load('assets/fonts/Cairo.ttf');
    final cairoFont = pw.Font.ttf(fontData);

    // تحميل شعار مركز الأمين
    Uint8List? logoBytes;
    try {
      final logoData = await rootBundle.load('assets/images/logo.png');
      logoBytes = logoData.buffer.asUint8List();
    } catch (_) {
      try {
        final logoData = await rootBundle.load('assets/images/website-logo.png');
        logoBytes = logoData.buffer.asUint8List();
      } catch (_) {}
    }

    final formattedDate =
        DateFormat('yyyy/MM/dd', 'ar').format(certificate.issuedAt);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(18),
        theme: pw.ThemeData.withFont(base: cairoFont, bold: cairoFont),
        build: (context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              decoration: pw.BoxDecoration(
                color: creamBackground,
                border: pw.Border.all(color: luxuryGold, width: 3.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
              ),
              padding: const pw.EdgeInsets.all(12),
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: royalNavy, width: 1.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 20,
                ),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // Header with Center Brand and Logo
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        // Left side text: Verification serial
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'رقم التحقق والاعتماد:',
                              style: pw.TextStyle(
                                font: cairoFont,
                                fontSize: 9,
                                color: textMuted,
                              ),
                            ),
                            pw.Text(
                              certificate.serialNumber,
                              style: pw.TextStyle(
                                font: cairoFont,
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: royalNavy,
                              ),
                            ),
                          ],
                        ),

                        // Center: Center Name & Title
                        pw.Column(
                          children: [
                            pw.Text(
                              'مـركـز الأمـيـن لـلـتـخـاطـب',
                              style: pw.TextStyle(
                                font: cairoFont,
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                color: royalNavy,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'AL-AMEEN CENTER FOR SPEECH TRAINING & REHABILITATION',
                              style: const pw.TextStyle(
                                fontSize: 8.5,
                                color: luxuryGold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),

                        // Right: Center Logo
                        if (logoBytes != null)
                          pw.Container(
                            width: 50,
                            height: 50,
                            child: pw.Image(pw.MemoryImage(logoBytes)),
                          )
                        else
                          pw.SizedBox(width: 50, height: 50),
                      ],
                    ),

                    pw.SizedBox(height: 8),

                    // Certificate Title Banner
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 6,
                      ),
                      decoration: pw.BoxDecoration(
                        color: royalNavy,
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(6),
                        ),
                      ),
                      child: pw.Text(
                        'شـهـادة إتـمـام دورة تـدريـبـيـة',
                        style: pw.TextStyle(
                          font: cairoFont,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: luxuryGold,
                        ),
                      ),
                    ),

                    pw.SizedBox(height: 10),

                    // Testimonial line
                    pw.Text(
                      'يشهد مركز الأمين للتخاطب بأن المتدرب / ـة:',
                      style: pw.TextStyle(
                        font: cairoFont,
                        fontSize: 12,
                        color: textDark,
                      ),
                    ),

                    // Student Name
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 4,
                      ),
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(color: luxuryGold, width: 2),
                        ),
                      ),
                      child: pw.Text(
                        certificate.studentName,
                        style: pw.TextStyle(
                          font: cairoFont,
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: royalNavy,
                        ),
                      ),
                    ),

                    pw.SizedBox(height: 8),

                    // Statement
                    pw.Text(
                      'قد اجتاز/ت بنجاح واقتدار كافة متطلبات البرنامج التدريبي المتخصص:',
                      style: pw.TextStyle(
                        font: cairoFont,
                        fontSize: 12,
                        color: textDark,
                      ),
                    ),

                    // Course Title
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor.fromInt(0xFFF3F4F6),
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(4),
                        ),
                      ),
                      child: pw.Text(
                        certificate.courseTitle,
                        style: pw.TextStyle(
                          font: cairoFont,
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                          color: darkNavy,
                        ),
                      ),
                    ),

                    // Completion criteria
                    pw.Text(
                      'بنسبة إنجاز وحضور مكتملة للمحاضرات التدريبية بلغت ${certificate.completionPercentage.toStringAsFixed(0)}% من إجمالي الدورة',
                      style: pw.TextStyle(
                        font: cairoFont,
                        fontSize: 10.5,
                        color: luxuryGold,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),

                    pw.SizedBox(height: 12),

                    // Footer Row with Signatures & Seal
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        // Date of issue
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(
                              'تاريخ الاعتماد والإصدار',
                              style: pw.TextStyle(
                                font: cairoFont,
                                fontSize: 10,
                                color: textMuted,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              formattedDate,
                              style: pw.TextStyle(
                                font: cairoFont,
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: royalNavy,
                              ),
                            ),
                          ],
                        ),

                        // Center Official Seal Crest
                        pw.Container(
                          padding: const pw.EdgeInsets.all(10),
                          decoration: pw.BoxDecoration(
                            shape: pw.BoxShape.circle,
                            border: pw.Border.all(
                              color: luxuryGold,
                              width: 2.5,
                            ),
                          ),
                          child: pw.Column(
                            children: [
                              pw.Text(
                                'الختم الرسمي',
                                style: pw.TextStyle(
                                  font: cairoFont,
                                  fontSize: 8.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: luxuryGold,
                                ),
                              ),
                              pw.Text(
                                'مـعـتـمـد',
                                style: pw.TextStyle(
                                  font: cairoFont,
                                  fontSize: 11,
                                  fontWeight: pw.FontWeight.bold,
                                  color: royalNavy,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Instructor & Director Signature
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(
                              'المشرف العام والمدير الأكاديمي',
                              style: pw.TextStyle(
                                font: cairoFont,
                                fontSize: 10,
                                color: textMuted,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              certificate.instructorName,
                              style: pw.TextStyle(
                                font: cairoFont,
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: royalNavy,
                              ),
                            ),
                            pw.Container(
                              width: 100,
                              height: 1,
                              color: luxuryGold,
                              margin: const pw.EdgeInsets.only(top: 2),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// فتح نافذة التحميل أو الطباعة أو المشاركة للشهادة PDF مباشرة
  static Future<void> downloadOrPrintCertificate(
    CourseCertificate certificate,
  ) async {
    final pdfBytes = await generateCertificatePdf(certificate);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name:
          'شهادة_${certificate.courseTitle}_${certificate.studentName}.pdf',
    );
  }

  /// مشاركة ملف الـ PDF للشهادة عبر التطبيقات
  static Future<void> shareCertificatePdf(
    CourseCertificate certificate,
  ) async {
    final pdfBytes = await generateCertificatePdf(certificate);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename:
          'شهادة_مركز_الأمين_${certificate.courseTitle}.pdf',
    );
  }
}

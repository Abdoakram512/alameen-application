import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/assignment_submission.dart';
import '../models/course.dart';
import '../models/registered_student.dart';

class CourseAuditPdfService {
  CourseAuditPdfService._();

  /// إنشاء وطباعة تقرير PDF رسمي لحضور وإنجازات المتدربين في الدورة التدريبية
  static Future<void> generateAndPrintReport({
    required Course course,
    required List<RegisteredStudent> students,
    required List<AssignmentSubmission> submissions,
  }) async {
    final pdf = pw.Document();

    // تحميل خط القاهرة لدعم اللغة العربية وتشكيل الحروف بشكل صحيح
    final fontData = await rootBundle.load('assets/fonts/Cairo.ttf');
    final cairoFont = pw.Font.ttf(fontData);

    // تحميل شعار مركز الأمين
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    final now = DateTime.now();
    final reportDate =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

    // إجمالي دروس الدورة
    final totalCourseLessons = course.totalLessonsCount;
    final lessonIds = course.allLessonIds;

    // حساب نسبة الحضور الإجمالية للدورة
    double overallAttendanceSum = 0.0;
    for (final s in students) {
      if (totalCourseLessons > 0) {
        final comp = s.completedLessonIds
            .where(lessonIds.contains)
            .length;
        overallAttendanceSum += (comp / totalCourseLessons);
      }
    }
    final avgCourseAttendancePercent = students.isNotEmpty
        ? ((overallAttendanceSum / students.length) * 100).toStringAsFixed(1)
        : '0.0';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        theme: pw.ThemeData.withFont(
          base: cairoFont,
          bold: cairoFont,
        ),
        textDirection: pw.TextDirection.rtl,
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.blue900, width: 2),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'مركز الأمين للتخاطب والتأهيل',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'تقرير الحضور ونسب الإنجاز الأكاديمي والتقييمات الرسمية',
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                if (logoImage != null)
                  pw.Container(
                    width: 44,
                    height: 44,
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey300, width: 1),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'مركز الأمين للتخاطب والتأهيل - نظام التوثيق الأكاديمي المعتمد',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
                pw.Text(
                  'صفحة ${context.pageNumber} من ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) => [
          pw.SizedBox(height: 8),
          // كروت مؤشرات أداء الدورة التدريبية
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.blue200, width: 0.8),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 3,
                  child: _buildKpiBox('اسم الدورة', course.title, cairoFont),
                ),
                pw.Container(width: 1, height: 28, color: PdfColors.blue200),
                pw.Expanded(
                  flex: 2,
                  child: _buildKpiBox('المحاضر', course.instructor, cairoFont),
                ),
                pw.Container(width: 1, height: 28, color: PdfColors.blue200),
                pw.Expanded(
                  flex: 2,
                  child: _buildKpiBox('عدد المتدربين', '${students.length} متدرب', cairoFont),
                ),
                pw.Container(width: 1, height: 28, color: PdfColors.blue200),
                pw.Expanded(
                  flex: 2,
                  child: _buildKpiBox('المحاضرات', '$totalCourseLessons محاضرة', cairoFont),
                ),
                pw.Container(width: 1, height: 28, color: PdfColors.blue200),
                pw.Expanded(
                  flex: 2,
                  child: _buildKpiBox('متوسط الحضور', '$avgCourseAttendancePercent%', cairoFont),
                ),
                pw.Container(width: 1, height: 28, color: PdfColors.blue200),
                pw.Expanded(
                  flex: 2,
                  child: _buildKpiBox('تاريخ التقرير', reportDate, cairoFont),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // جدول كشف الحضور والتقييمات التفصيلي مع أوزان ثابتة ومحددة بدقة
          pw.TableHelper.fromTextArray(
            columnWidths: const {
              0: pw.FixedColumnWidth(24),  // م
              1: pw.FlexColumnWidth(2.6), // اسم المتدرب
              2: pw.FlexColumnWidth(3.0), // البريد الإلكتروني
              3: pw.FlexColumnWidth(1.6), // ساعات الحضور
              4: pw.FlexColumnWidth(1.5), // المحاضرات المكتملة
              5: pw.FlexColumnWidth(1.3), // نسبة الحضور
              6: pw.FlexColumnWidth(1.3), // المهام المسلمة
              7: pw.FlexColumnWidth(1.6), // متوسط التقييم
              8: pw.FlexColumnWidth(1.8), // حالة الشهادة
            },
            headers: [
              'م',
              'اسم المتدرب',
              'البريد الإلكتروني',
              'ساعات الحضور',
              'المحاضرات المكتملة',
              'نسبة الحضور',
              'المهام المسلمة',
              'متوسط التقييم',
              'حالة الشهادة',
            ],
            data: List.generate(students.length, (index) {
              final student = students[index];
              final completedInCourse = student.completedLessonIds
                  .where(lessonIds.contains)
                  .length;
              final attendanceRatio = totalCourseLessons > 0
                  ? (completedInCourse / totalCourseLessons) * 100
                  : 0.0;

              // تسليمات هذا الطالب الخاصة بالكورس
              final studentSubs = submissions.where((sub) =>
                  sub.studentId == student.id && sub.courseId == course.id).toList();
              final gradedSubs = studentSubs.where((s) => s.isGraded && s.score != null).toList();

              final avgScore = gradedSubs.isNotEmpty
                  ? (gradedSubs.map((s) => s.score!).reduce((a, b) => a + b) / gradedSubs.length).round()
                  : null;

              final isQualified = attendanceRatio >= 100.0 &&
                  (studentSubs.isEmpty || gradedSubs.length == studentSubs.length);

              return [
                '${index + 1}',
                student.name,
                student.email,
                student.watchTimeFormatted,
                '$completedInCourse من $totalCourseLessons',
                '${attendanceRatio.toStringAsFixed(0)}%',
                '${studentSubs.length}',
                avgScore != null ? '$avgScore / 100' : 'قيد التصحيح',
                isQualified ? 'مؤهل للشهادة' : 'مستمر في الدورة',
              ];
            }),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headerStyle: pw.TextStyle(
              font: cairoFont,
              fontWeight: pw.FontWeight.bold,
              fontSize: 9.5,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
            cellStyle: pw.TextStyle(font: cairoFont, fontSize: 8.5),
            cellAlignment: pw.Alignment.center,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4.5),
            rowDecoration: const pw.BoxDecoration(
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 20),

          // التوقيعات والاعتماد الرسمي
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('منسق التدريب والتسجيل', style: pw.TextStyle(font: cairoFont, fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 30),
                  pw.Text('........................................', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey400)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('الختم الرسمي لمركز الأمين', style: pw.TextStyle(font: cairoFont, fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 30),
                  pw.Text('........................................', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey400)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('يعتمد، إدارة مركز الأمين للتخاطب والتأهيل', style: pw.TextStyle(font: cairoFont, fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 30),
                  pw.Text('........................................', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey400)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    // معاينة أو طباعة التقرير بالنسق الأفقي الصريح والملزم
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      format: PdfPageFormat.a4.landscape,
      name: 'تقرير_حضور_${course.title.replaceAll(' ', '_')}.pdf',
    );
  }

  static pw.Widget _buildKpiBox(String title, String value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            title,
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            style: pw.TextStyle(font: font, fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
          ),
        ],
      ),
    );
  }
}

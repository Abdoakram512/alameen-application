import 'package:equatable/equatable.dart';
import '../core/converters/firestore_date_time_converter.dart';

/// توقيت ظهور التكليف بالنسبة لفيديو الدرس.
enum AssignmentTiming {
  /// يظهر مع الدرس أثناء المشاهدة (على مستوى الدرس).
  duringLesson,

  /// يظهر بعد انتهاء مشاهدة الدرس.
  afterLesson;

  static AssignmentTiming fromName(String? name) {
    for (final t in AssignmentTiming.values) {
      if (t.name == name) return t;
    }
    return AssignmentTiming.afterLesson;
  }
}

/// نموذج بيانات التكليف (Assignment)
class Assignment extends Equatable {
  final String id;
  final String courseId;
  final String courseTitle;
  final String levelId;
  final String lessonId;
  final String title;
  final String instructions;
  final int maxScore;
  final DateTime? deadline;
  final DateTime createdAt;
  final AssignmentTiming timing;

  /// رابط ملف مرفق أو ورقة عمل إضافية من قبل الإدارة
  final String attachmentUrl;

  /// اسم ملف الـ PDF المرفق (اختياري)
  final String? pdfAttachmentName;

  /// عند `true` لا يُفتح الدرس التالي قبل تسليم هذا التكليف.
  final bool blocksNextLesson;

  const Assignment({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    this.levelId = '',
    this.lessonId = '',
    required this.title,
    required this.instructions,
    this.maxScore = 100,
    this.deadline,
    required this.createdAt,
    this.timing = AssignmentTiming.afterLesson,
    this.attachmentUrl = '',
    this.pdfAttachmentName,
    this.blocksNextLesson = false,
  });

  bool get hasAttachment => attachmentUrl.trim().isNotEmpty;
  bool get hasPdfAttachment =>
      attachmentUrl.trim().isNotEmpty &&
      (attachmentUrl.toLowerCase().contains('.pdf') ||
          attachmentUrl.contains('/o/assignments%2F') ||
          (pdfAttachmentName != null &&
              pdfAttachmentName!.toLowerCase().endsWith('.pdf')));

  Assignment copyWith({
    String? id,
    String? courseId,
    String? courseTitle,
    String? levelId,
    String? lessonId,
    String? title,
    String? instructions,
    int? maxScore,
    DateTime? deadline,
    DateTime? createdAt,
    AssignmentTiming? timing,
    String? attachmentUrl,
    String? pdfAttachmentName,
    bool? blocksNextLesson,
  }) {
    return Assignment(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      courseTitle: courseTitle ?? this.courseTitle,
      levelId: levelId ?? this.levelId,
      lessonId: lessonId ?? this.lessonId,
      title: title ?? this.title,
      instructions: instructions ?? this.instructions,
      maxScore: maxScore ?? this.maxScore,
      deadline: deadline ?? this.deadline,
      createdAt: createdAt ?? this.createdAt,
      timing: timing ?? this.timing,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      pdfAttachmentName: pdfAttachmentName ?? this.pdfAttachmentName,
      blocksNextLesson: blocksNextLesson ?? this.blocksNextLesson,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'courseId': courseId,
        'courseTitle': courseTitle,
        'levelId': levelId,
        'lessonId': lessonId,
        'title': title,
        'instructions': instructions,
        'maxScore': maxScore,
        'deadline': deadline?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'timing': timing.name,
        'attachmentUrl': attachmentUrl,
        'pdfAttachmentName': pdfAttachmentName,
        'blocksNextLesson': blocksNextLesson,
      };

  factory Assignment.fromLaravelJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final idVal = json['id']?.toString() ?? '';
    final courseIdStr = json['course_id']?.toString() ?? '';
    final videoIdStr = json['video_id']?.toString() ?? '';
    final titleStr = json['title']?.toString() ?? '';
    final instructionsStr = json['instructions']?.toString() ?? '';
    final maxScoreVal = (json['max_score'] is num)
        ? (json['max_score'] as num).toInt()
        : 100;

    return Assignment(
      id: idVal,
      courseId: courseIdStr,
      courseTitle: json['course_title']?.toString() ?? '',
      lessonId: videoIdStr,
      title: titleStr,
      instructions: instructionsStr,
      maxScore: maxScoreVal,
      createdAt: parseDate(json['created_at']),
      attachmentUrl: json['attachment_url']?.toString() ?? '',
      pdfAttachmentName: json['pdf_attachment_name']?.toString(),
      blocksNextLesson: json['blocks_next_lesson'] == true,
    );
  }

  factory Assignment.fromMap(Map<String, dynamic> map, {String? id}) {
    return Assignment(
      id: id ?? map['id']?.toString() ?? '',
      courseId: map['courseId']?.toString() ?? '',
      courseTitle: map['courseTitle']?.toString() ?? '',
      levelId: map['levelId']?.toString() ?? '',
      lessonId: map['lessonId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      instructions: map['instructions']?.toString() ?? '',
      maxScore: (map['maxScore'] is num) ? (map['maxScore'] as num).toInt() : 100,
      deadline: FirestoreDateTimeConverter.fromValue(map['deadline']),
      createdAt: FirestoreDateTimeConverter.fromValue(map['createdAt']) ?? DateTime.now(),
      timing: AssignmentTiming.fromName(map['timing'] as String?),
      attachmentUrl: map['attachmentUrl']?.toString() ?? '',
      pdfAttachmentName: map['pdfAttachmentName'] as String?,
      blocksNextLesson: map['blocksNextLesson'] == true,
    );
  }

  @override
  List<Object?> get props => [
        id,
        courseId,
        courseTitle,
        levelId,
        lessonId,
        title,
        instructions,
        maxScore,
        deadline,
        createdAt,
        timing,
        attachmentUrl,
        pdfAttachmentName,
        blocksNextLesson,
      ];
}

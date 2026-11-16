import 'package:equatable/equatable.dart';

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

  factory Assignment.fromMap(Map<String, dynamic> map, {String? id}) {
    return Assignment(
      id: id ?? map['id'] ?? '',
      courseId: map['courseId'] ?? '',
      courseTitle: map['courseTitle'] ?? '',
      levelId: map['levelId'] ?? '',
      lessonId: map['lessonId'] ?? '',
      title: map['title'] ?? '',
      instructions: map['instructions'] ?? '',
      maxScore: map['maxScore'] ?? 100,
      deadline: map['deadline'] != null
          ? DateTime.tryParse(map['deadline'].toString())
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      timing: AssignmentTiming.fromName(map['timing'] as String?),
      attachmentUrl: map['attachmentUrl'] ?? '',
      pdfAttachmentName: map['pdfAttachmentName'] as String?,
      blocksNextLesson: map['blocksNextLesson'] ?? false,
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

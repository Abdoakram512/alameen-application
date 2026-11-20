import 'package:equatable/equatable.dart';
import '../core/converters/firestore_date_time_converter.dart';

/// نموذج بيانات تسليم التكليف (AssignmentSubmission)
class AssignmentSubmission extends Equatable {
  final String id;
  final String assignmentId;
  final String assignmentTitle;
  final String courseId;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String solutionText;
  final String attachmentUrl;
  final String status; // 'pending' | 'graded'
  final int? score;
  final int maxScore;
  final String adminFeedback;
  final DateTime submittedAt;
  final DateTime? gradedAt;
  final String? audioRecordingUrl;
  final String? clinicalFeedback;

  const AssignmentSubmission({
    required this.id,
    required this.assignmentId,
    this.assignmentTitle = '',
    required this.courseId,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.solutionText,
    this.attachmentUrl = '',
    this.status = 'pending',
    this.score,
    this.maxScore = 100,
    this.adminFeedback = '',
    required this.submittedAt,
    this.gradedAt,
    this.audioRecordingUrl,
    this.clinicalFeedback,
  });

  bool get isGraded => status == 'graded' || status == 'evaluated';

  AssignmentSubmission copyWith({
    String? id,
    String? assignmentId,
    String? assignmentTitle,
    String? courseId,
    String? studentId,
    String? studentName,
    String? studentEmail,
    String? solutionText,
    String? attachmentUrl,
    String? status,
    int? score,
    int? maxScore,
    String? adminFeedback,
    DateTime? submittedAt,
    DateTime? gradedAt,
    String? audioRecordingUrl,
    String? clinicalFeedback,
  }) {
    return AssignmentSubmission(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      assignmentTitle: assignmentTitle ?? this.assignmentTitle,
      courseId: courseId ?? this.courseId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentEmail: studentEmail ?? this.studentEmail,
      solutionText: solutionText ?? this.solutionText,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      status: status ?? this.status,
      score: score ?? this.score,
      maxScore: maxScore ?? this.maxScore,
      adminFeedback: adminFeedback ?? this.adminFeedback,
      submittedAt: submittedAt ?? this.submittedAt,
      gradedAt: gradedAt ?? this.gradedAt,
      audioRecordingUrl: audioRecordingUrl ?? this.audioRecordingUrl,
      clinicalFeedback: clinicalFeedback ?? this.clinicalFeedback,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'assignmentId': assignmentId,
        'assignmentTitle': assignmentTitle,
        'courseId': courseId,
        'studentId': studentId,
        'studentName': studentName,
        'studentEmail': studentEmail,
        'solutionText': solutionText,
        'attachmentUrl': attachmentUrl,
        'status': status,
        'score': score,
        'maxScore': maxScore,
        'adminFeedback': adminFeedback,
        'submittedAt': submittedAt.toIso8601String(),
        'gradedAt': gradedAt?.toIso8601String(),
        'audioRecordingUrl': audioRecordingUrl,
        'clinicalFeedback': clinicalFeedback,
      };

  factory AssignmentSubmission.fromLaravelJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final idVal = json['id']?.toString() ?? '';
    final taskIdVal = json['task_id']?.toString() ?? '';
    final userIdVal = json['user_id']?.toString() ?? '';
    final audioUrl = json['audio_recording_url']?.toString() ?? '';
    final studentNotes = json['student_notes']?.toString() ?? '';
    final feedback = json['clinical_feedback']?.toString() ?? '';
    final statusVal = json['status']?.toString() ?? 'pending';
    final scoreVal = json['score'] != null ? int.tryParse(json['score'].toString()) : null;
    final maxScoreVal = json['max_score'] != null
        ? int.tryParse(json['max_score'].toString()) ?? 100
        : 100;
    final graderName = json['grader_name']?.toString();

    DateTime? gradedAtDate;
    if (json['graded_at'] != null) {
      gradedAtDate = DateTime.tryParse(json['graded_at'].toString());
    }

    return AssignmentSubmission(
      id: idVal,
      assignmentId: taskIdVal,
      assignmentTitle: json['task_title']?.toString() ?? '',
      courseId: json['course_id']?.toString() ?? '',
      studentId: userIdVal,
      studentName: json['student_name']?.toString() ?? '',
      studentEmail: json['student_email']?.toString() ?? '',
      solutionText: studentNotes,
      attachmentUrl: audioUrl.isNotEmpty ? audioUrl : (json['attachment_url']?.toString() ?? ''),
      audioRecordingUrl: audioUrl.isNotEmpty ? audioUrl : null,
      clinicalFeedback: feedback.isNotEmpty ? feedback : null,
      status: statusVal,
      score: scoreVal,
      maxScore: maxScoreVal,
      adminFeedback: feedback.isNotEmpty
          ? (graderName != null && graderName.isNotEmpty ? '$feedback ($graderName)' : feedback)
          : '',
      submittedAt: parseDate(json['created_at']),
      gradedAt: gradedAtDate,
    );
  }

  factory AssignmentSubmission.fromMap(Map<String, dynamic> map, {String? id}) {
    return AssignmentSubmission(
      id: id ?? map['id']?.toString() ?? '',
      assignmentId: map['assignmentId']?.toString() ?? '',
      assignmentTitle: map['assignmentTitle']?.toString() ?? '',
      courseId: map['courseId']?.toString() ?? '',
      studentId: map['studentId']?.toString() ?? '',
      studentName: map['studentName']?.toString() ?? '',
      studentEmail: map['studentEmail']?.toString() ?? '',
      solutionText: map['solutionText']?.toString() ?? '',
      attachmentUrl: map['attachmentUrl']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      score: map['score'] != null ? int.tryParse(map['score'].toString()) : null,
      maxScore: map['maxScore'] != null
          ? int.tryParse(map['maxScore'].toString()) ?? 100
          : 100,
      adminFeedback: map['adminFeedback']?.toString() ?? '',
      submittedAt: FirestoreDateTimeConverter.fromValue(map['submittedAt']) ??
          DateTime.now(),
      gradedAt: FirestoreDateTimeConverter.fromValue(map['gradedAt']),
    );
  }

  @override
  List<Object?> get props => [
        id,
        assignmentId,
        assignmentTitle,
        courseId,
        studentId,
        studentName,
        studentEmail,
        solutionText,
        attachmentUrl,
        status,
        score,
        maxScore,
        adminFeedback,
        submittedAt,
        gradedAt,
        audioRecordingUrl,
        clinicalFeedback,
      ];
}

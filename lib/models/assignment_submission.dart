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
  });

  bool get isGraded => status == 'graded';

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
      };

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
      ];
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

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
      id: id ?? map['id'] ?? '',
      assignmentId: map['assignmentId'] ?? '',
      assignmentTitle: map['assignmentTitle'] ?? '',
      courseId: map['courseId'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      studentEmail: map['studentEmail'] ?? '',
      solutionText: map['solutionText'] ?? '',
      attachmentUrl: map['attachmentUrl'] ?? '',
      status: map['status'] ?? 'pending',
      score: map['score'] != null ? int.tryParse(map['score'].toString()) : null,
      maxScore: map['maxScore'] != null ? int.tryParse(map['maxScore'].toString()) ?? 100 : 100,
      adminFeedback: map['adminFeedback'] ?? '',
      submittedAt: map['submittedAt'] is Timestamp
          ? (map['submittedAt'] as Timestamp).toDate()
          : (map['submittedAt'] != null
                ? DateTime.tryParse(map['submittedAt'].toString()) ??
                      DateTime.now()
                : DateTime.now()),
      gradedAt: map['gradedAt'] is Timestamp
          ? (map['gradedAt'] as Timestamp).toDate()
          : (map['gradedAt'] != null
                ? DateTime.tryParse(map['gradedAt'].toString())
                : null),
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

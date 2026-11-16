import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class CourseCertificate extends Equatable {
  final String id;
  final String courseId;
  final String courseTitle;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String serialNumber;
  final DateTime issuedAt;
  final double completionPercentage;
  final String instructorName;
  final String verificationUrl;

  const CourseCertificate({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.serialNumber,
    required this.issuedAt,
    this.completionPercentage = 95.0,
    this.instructorName = 'المشرف الأكاديمي العام',
    this.verificationUrl = 'https://alameen.center/verify',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'courseId': courseId,
        'courseTitle': courseTitle,
        'studentId': studentId,
        'studentUid': studentId,
        'studentName': studentName,
        'studentEmail': studentEmail,
        'serialNumber': serialNumber,
        'issuedAt': Timestamp.fromDate(issuedAt),
        'completionPercentage': completionPercentage,
        'instructorName': instructorName,
        'verificationUrl': verificationUrl,
      };

  factory CourseCertificate.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return CourseCertificate(
      id: id ?? map['id'] ?? '',
      courseId: map['courseId'] ?? '',
      courseTitle: map['courseTitle'] ?? '',
      studentId: (map['studentId'] ?? map['studentUid']) as String? ?? '',
      studentName: map['studentName'] ?? '',
      studentEmail: map['studentEmail'] ?? '',
      serialNumber: map['serialNumber'] ?? '',
      issuedAt: parseDate(map['issuedAt']),
      completionPercentage:
          (map['completionPercentage'] as num?)?.toDouble() ?? 95.0,
      instructorName: map['instructorName'] ?? 'المشرف الأكاديمي العام',
      verificationUrl: map['verificationUrl'] ?? 'https://alameen.center/verify',
    );
  }

  @override
  List<Object?> get props => [
        id,
        courseId,
        studentId,
        serialNumber,
        issuedAt,
        completionPercentage,
      ];
}


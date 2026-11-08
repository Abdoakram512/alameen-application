import 'package:equatable/equatable.dart';

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
  });

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
      ];
}

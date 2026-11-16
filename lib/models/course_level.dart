import 'package:equatable/equatable.dart';
import 'lesson.dart';

/// نموذج بيانات المستوى الدراسي (CourseLevel)
class CourseLevel extends Equatable {
  final String id;
  final String title;
  final String description;
  final int order;
  final List<Lesson> lessons;

  const CourseLevel({
    required this.id,
    required this.title,
    required this.description,
    required this.order,
    required this.lessons,
  });

  int get totalLessons => lessons.length;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'order': order,
        'lessons': lessons.map((l) => l.toMap()).toList(),
      };

  factory CourseLevel.fromMap(Map<String, dynamic> map) {
    final rawLessons = map['lessons'] as List? ?? [];
    final parsedLessons = rawLessons
        .map((l) => Lesson.fromMap(Map<String, dynamic>.from(l as Map)))
        .toList();
    parsedLessons.sort((a, b) => a.order.compareTo(b.order));

    return CourseLevel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      order: (map['order'] is num) ? (map['order'] as num).toInt() : 1,
      lessons: parsedLessons,
    );
  }

  CourseLevel copyWith({
    String? id,
    String? title,
    String? description,
    int? order,
    List<Lesson>? lessons,
  }) {
    return CourseLevel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      order: order ?? this.order,
      lessons: lessons ?? List.from(this.lessons),
    );
  }

  @override
  List<Object?> get props => [id, title, description, order, lessons];
}

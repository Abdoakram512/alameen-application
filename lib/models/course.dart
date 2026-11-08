import 'package:equatable/equatable.dart';
import 'course_level.dart';

class Course extends Equatable {
  final String id;
  final String title;
  final String description;
  final String instructor;
  final String category;
  final String thumbnailUrl;
  final List<CourseLevel> levels;
  final int enrolledCount;
  final double price;

  const Course({
    required this.id,
    required this.title,
    required this.description,
    required this.instructor,
    required this.category,
    required this.thumbnailUrl,
    required this.levels,
    this.enrolledCount = 0,
    this.price = 0.0,
  });

  int get totalLessonsCount {
    return levels.fold(0, (sum, lvl) => sum + lvl.lessons.length);
  }

  List<String> get allLessonIds {
    return levels.expand((lvl) => lvl.lessons.map((les) => les.id)).toList();
  }

  String get priceFormatted =>
      price > 0 ? '${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)} ج.م' : 'مجاني';

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'instructor': instructor,
        'category': category,
        'thumbnailUrl': thumbnailUrl,
        'enrolledCount': enrolledCount,
        'price': price,
        'levels': levels.map((lvl) => lvl.toMap()).toList(),
      };

  factory Course.fromMap(Map<String, dynamic> map) {
    final rawLevels = map['levels'] as List? ?? [];
    final parsedLevels = rawLevels
        .map((lvl) => CourseLevel.fromMap(Map<String, dynamic>.from(lvl)))
        .toList();
    parsedLevels.sort((a, b) => a.order.compareTo(b.order));

    return Course(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      instructor: map['instructor'] ?? '',
      category: map['category'] ?? '',
      thumbnailUrl: map['thumbnailUrl'] ?? '',
      enrolledCount: map['enrolledCount'] != null
          ? int.tryParse(map['enrolledCount'].toString()) ?? 0
          : 0,
      price: map['price'] != null
          ? double.tryParse(map['price'].toString()) ?? 0.0
          : 0.0,
      levels: parsedLevels,
    );
  }

  Course copyWith({
    String? id,
    String? title,
    String? description,
    String? instructor,
    String? category,
    String? thumbnailUrl,
    List<CourseLevel>? levels,
    int? enrolledCount,
    double? price,
  }) {
    return Course(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      instructor: instructor ?? this.instructor,
      category: category ?? this.category,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      levels: levels ?? List.from(this.levels),
      enrolledCount: enrolledCount ?? this.enrolledCount,
      price: price ?? this.price,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        instructor,
        category,
        thumbnailUrl,
        levels,
        enrolledCount,
        price,
      ];
}

import 'package:equatable/equatable.dart';
import '../core/converters/firestore_date_time_converter.dart';
import 'course_access_mode.dart';
import 'course_level.dart';

/// نموذج بيانات الدورة التعليمية (Course)
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
  final CourseAccessMode accessMode;
  final List<String> allowedStudentIds;
  final int validityDays; // مدة الصلاحية بالأيام (0 = دائم / غير محدود)
  final bool isEnrollmentClosed; // إغلاق الدورة بالكامل وإلغاء اشتراك الجميع
  final DateTime? fixedExpiryDate; // تاريخ إغلاق موحد محدد

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
    this.accessMode = CourseAccessMode.approvalRequired,
    this.allowedStudentIds = const [],
    this.validityDays = 0,
    this.isEnrollmentClosed = false,
    this.fixedExpiryDate,
  });

  int get totalLessonsCount {
    return levels.fold(0, (sum, lvl) => sum + lvl.lessons.length);
  }

  List<String> get allLessonIds {
    return levels.expand((lvl) => lvl.lessons.map((les) => les.id)).toList();
  }

  String get priceFormatted => price > 0
      ? '${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)} ج.م'
      : 'مجاني';

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'instructor': instructor,
        'category': category,
        'thumbnailUrl': thumbnailUrl,
        'enrolledCount': enrolledCount,
        'price': price,
        'accessMode': accessMode.name,
        'allowedStudentIds': allowedStudentIds,
        'validityDays': validityDays,
        'isEnrollmentClosed': isEnrollmentClosed,
        'fixedExpiryDate': fixedExpiryDate?.toIso8601String(),
        'levels': levels.map((lvl) => lvl.toMap()).toList(),
      };

  factory Course.fromMap(Map<String, dynamic> map) {
    final rawLevels = map['levels'] as List? ?? [];
    final parsedLevels = rawLevels
        .map((lvl) => CourseLevel.fromMap(Map<String, dynamic>.from(lvl as Map)))
        .toList();
    parsedLevels.sort((a, b) => a.order.compareTo(b.order));

    return Course(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      instructor: map['instructor']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      thumbnailUrl: map['thumbnailUrl']?.toString() ?? '',
      enrolledCount: (map['enrolledCount'] is num)
          ? (map['enrolledCount'] as num).toInt()
          : (int.tryParse(map['enrolledCount']?.toString() ?? '') ?? 0),
      price: (map['price'] is num)
          ? (map['price'] as num).toDouble()
          : (double.tryParse(map['price']?.toString() ?? '') ?? 0.0),
      levels: parsedLevels,
      accessMode: CourseAccessMode.fromName(map['accessMode'] as String?),
      allowedStudentIds:
          List<String>.from(map['allowedStudentIds'] as List? ?? const []),
      validityDays: (map['validityDays'] is num)
          ? (map['validityDays'] as num).toInt()
          : (int.tryParse(map['validityDays']?.toString() ?? '') ?? 0),
      isEnrollmentClosed: map['isEnrollmentClosed'] == true,
      fixedExpiryDate:
          FirestoreDateTimeConverter.fromValue(map['fixedExpiryDate']),
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
    CourseAccessMode? accessMode,
    List<String>? allowedStudentIds,
    int? validityDays,
    bool? isEnrollmentClosed,
    DateTime? fixedExpiryDate,
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
      accessMode: accessMode ?? this.accessMode,
      allowedStudentIds: allowedStudentIds ?? this.allowedStudentIds,
      validityDays: validityDays ?? this.validityDays,
      isEnrollmentClosed: isEnrollmentClosed ?? this.isEnrollmentClosed,
      fixedExpiryDate: fixedExpiryDate ?? this.fixedExpiryDate,
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
        accessMode,
        allowedStudentIds,
        validityDays,
        isEnrollmentClosed,
        fixedExpiryDate,
      ];
}

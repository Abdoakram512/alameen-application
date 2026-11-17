import 'package:equatable/equatable.dart';
import '../core/config/app_config.dart';
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
  final String? slug;
  final double? originalPrice;
  final String? currencySymbol;
  final String? currencyName;
  final int? videosCount;
  final bool isPublished;
  final bool hasEnrolled;
  final List<int> accessibleVideoIds;

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
    this.slug,
    this.originalPrice,
    this.currencySymbol,
    this.currencyName,
    this.videosCount,
    this.isPublished = true,
    this.hasEnrolled = false,
    this.accessibleVideoIds = const [],
  });

  int get totalLessonsCount {
    if (levels.isNotEmpty) {
      return levels.fold(0, (sum, lvl) => sum + lvl.lessons.length);
    }
    return videosCount ?? 0;
  }

  List<String> get allLessonIds {
    return levels.expand((lvl) => lvl.lessons.map((les) => les.id)).toList();
  }

  String get priceFormatted => price > 0
      ? '${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)} ج.م'
      : 'مجاني';

  Map<String, dynamic> toMap() => {
        'id': id,
        'slug': slug,
        'title': title,
        'description': description,
        'instructor': instructor,
        'category': category,
        'thumbnailUrl': thumbnailUrl,
        'enrolledCount': enrolledCount,
        'price': price,
        'originalPrice': originalPrice,
        'currencySymbol': currencySymbol,
        'currencyName': currencyName,
        'accessMode': accessMode.name,
        'allowedStudentIds': allowedStudentIds,
        'validityDays': validityDays,
        'isEnrollmentClosed': isEnrollmentClosed,
        'fixedExpiryDate': fixedExpiryDate?.toIso8601String(),
        'videosCount': videosCount,
        'isPublished': isPublished,
        'levels': levels.map((lvl) => lvl.toMap()).toList(),
      };

  factory Course.fromLaravelSummaryJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final slug = json['slug']?.toString() ?? id;
    final title = json['title']?.toString() ?? json['title_ar']?.toString() ?? '';
    final description = json['description']?.toString() ?? json['description_ar']?.toString() ?? '';
    final price = (json['price'] is num)
        ? (json['price'] as num).toDouble()
        : (double.tryParse(json['price']?.toString() ?? '') ?? 0.0);
    final originalPrice = (json['original_price'] is num)
        ? (json['original_price'] as num).toDouble()
        : null;
    final currencySymbol = json['currency_symbol']?.toString() ?? 'ج.م';
    final currencyName = json['currency_name']?.toString() ?? 'جنيه مصري';
    final accessDurationDays = (json['access_duration_days'] is num)
        ? (json['access_duration_days'] as num).toInt()
        : 365;
    final thumbnail = AppConfig.resolveMediaUrl(json['thumbnail']?.toString());
    final videosCount = (json['videos_count'] is num)
        ? (json['videos_count'] as num).toInt()
        : null;
    final isPublished = json['is_published'] != false;

    return Course(
      id: id,
      slug: slug,
      title: title,
      description: description,
      instructor: 'أكاديمية الأمين',
      category: 'تخاطب سريري',
      thumbnailUrl: thumbnail,
      levels: const [],
      enrolledCount: 0,
      price: price,
      originalPrice: originalPrice,
      currencySymbol: currencySymbol,
      currencyName: currencyName,
      accessMode: price > 0 ? CourseAccessMode.approvalRequired : CourseAccessMode.open,
      validityDays: accessDurationDays,
      videosCount: videosCount,
      isPublished: isPublished,
    );
  }

  factory Course.fromLaravelDetailsJson(Map<String, dynamic> json) {
    final courseData = json['course'] is Map<String, dynamic>
        ? json['course'] as Map<String, dynamic>
        : json;
    final baseCourse = Course.fromLaravelSummaryJson(courseData);

    final rawLevels = json['levels'] as List? ?? [];
    final parsedLevels = rawLevels
        .map((lvl) => CourseLevel.fromLaravelJson(Map<String, dynamic>.from(lvl as Map)))
        .toList();
    parsedLevels.sort((a, b) => a.order.compareTo(b.order));

    final totalVideos = (json['total_videos'] is num)
        ? (json['total_videos'] as num).toInt()
        : baseCourse.videosCount;

    final hasEnrolled = json['has_enrolled'] == true ||
        (json['course'] is Map && (json['course'] as Map)['has_enrolled'] == true);

    final rawAccessible = json['accessible_video_ids'] as List? ?? [];
    final parsedAccessible = rawAccessible
        .map((id) => (id is num) ? id.toInt() : (int.tryParse(id.toString()) ?? 0))
        .where((id) => id > 0)
        .toList();

    return baseCourse.copyWith(
      levels: parsedLevels,
      videosCount: totalVideos,
      hasEnrolled: hasEnrolled,
      accessibleVideoIds: parsedAccessible,
    );
  }

  factory Course.fromMap(Map<String, dynamic> map) {
    // If it's a Laravel API response object with slug and currency
    if (map.containsKey('slug') && (map.containsKey('currency_symbol') || map.containsKey('access_duration_days'))) {
      if (map.containsKey('levels') || map.containsKey('course')) {
        return Course.fromLaravelDetailsJson(map);
      }
      return Course.fromLaravelSummaryJson(map);
    }

    final rawLevels = map['levels'] as List? ?? [];
    final parsedLevels = rawLevels
        .map((lvl) => CourseLevel.fromMap(Map<String, dynamic>.from(lvl as Map)))
        .toList();
    parsedLevels.sort((a, b) => a.order.compareTo(b.order));

    return Course(
      id: map['id']?.toString() ?? '',
      slug: map['slug']?.toString(),
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
      originalPrice: (map['originalPrice'] is num)
          ? (map['originalPrice'] as num).toDouble()
          : null,
      currencySymbol: map['currencySymbol']?.toString(),
      currencyName: map['currencyName']?.toString(),
      videosCount: (map['videosCount'] is num) ? (map['videosCount'] as num).toInt() : null,
      isPublished: map['isPublished'] != false,
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
    String? slug,
    double? originalPrice,
    String? currencySymbol,
    String? currencyName,
    int? videosCount,
    bool? isPublished,
    bool? hasEnrolled,
    List<int>? accessibleVideoIds,
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
      slug: slug ?? this.slug,
      originalPrice: originalPrice ?? this.originalPrice,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      currencyName: currencyName ?? this.currencyName,
      videosCount: videosCount ?? this.videosCount,
      isPublished: isPublished ?? this.isPublished,
      hasEnrolled: hasEnrolled ?? this.hasEnrolled,
      accessibleVideoIds: accessibleVideoIds ?? this.accessibleVideoIds,
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
        slug,
        originalPrice,
        currencySymbol,
        currencyName,
        videosCount,
        isPublished,
        hasEnrolled,
        accessibleVideoIds,
      ];
}

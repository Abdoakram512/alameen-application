import 'package:equatable/equatable.dart';

/// نموذج ركيزة أو محور تعريفي ضمن محتوى من نحن
class AboutUsPillar extends Equatable {
  final String title;
  final String description;

  const AboutUsPillar({
    required this.title,
    required this.description,
  });

  factory AboutUsPillar.fromJson(Map<String, dynamic> json) {
    return AboutUsPillar(
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }

  Map<String, String> toMap() => {
        'title': title,
        'description': description,
      };

  Map<String, String> toJson() => toMap();

  dynamic operator [](String key) {
    switch (key) {
      case 'title':
        return title;
      case 'description':
        return description;
      default:
        return null;
    }
  }

  bool containsKey(String key) => key == 'title' || key == 'description';

  @override
  List<Object?> get props => [title, description];
}

/// نموذج بيانات صفحة من نحن المعتمد (AboutUsData)
class AboutUsData extends Equatable {
  final String title;
  final String content;
  final List<AboutUsPillar> pillars;

  const AboutUsData({
    required this.title,
    required this.content,
    this.pillars = const [],
  });

  factory AboutUsData.fromJson(Map<String, dynamic> json) {
    final pillarsList = <AboutUsPillar>[];
    if (json['pillars'] is List) {
      for (final p in json['pillars'] as List) {
        if (p is Map) {
          pillarsList.add(AboutUsPillar.fromJson(Map<String, dynamic>.from(p)));
        }
      }
    }
    return AboutUsData(
      title: json['title']?.toString() ?? 'مركز الأمين للتخاطب والتأهيل',
      content: json['content']?.toString() ?? '',
      pillars: pillarsList,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'content': content,
        'pillars': pillars.map((p) => p.toMap()).toList(),
      };

  Map<String, dynamic> toJson() => toMap();

  dynamic operator [](String key) {
    switch (key) {
      case 'title':
        return title;
      case 'content':
        return content;
      case 'pillars':
        return pillars;
      default:
        return null;
    }
  }

  bool containsKey(String key) =>
      key == 'title' || key == 'content' || key == 'pillars';

  @override
  List<Object?> get props => [title, content, pillars];
}

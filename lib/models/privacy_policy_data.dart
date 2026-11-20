import 'package:equatable/equatable.dart';

/// نموذج بيانات سياسة الخصوصية وسرية المعلومات (PrivacyPolicyData)
class PrivacyPolicyData extends Equatable {
  final String title;
  final String content;

  const PrivacyPolicyData({
    required this.title,
    required this.content,
  });

  factory PrivacyPolicyData.fromJson(Map<String, dynamic> json) {
    return PrivacyPolicyData(
      title: json['title']?.toString() ?? 'سياسة الخصوصية والأمان',
      content: json['content']?.toString() ?? '',
    );
  }

  Map<String, String> toMap() => {
        'title': title,
        'content': content,
      };

  Map<String, String> toJson() => toMap();

  dynamic operator [](String key) {
    switch (key) {
      case 'title':
        return title;
      case 'content':
        return content;
      default:
        return null;
    }
  }

  bool containsKey(String key) => key == 'title' || key == 'content';

  @override
  List<Object?> get props => [title, content];
}

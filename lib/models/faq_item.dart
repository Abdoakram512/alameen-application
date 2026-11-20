import 'package:equatable/equatable.dart';

/// نموذج بيانات عنصر الأسئلة الشائعة (FAQ Item)
class FaqItem extends Equatable {
  final String question;
  final String answer;

  const FaqItem({
    required this.question,
    required this.answer,
  });

  factory FaqItem.fromJson(Map<String, dynamic> json) {
    return FaqItem(
      question: json['question']?.toString() ?? json['q']?.toString() ?? '',
      answer: json['answer']?.toString() ?? json['a']?.toString() ?? '',
    );
  }

  Map<String, String> toMap() => {
        'question': question,
        'answer': answer,
      };

  Map<String, String> toJson() => toMap();

  /// دعم المفاتيح كـ Map لمنع أي تعارض توافقي
  dynamic operator [](String key) {
    switch (key) {
      case 'question':
      case 'q':
        return question;
      case 'answer':
      case 'a':
        return answer;
      default:
        return null;
    }
  }

  bool containsKey(String key) =>
      key == 'question' || key == 'answer' || key == 'q' || key == 'a';

  @override
  List<Object?> get props => [question, answer];
}

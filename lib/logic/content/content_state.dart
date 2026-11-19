import 'package:equatable/equatable.dart';
import '../../models/contact_info_data.dart';

abstract class ContentState extends Equatable {
  const ContentState();

  @override
  List<Object?> get props => [];
}

class ContentInitial extends ContentState {
  const ContentInitial();
}

class ContentLoading extends ContentState {
  const ContentLoading();
}

class ContentAboutLoaded extends ContentState {
  final String title;
  final String content;

  const ContentAboutLoaded({
    required this.title,
    required this.content,
  });

  @override
  List<Object?> get props => [title, content];
}

class ContentFaqsLoaded extends ContentState {
  final List<Map<String, String>> faqs;

  const ContentFaqsLoaded({required this.faqs});

  @override
  List<Object?> get props => [faqs];
}

class ContentPrivacyLoaded extends ContentState {
  final String title;
  final String content;

  const ContentPrivacyLoaded({
    required this.title,
    required this.content,
  });

  @override
  List<Object?> get props => [title, content];
}

class ContentContactLoaded extends ContentState {
  final ContactInfoData contactInfo;

  const ContentContactLoaded({required this.contactInfo});

  @override
  List<Object?> get props => [contactInfo];
}

class ContentError extends ContentState {
  final String message;

  const ContentError(this.message);

  @override
  List<Object?> get props => [message];
}

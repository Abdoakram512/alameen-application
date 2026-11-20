import 'package:equatable/equatable.dart';
import '../../models/about_us_data.dart';
import '../../models/contact_info_data.dart';
import '../../models/faq_item.dart';
import '../../models/privacy_policy_data.dart';

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
  final AboutUsData aboutUs;

  const ContentAboutLoaded({required this.aboutUs});

  String get title => aboutUs.title;
  String get content => aboutUs.content;

  @override
  List<Object?> get props => [aboutUs];
}

class ContentFaqsLoaded extends ContentState {
  final List<FaqItem> faqs;

  const ContentFaqsLoaded({required this.faqs});

  @override
  List<Object?> get props => [faqs];
}

class ContentPrivacyLoaded extends ContentState {
  final PrivacyPolicyData privacyPolicy;

  const ContentPrivacyLoaded({required this.privacyPolicy});

  String get title => privacyPolicy.title;
  String get content => privacyPolicy.content;

  @override
  List<Object?> get props => [privacyPolicy];
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

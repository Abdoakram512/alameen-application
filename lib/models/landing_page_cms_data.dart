import 'package:equatable/equatable.dart';
import 'about_us_data.dart';
import 'faq_item.dart';

/// بيانات قسم البطل (Hero Section) في الصفحة العامة /public/home
class HeroCmsData extends Equatable {
  final String title;
  final String subtitle;
  final String? ctaPrimaryText;
  final String? ctaSecondaryText;
  final String? studentsCount;
  final List<String> images;

  const HeroCmsData({
    required this.title,
    required this.subtitle,
    this.ctaPrimaryText,
    this.ctaSecondaryText,
    this.studentsCount,
    this.images = const [],
  });

  factory HeroCmsData.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'] as List? ?? [];
    return HeroCmsData(
      title: json['title']?.toString() ?? json['headline']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? json['subheadline']?.toString() ?? '',
      ctaPrimaryText: json['cta_primary_text']?.toString(),
      ctaSecondaryText: json['cta_secondary_text']?.toString(),
      studentsCount: json['students_count']?.toString(),
      images: rawImages.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'subtitle': subtitle,
        if (ctaPrimaryText != null) 'cta_primary_text': ctaPrimaryText,
        if (ctaSecondaryText != null) 'cta_secondary_text': ctaSecondaryText,
        if (studentsCount != null) 'students_count': studentsCount,
        'images': images,
      };

  dynamic operator [](String key) {
    switch (key) {
      case 'title':
      case 'headline':
        return title;
      case 'subtitle':
      case 'subheadline':
        return subtitle;
      case 'cta_primary_text':
        return ctaPrimaryText;
      case 'cta_secondary_text':
        return ctaSecondaryText;
      case 'students_count':
        return studentsCount;
      case 'images':
        return images;
      default:
        return null;
    }
  }

  @override
  List<Object?> get props => [
        title,
        subtitle,
        ctaPrimaryText,
        ctaSecondaryText,
        studentsCount,
        images,
      ];
}

/// نموذج بيانات الصفحة الرئيسية العامة (LandingPageCmsData) المطابق لـ /public/home
class LandingPageCmsData extends Equatable {
  final HeroCmsData? hero;
  final List<AboutUsPillar> aboutPillars;
  final List<FaqItem> faqs;

  const LandingPageCmsData({
    this.hero,
    this.aboutPillars = const [],
    this.faqs = const [],
  });

  factory LandingPageCmsData.fromJson(Map<String, dynamic> json) {
    HeroCmsData? heroData;
    if (json['hero'] is Map) {
      heroData = HeroCmsData.fromJson(Map<String, dynamic>.from(json['hero'] as Map));
    }

    final pillars = <AboutUsPillar>[];
    if (json['about_pillars'] is List) {
      for (final item in json['about_pillars'] as List) {
        if (item is Map) {
          pillars.add(AboutUsPillar.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final faqItems = <FaqItem>[];
    if (json['faq'] is List) {
      for (final item in json['faq'] as List) {
        if (item is Map) {
          faqItems.add(FaqItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return LandingPageCmsData(
      hero: heroData,
      aboutPillars: pillars,
      faqs: faqItems,
    );
  }

  Map<String, dynamic> toJson() => {
        if (hero != null) 'hero': hero!.toJson(),
        'about_pillars': aboutPillars.map((p) => p.toJson()).toList(),
        'faq': faqs.map((f) => f.toJson()).toList(),
      };

  dynamic operator [](String key) {
    switch (key) {
      case 'hero':
        return hero;
      case 'about_pillars':
        return aboutPillars;
      case 'faq':
        return faqs;
      default:
        return null;
    }
  }

  @override
  List<Object?> get props => [hero, aboutPillars, faqs];
}

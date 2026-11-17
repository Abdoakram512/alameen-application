import 'package:equatable/equatable.dart';

class BootstrapData extends Equatable {
  final String siteName;
  final String siteTagline;
  final String? logoUrl;
  final String currencySymbol;
  final String currencyName;
  final Map<String, dynamic> theme;
  final Map<String, dynamic> features;
  final Map<String, dynamic> contact;

  const BootstrapData({
    required this.siteName,
    required this.siteTagline,
    this.logoUrl,
    this.currencySymbol = 'ج.م',
    this.currencyName = 'جنيه مصري',
    this.theme = const {},
    this.features = const {},
    this.contact = const {},
  });

  factory BootstrapData.fromJson(Map<String, dynamic> json) {
    final branding = json['branding'] as Map? ?? {};
    final currency = json['currency'] as Map? ?? {};
    final themeMap = json['theme'] as Map? ?? {};
    final featuresMap = json['features'] as Map? ?? {};
    final contactMap = json['contact'] as Map? ?? {};

    return BootstrapData(
      siteName: branding['site_name']?.toString() ?? 'أكاديمية الأمين للتخاطب السريري',
      siteTagline: branding['site_tagline']?.toString() ?? '',
      logoUrl: branding['logo_url']?.toString(),
      currencySymbol: currency['symbol']?.toString() ?? 'ج.م',
      currencyName: currency['name']?.toString() ?? 'جنيه مصري',
      theme: Map<String, dynamic>.from(themeMap),
      features: Map<String, dynamic>.from(featuresMap),
      contact: Map<String, dynamic>.from(contactMap),
    );
  }

  @override
  List<Object?> get props => [
        siteName,
        siteTagline,
        logoUrl,
        currencySymbol,
        currencyName,
        theme,
        features,
        contact,
      ];
}

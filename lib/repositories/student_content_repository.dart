import '../models/bootstrap_data.dart';
import '../models/contact_info_data.dart';

abstract class StudentContentRepository {
  /// Fetch global platform bootstrap config
  Future<BootstrapData?> getBootstrapConfig();

  /// Fetch landing page CMS data
  Future<Map<String, dynamic>?> getLandingPageData();

  /// Fetch platform contact and support channels
  Future<ContactInfoData?> getContactInfo();

  /// Fetch About Us profile details from Laravel API or bundled verified CMS
  Future<Map<String, String>> getAboutUs();

  /// Fetch FAQ list from Laravel API (/public/home) or bundled verified CMS
  Future<List<Map<String, String>>> getFaqs();

  /// Fetch Privacy Policy legal content
  Future<Map<String, String>> getPrivacyPolicy();
}

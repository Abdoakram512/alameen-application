import '../models/about_us_data.dart';
import '../models/bootstrap_data.dart';
import '../models/contact_info_data.dart';
import '../models/faq_item.dart';
import '../models/landing_page_cms_data.dart';
import '../models/privacy_policy_data.dart';

abstract class StudentContentRepository {
  /// Fetch global platform bootstrap config
  Future<BootstrapData?> getBootstrapConfig();

  /// Fetch landing page CMS data
  Future<LandingPageCmsData?> getLandingPageData();

  /// Fetch platform contact and support channels
  Future<ContactInfoData?> getContactInfo();

  /// Fetch About Us profile details from Laravel API or bundled verified CMS
  Future<AboutUsData> getAboutUs();

  /// Fetch FAQ list from Laravel API (/public/home) or bundled verified CMS
  Future<List<FaqItem>> getFaqs();

  /// Fetch Privacy Policy legal content
  Future<PrivacyPolicyData> getPrivacyPolicy();
}

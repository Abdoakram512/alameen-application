import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bootstrap_data.dart';
import '../models/contact_info_data.dart';

abstract class StudentContentRepository {
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamAppContent(String docId);
  Future<Map<String, dynamic>?> getAppContent(String docId);

  /// Fetch global platform bootstrap config
  Future<BootstrapData?> getBootstrapConfig();

  /// Fetch landing page CMS data
  Future<Map<String, dynamic>?> getLandingPageData();

  /// Fetch platform contact and support channels
  Future<ContactInfoData?> getContactInfo();
}

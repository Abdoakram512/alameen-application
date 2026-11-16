import 'package:cloud_firestore/cloud_firestore.dart';

abstract class AppContentRepository {
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamAppContent(String docId);
  Future<void> saveAppContent({
    required String docId,
    required String title,
    required dynamic content,
  });
}

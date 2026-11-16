import 'package:cloud_firestore/cloud_firestore.dart';

abstract class StudentContentRepository {
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamAppContent(String docId);
  Future<Map<String, dynamic>?> getAppContent(String docId);
}

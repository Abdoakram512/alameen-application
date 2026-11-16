import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_content_repository.dart';

class AppContentRepositoryImpl implements AppContentRepository {
  final FirebaseFirestore? _explicitFirestore;

  AppContentRepositoryImpl({FirebaseFirestore? firestore})
      : _explicitFirestore = firestore;

  bool get isAvailable {
    try {
      final _ = db;
      return true;
    } catch (_) {
      return false;
    }
  }

  FirebaseFirestore get db => _explicitFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _appContentRef =>
      db.collection('app_content');

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamAppContent(String docId) {
    if (!isAvailable) return const Stream.empty();
    return _appContentRef.doc(docId).snapshots();
  }

  @override
  Future<void> saveAppContent({
    required String docId,
    required String title,
    required dynamic content,
  }) async {
    await _appContentRef.doc(docId).set({
      'title': title,
      if (content is String) 'content': content,
      if (content is List) 'items': content,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../student_content_repository.dart';

class StudentContentRepositoryImpl implements StudentContentRepository {
  final FirebaseFirestore? _explicitFirestore;

  StudentContentRepositoryImpl({FirebaseFirestore? firestore})
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
  Future<Map<String, dynamic>?> getAppContent(String docId) async {
    if (!isAvailable) return null;
    try {
      final doc = await _appContentRef.doc(docId).get();
      if (doc.exists && doc.data() != null) {
        return doc.data();
      }
    } catch (_) {}
    return null;
  }
}

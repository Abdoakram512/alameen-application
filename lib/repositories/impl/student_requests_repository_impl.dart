import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/access_request.dart';
import '../student_requests_repository.dart';

class StudentRequestsRepositoryImpl implements StudentRequestsRepository {
  final FirebaseFirestore? _explicitFirestore;

  StudentRequestsRepositoryImpl({FirebaseFirestore? firestore})
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

  CollectionReference<Map<String, dynamic>> get _requestsRef =>
      db.collection('access_requests');

  @override
  Stream<List<CourseAccessRequest>> streamStudentRequests(String studentId) {
    if (!isAvailable) return Stream.value(const <CourseAccessRequest>[]);
    return _requestsRef
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return CourseAccessRequest.fromJson(data);
      }).toList();
    });
  }

  @override
  Future<void> sendAccessRequest(CourseAccessRequest request) async {
    if (!isAvailable) return;
    await db.runTransaction((transaction) async {
      final ref = _requestsRef.doc(request.id);
      final existing = await transaction.get(ref);
      final status = existing.data()?['status'];
      if (status == 'approved') throw StateError('تم قبول الاشتراك بالفعل');
      if (status == 'pending') return;
      final json = request.toJson()
        ..['status'] = 'pending'
        ..['adminNotes'] = '';
      transaction.set(ref, json);
    });
  }
}

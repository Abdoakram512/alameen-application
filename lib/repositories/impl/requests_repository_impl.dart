import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/access_request.dart';
import '../requests_repository.dart';

class RequestsRepositoryImpl implements RequestsRepository {
  final FirebaseFirestore? _explicitFirestore;

  RequestsRepositoryImpl({FirebaseFirestore? firestore})
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

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      db.collection('users');

  CollectionReference<Map<String, dynamic>> get _coursesRef =>
      db.collection('courses');

  @override
  Stream<List<CourseAccessRequest>> streamRequests() {
    if (!isAvailable) return Stream.value(const <CourseAccessRequest>[]);
    return _requestsRef.snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return CourseAccessRequest.fromJson(data);
      }).toList();
      list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      return list;
    });
  }

  @override
  Stream<List<CourseAccessRequest>> streamStudentRequests(String studentId) {
    return _requestsRef
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return CourseAccessRequest.fromJson(data);
      }).toList();
      list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      return list;
    });
  }

  @override
  Future<void> approveRequest(
    String requestId,
    String studentId,
    String courseId, {
    String? levelId,
  }) async {
    final batch = db.batch();
    final requestRef = _requestsRef.doc(requestId);
    final studentRef = _usersRef.doc(studentId);
    final courseRef = _coursesRef.doc(courseId);

    batch.update(requestRef, {
      'status': 'approved',
      'reviewedAt': FieldValue.serverTimestamp(),
    });

    final isLevelSpecific = levelId != null && levelId.isNotEmpty;

    final studentUpdates = <String, dynamic>{
      'enrolledCourseIds': FieldValue.arrayUnion([courseId]),
      if (isLevelSpecific)
        'levelEntitlements': FieldValue.arrayUnion(['$courseId:$levelId'])
      else
        'fullCourseEntitlements': FieldValue.arrayUnion([courseId]),
    };

    batch.set(
      studentRef,
      studentUpdates,
      SetOptions(merge: true),
    );

    batch.set(
      courseRef,
      {
        'enrolledCount': FieldValue.increment(1),
        'allowedStudentIds': FieldValue.arrayUnion([studentId]),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  @override
  Future<void> rejectRequest(String requestId, {String adminNotes = ''}) async {
    await _requestsRef.doc(requestId).update({
      'status': 'rejected',
      'adminNotes': adminNotes,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }
}

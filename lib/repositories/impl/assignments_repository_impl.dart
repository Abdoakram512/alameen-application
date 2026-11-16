import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/assignment.dart';
import '../../models/assignment_submission.dart';
import '../assignments_repository.dart';

class AssignmentsRepositoryImpl implements AssignmentsRepository {
  final FirebaseFirestore? _explicitFirestore;

  AssignmentsRepositoryImpl({FirebaseFirestore? firestore})
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

  CollectionReference<Map<String, dynamic>> get _assignmentsRef =>
      db.collection('assignments');

  CollectionReference<Map<String, dynamic>> get _submissionsRef =>
      db.collection('submissions');

  @override
  Stream<List<Assignment>> streamAllAssignments() {
    if (!isAvailable) return Stream.value(const <Assignment>[]);
    return _assignmentsRef.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => Assignment.fromMap(doc.data(), id: doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Stream<List<Assignment>> streamCourseAssignments(String courseId) {
    return _assignmentsRef
        .where('courseId', isEqualTo: courseId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => Assignment.fromMap(doc.data(), id: doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Stream<List<AssignmentSubmission>> streamAllSubmissions() {
    return _submissionsRef.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => AssignmentSubmission.fromMap(doc.data(), id: doc.id))
          .toList();
      list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      return list;
    });
  }

  @override
  Stream<List<AssignmentSubmission>> streamPendingSubmissions() {
    return _submissionsRef
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => AssignmentSubmission.fromMap(doc.data(), id: doc.id))
          .toList();
      list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      return list;
    });
  }

  @override
  Stream<List<AssignmentSubmission>> streamStudentSubmissions(String studentId) {
    return _submissionsRef
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => AssignmentSubmission.fromMap(doc.data(), id: doc.id))
          .toList();
      list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      return list;
    });
  }

  @override
  Future<List<AssignmentSubmission>> getCourseSubmissions(String courseId) async {
    try {
      final snapshot = await _submissionsRef
          .where('courseId', isEqualTo: courseId)
          .get(const GetOptions(source: Source.serverAndCache));
      final list = snapshot.docs
          .map((doc) => AssignmentSubmission.fromMap(doc.data(), id: doc.id))
          .toList();
      list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      return list;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> saveAssignment(Assignment assignment) async {
    final docId = assignment.id.trim().isNotEmpty
        ? assignment.id.trim()
        : 'asg_${DateTime.now().millisecondsSinceEpoch}';
    final payload = assignment.toMap()..['id'] = docId;
    await _assignmentsRef.doc(docId).set(payload, SetOptions(merge: true));
  }

  @override
  Future<void> deleteAssignment(String assignmentId) async {
    await _assignmentsRef.doc(assignmentId).delete();
  }

  @override
  Future<void> sendSubmissionFeedback({
    required String submissionId,
    required String feedback,
  }) async {
    await _submissionsRef.doc(submissionId).update({
      'adminFeedback': feedback.trim(),
      'status': 'reviewed',
      'gradedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> gradeSubmission({
    required String submissionId,
    required double grade,
    String? feedback,
  }) async {
    await _submissionsRef.doc(submissionId).update({
      'score': grade.toInt(),
      'adminFeedback': feedback?.trim() ?? '',
      'status': 'graded',
      'gradedAt': DateTime.now().toIso8601String(),
    });
  }
}

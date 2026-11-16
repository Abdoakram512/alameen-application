import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/assignment.dart';
import '../../models/assignment_submission.dart';
import '../student_assignments_repository.dart';

class StudentAssignmentsRepositoryImpl implements StudentAssignmentsRepository {
  final FirebaseFirestore? _explicitFirestore;

  StudentAssignmentsRepositoryImpl({FirebaseFirestore? firestore})
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
  Stream<List<Assignment>> streamCourseAssignments(String courseId) {
    if (!isAvailable) return Stream.value(const <Assignment>[]);
    return _assignmentsRef
        .where('courseId', isEqualTo: courseId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Assignment.fromMap(data, id: doc.id);
      }).toList();
    });
  }

  @override
  Future<Assignment?> getAssignment(String assignmentId) async {
    if (!isAvailable) return null;
    try {
      final doc = await _assignmentsRef.doc(assignmentId).get();
      if (!doc.exists || doc.data() == null) return null;
      return Assignment.fromMap(doc.data()!, id: doc.id);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<AssignmentSubmission>> streamStudentSubmissions(String studentId) {
    if (!isAvailable) return Stream.value(const <AssignmentSubmission>[]);
    return _submissionsRef
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return AssignmentSubmission.fromMap(data, id: doc.id);
      }).toList();
    });
  }

  @override
  Future<List<AssignmentSubmission>> getStudentSubmissions(String studentId) async {
    if (!isAvailable) return const [];
    try {
      final snapshot = await _submissionsRef
          .where('studentId', isEqualTo: studentId)
          .get(const GetOptions(source: Source.serverAndCache));
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return AssignmentSubmission.fromMap(data, id: doc.id);
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> submitAssignment(AssignmentSubmission submission) async {
    if (!isAvailable) return;
    await _submissionsRef.doc(submission.id).set(submission.toMap());
  }
}

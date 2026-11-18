import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/assignment.dart';
import '../models/assignment_submission.dart';
import '../repositories/student_assignments_repository.dart';
import '../repositories/impl/student_assignments_repository_impl.dart';

/// واجهة موحدة لخدمات التكليفات والواجبات المتبقية في Firebase مؤقتاً حتى المرحلة P6.
/// تم استئصال كافة عمليات الدورات والحسابات والمدفوعات والمشاهدة والفيديوهات المحمية من هذه الخدمة بالكامل.
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;

  final FirebaseFirestore? _explicitFirestore;
  final StudentAssignmentsRepository _assignmentsRepository;

  FirestoreService._internal({FirebaseFirestore? firestore})
      : _explicitFirestore = firestore,
        _assignmentsRepository = StudentAssignmentsRepositoryImpl(firestore: firestore);

  FirestoreService.withRepositories({
    FirebaseFirestore? firestore,
    StudentAssignmentsRepository? assignmentsRepository,
  })  : _explicitFirestore = firestore,
        _assignmentsRepository = assignmentsRepository ??
            StudentAssignmentsRepositoryImpl(firestore: firestore);

  FirestoreService.forDatabase(FirebaseFirestore database)
      : _explicitFirestore = database,
        _assignmentsRepository = StudentAssignmentsRepositoryImpl(firestore: database);

  FirebaseFirestore get db => _explicitFirestore ?? FirebaseFirestore.instance;

  bool get isAvailable {
    try {
      final _ = db;
      return true;
    } catch (_) {
      return false;
    }
  }

  StudentAssignmentsRepository get assignmentsRepository => _assignmentsRepository;

  // --- P6 Assignments (Retained until Phase P6) ---

  Stream<List<Assignment>> streamCourseAssignments(String courseId) =>
      _assignmentsRepository.streamCourseAssignments(courseId);

  Future<Assignment?> getAssignment(String assignmentId) =>
      _assignmentsRepository.getAssignment(assignmentId);

  Stream<List<AssignmentSubmission>> streamStudentSubmissions(String studentId) =>
      _assignmentsRepository.streamStudentSubmissions(studentId);

  Future<List<AssignmentSubmission>> getStudentSubmissions(String studentId) =>
      _assignmentsRepository.getStudentSubmissions(studentId);

  Future<void> submitAssignment(AssignmentSubmission submission) =>
      _assignmentsRepository.submitAssignment(submission);
}

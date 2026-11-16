import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/access_request.dart';
import '../models/active_watch_session.dart';
import '../models/assignment.dart';
import '../models/assignment_submission.dart';
import '../models/course.dart';
import '../models/user_profile.dart';
import '../models/watch_log_entry.dart';
import '../repositories/student_assignments_repository.dart';
import '../repositories/student_content_repository.dart';
import '../repositories/student_courses_repository.dart';
import '../repositories/student_profile_repository.dart';
import '../repositories/student_requests_repository.dart';
import '../repositories/student_watch_repository.dart';
import '../repositories/impl/student_assignments_repository_impl.dart';
import '../repositories/impl/student_content_repository_impl.dart';
import '../repositories/impl/student_courses_repository_impl.dart';
import '../repositories/impl/student_profile_repository_impl.dart';
import '../repositories/impl/student_requests_repository_impl.dart';
import '../repositories/impl/student_watch_repository_impl.dart';

/// واجهة خفيفة موحدة (Facade Pattern) لتطبيق الطالب تُغلّف المستودعات المتخصصة الستة
/// وتضمن توافقاً كاملاً بنسبة 100% مع كافة Cubits وشاشات التطبيق والاختبارات الحالية.
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;

  final FirebaseFirestore? _explicitFirestore;

  final StudentCoursesRepository _coursesRepository;
  final StudentProfileRepository _profileRepository;
  final StudentRequestsRepository _requestsRepository;
  final StudentAssignmentsRepository _assignmentsRepository;
  final StudentWatchRepository _watchRepository;
  final StudentContentRepository _contentRepository;

  FirestoreService._internal({FirebaseFirestore? firestore})
      : _explicitFirestore = firestore,
        _coursesRepository = StudentCoursesRepositoryImpl(firestore: firestore),
        _profileRepository = StudentProfileRepositoryImpl(firestore: firestore),
        _requestsRepository = StudentRequestsRepositoryImpl(firestore: firestore),
        _assignmentsRepository = StudentAssignmentsRepositoryImpl(firestore: firestore),
        _watchRepository = StudentWatchRepositoryImpl(firestore: firestore),
        _contentRepository = StudentContentRepositoryImpl(firestore: firestore);

  FirestoreService.withRepositories({
    FirebaseFirestore? firestore,
    StudentCoursesRepository? coursesRepository,
    StudentProfileRepository? profileRepository,
    StudentRequestsRepository? requestsRepository,
    StudentAssignmentsRepository? assignmentsRepository,
    StudentWatchRepository? watchRepository,
    StudentContentRepository? contentRepository,
  })  : _explicitFirestore = firestore,
        _coursesRepository = coursesRepository ?? StudentCoursesRepositoryImpl(firestore: firestore),
        _profileRepository = profileRepository ?? StudentProfileRepositoryImpl(firestore: firestore),
        _requestsRepository = requestsRepository ?? StudentRequestsRepositoryImpl(firestore: firestore),
        _assignmentsRepository = assignmentsRepository ?? StudentAssignmentsRepositoryImpl(firestore: firestore),
        _watchRepository = watchRepository ?? StudentWatchRepositoryImpl(firestore: firestore),
        _contentRepository = contentRepository ?? StudentContentRepositoryImpl(firestore: firestore);

  FirestoreService.forDatabase(FirebaseFirestore database)
      : _explicitFirestore = database,
        _coursesRepository = StudentCoursesRepositoryImpl(firestore: database),
        _profileRepository = StudentProfileRepositoryImpl(firestore: database),
        _requestsRepository = StudentRequestsRepositoryImpl(firestore: database),
        _assignmentsRepository = StudentAssignmentsRepositoryImpl(firestore: database),
        _watchRepository = StudentWatchRepositoryImpl(firestore: database),
        _contentRepository = StudentContentRepositoryImpl(firestore: database);

  FirebaseFirestore get db => _explicitFirestore ?? FirebaseFirestore.instance;

  bool get isAvailable {
    try {
      final _ = db;
      return true;
    } catch (_) {
      return false;
    }
  }

  // --- الوصول المباشر للمستودعات المتخصصة ---
  StudentCoursesRepository get coursesRepository => _coursesRepository;
  StudentProfileRepository get profileRepository => _profileRepository;
  StudentRequestsRepository get requestsRepository => _requestsRepository;
  StudentAssignmentsRepository get assignmentsRepository => _assignmentsRepository;
  StudentWatchRepository get watchRepository => _watchRepository;
  StudentContentRepository get contentRepository => _contentRepository;

  // --- Realtime Streams & Queries Facade ---

  Stream<List<Course>> streamCourses() => _coursesRepository.streamCourses();

  Future<List<Course>> getCourses({Source source = Source.serverAndCache}) =>
      _coursesRepository.getCourses(source: source);

  Stream<UserModel?> streamUser(String uid) => _profileRepository.streamUser(uid);

  Stream<List<CourseAccessRequest>> streamStudentRequests(String studentId) =>
      _requestsRepository.streamStudentRequests(studentId);

  Stream<List<Assignment>> streamCourseAssignments(String courseId) =>
      _assignmentsRepository.streamCourseAssignments(courseId);

  Future<Assignment?> getAssignment(String assignmentId) =>
      _assignmentsRepository.getAssignment(assignmentId);

  Stream<List<AssignmentSubmission>> streamStudentSubmissions(String studentId) =>
      _assignmentsRepository.streamStudentSubmissions(studentId);

  Future<List<AssignmentSubmission>> getStudentSubmissions(String studentId) =>
      _assignmentsRepository.getStudentSubmissions(studentId);

  Stream<List<WatchLogEntry>> streamStudentWatchLogs(String studentId) =>
      _watchRepository.streamStudentWatchLogs(studentId);

  Future<String?> fetchProtectedLessonPlaybackId({
    required String courseId,
    required String lessonId,
  }) =>
      _coursesRepository.fetchProtectedLessonPlaybackId(
        courseId: courseId,
        lessonId: lessonId,
      );

  // --- عمليات التعديل والكتابة ---

  Future<UserModel> syncUserProfile(UserModel user) =>
      _profileRepository.syncUserProfile(user);

  Future<void> sendAccessRequest(CourseAccessRequest request) =>
      _requestsRepository.sendAccessRequest(request);

  Future<void> enrollInOpenCourse(String uid, String courseId) =>
      _coursesRepository.enrollInOpenCourse(uid, courseId);

  Future<void> toggleLessonCompletion(
    String uid,
    String lessonId,
    bool isCompleted,
  ) =>
      _watchRepository.toggleLessonCompletion(uid, lessonId, isCompleted);

  Future<void> updateStudentProfile({
    required String uid,
    required String displayName,
    required String phone,
  }) =>
      _profileRepository.updateStudentProfile(
        uid: uid,
        displayName: displayName,
        phone: phone,
      );

  Future<void> updateStudentPhoto({
    required String uid,
    required String photoUrl,
  }) =>
      _profileRepository.updateStudentPhoto(
        uid: uid,
        photoUrl: photoUrl,
      );

  Future<void> deleteStudentAccount(String uid) =>
      _profileRepository.deleteStudentAccount(uid);

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamAppContent(String docId) =>
      _contentRepository.streamAppContent(docId);

  Future<Map<String, dynamic>?> getAppContent(String docId) =>
      _contentRepository.getAppContent(docId);

  Future<void> submitAssignment(AssignmentSubmission submission) =>
      _assignmentsRepository.submitAssignment(submission);

  Future<void> updateActiveWatchSession(ActiveWatchSession session) =>
      _watchRepository.updateActiveWatchSession(session);

  Future<void> removeActiveWatchSession(String sessionId) =>
      _watchRepository.removeActiveWatchSession(sessionId);

  Future<String?> getLatestLessonCoverage({
    required String uid,
    required String courseId,
    required String lessonId,
  }) =>
      _watchRepository.getLatestLessonCoverage(
        uid: uid,
        courseId: courseId,
        lessonId: lessonId,
      );

  Future<void> recordWatchEvent(Map<String, dynamic> event) =>
      _watchRepository.recordWatchEvent(event);
}

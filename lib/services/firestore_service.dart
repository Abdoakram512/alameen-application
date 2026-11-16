import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/active_watch_session.dart';
import '../models/admin_model.dart';
import '../models/assignment.dart';
import '../models/assignment_submission.dart';
import '../models/course.dart';
import '../models/course_access_mode.dart';
import '../models/course_level.dart';
import '../models/lesson.dart';
import '../models/registered_student.dart';
import '../models/watch_log_entry.dart';
import '../models/access_request.dart';
import '../repositories/admin_analytics_repository.dart';
import '../repositories/admins_repository.dart';
import '../repositories/app_content_repository.dart';
import '../repositories/assignments_repository.dart';
import '../repositories/courses_repository.dart';
import '../repositories/requests_repository.dart';
import '../repositories/students_repository.dart';
import '../repositories/impl/admin_analytics_repository_impl.dart';
import '../repositories/impl/admins_repository_impl.dart';
import '../repositories/impl/app_content_repository_impl.dart';
import '../repositories/impl/assignments_repository_impl.dart';
import '../repositories/impl/courses_repository_impl.dart';
import '../repositories/impl/requests_repository_impl.dart';
import '../repositories/impl/students_repository_impl.dart';

/// واجهة خفيفة موحدة (Facade) تُغلّف المستودعات المتخصصة في تطبيق الإدارة
/// وتوفر توافقاً كاملاً بنسبة 100% مع كافة الواجهات وكتل البناء (Cubits/Widgets) السابقة.
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;

  final FirebaseFirestore? _explicitFirestore;

  final CoursesRepository _coursesRepository;
  final StudentsRepository _studentsRepository;
  final RequestsRepository _requestsRepository;
  final AssignmentsRepository _assignmentsRepository;
  final AdminAnalyticsRepository _analyticsRepository;
  final AdminsRepository _adminsRepository;
  final AppContentRepository _contentRepository;

  FirestoreService._internal({FirebaseFirestore? firestore})
      : _explicitFirestore = firestore,
        _coursesRepository = CoursesRepositoryImpl(firestore: firestore),
        _studentsRepository = StudentsRepositoryImpl(firestore: firestore),
        _requestsRepository = RequestsRepositoryImpl(firestore: firestore),
        _assignmentsRepository = AssignmentsRepositoryImpl(firestore: firestore),
        _analyticsRepository = AdminAnalyticsRepositoryImpl(firestore: firestore),
        _adminsRepository = AdminsRepositoryImpl(firestore: firestore),
        _contentRepository = AppContentRepositoryImpl(firestore: firestore);

  FirestoreService.withRepositories({
    FirebaseFirestore? firestore,
    CoursesRepository? coursesRepository,
    StudentsRepository? studentsRepository,
    RequestsRepository? requestsRepository,
    AssignmentsRepository? assignmentsRepository,
    AdminAnalyticsRepository? analyticsRepository,
    AdminsRepository? adminsRepository,
    AppContentRepository? appContentRepository,
  })  : _explicitFirestore = firestore,
        _coursesRepository = coursesRepository ?? CoursesRepositoryImpl(firestore: firestore),
        _studentsRepository = studentsRepository ?? StudentsRepositoryImpl(firestore: firestore),
        _requestsRepository = requestsRepository ?? RequestsRepositoryImpl(firestore: firestore),
        _assignmentsRepository = assignmentsRepository ?? AssignmentsRepositoryImpl(firestore: firestore),
        _analyticsRepository = analyticsRepository ?? AdminAnalyticsRepositoryImpl(firestore: firestore),
        _adminsRepository = adminsRepository ?? AdminsRepositoryImpl(firestore: firestore),
        _contentRepository = appContentRepository ?? AppContentRepositoryImpl(firestore: firestore);

  FirestoreService.forDatabase(FirebaseFirestore database)
      : _explicitFirestore = database,
        _coursesRepository = CoursesRepositoryImpl(firestore: database),
        _studentsRepository = StudentsRepositoryImpl(firestore: database),
        _requestsRepository = RequestsRepositoryImpl(firestore: database),
        _assignmentsRepository = AssignmentsRepositoryImpl(firestore: database),
        _analyticsRepository = AdminAnalyticsRepositoryImpl(firestore: database),
        _adminsRepository = AdminsRepositoryImpl(firestore: database),
        _contentRepository = AppContentRepositoryImpl(firestore: database);

  FirebaseFirestore get db => _explicitFirestore ?? FirebaseFirestore.instance;

  bool get isAvailable {
    try {
      final _ = db;
      return true;
    } catch (_) {
      return false;
    }
  }


  // مستودعات الميزات المتخصصة
  CoursesRepository get coursesRepository => _coursesRepository;
  StudentsRepository get studentsRepository => _studentsRepository;
  RequestsRepository get requestsRepository => _requestsRepository;
  AssignmentsRepository get assignmentsRepository => _assignmentsRepository;
  AdminAnalyticsRepository get analyticsRepository => _analyticsRepository;
  AdminsRepository get adminsRepository => _adminsRepository;
  AppContentRepository get contentRepository => _contentRepository;

  // --- Courses Facade Methods ---
  Stream<List<Course>> streamCourses() => _coursesRepository.streamCourses();
  Future<void> saveCourse(Course course) => _coursesRepository.saveCourse(course);
  Future<void> deleteCourse(String courseId) => _coursesRepository.deleteCourse(courseId);
  Future<void> addLevelToCourse(String courseId, CourseLevel level) =>
      _coursesRepository.addLevelToCourse(courseId, level);
  Future<void> deleteLevelFromCourse(String courseId, String levelId) =>
      _coursesRepository.deleteLevelFromCourse(courseId, levelId);
  Future<void> addLessonToLevel(
    String courseId,
    String levelId,
    Lesson lesson, {
    Assignment? assignment,
  }) =>
      _coursesRepository.addLessonToLevel(
        courseId,
        levelId,
        lesson,
        assignment: assignment,
      );
  Future<void> updateLessonVideoStatus(
    String courseId,
    String levelId,
    String lessonId, {
    required String videoStatus,
    double? videoProgress,
    String? duration,
    String? videoErrorMessage,
  }) =>
      _coursesRepository.updateLessonVideoStatus(
        courseId,
        levelId,
        lessonId,
        videoStatus: videoStatus,
        videoProgress: videoProgress,
        duration: duration,
        videoErrorMessage: videoErrorMessage,
      );
  Future<void> updateLessonPublishStatus(
    String courseId,
    String levelId,
    String lessonId, {
    required bool isPublished,
    DateTime? scheduledPublishAt,
  }) =>
      _coursesRepository.updateLessonPublishStatus(
        courseId,
        levelId,
        lessonId,
        isPublished: isPublished,
        scheduledPublishAt: scheduledPublishAt,
      );
  Future<void> deleteLessonFromLevel(
    String courseId,
    String levelId,
    String lessonId,
  ) =>
      _coursesRepository.deleteLessonFromLevel(courseId, levelId, lessonId);
  Future<void> setCourseAccessMode(String courseId, CourseAccessMode mode) =>
      _coursesRepository.setCourseAccessMode(courseId, mode);

  // --- Students Facade Methods ---
  Stream<List<RegisteredStudent>> streamStudents() =>
      _studentsRepository.streamStudents();
  Future<List<RegisteredStudent>> getStudents({
    Source source = Source.serverAndCache,
  }) =>
      _studentsRepository.getStudents(forceRefresh: source == Source.server);
  Future<int> getStudentsCount() => _studentsRepository.getStudentsCount();
  Future<void> toggleStudentCourse(String studentId, String courseId, bool grant) =>
      _studentsRepository.toggleStudentCourse(studentId, courseId, grant);
  Future<void> toggleStudentSuspension(
    String studentId, {
    required bool suspend,
    String? reason,
  }) =>
      _studentsRepository.toggleStudentSuspension(
        studentId,
        suspend: suspend,
        reason: reason,
      );
  Future<void> deleteStudentAccount(String studentId) =>
      _studentsRepository.deleteStudentAccount(studentId);
  Future<int> assignStudentsToCourse({
    required String courseId,
    required List<String> studentIds,
    required bool grant,
  }) =>
      _studentsRepository.assignStudentsToCourse(
        courseId: courseId,
        studentIds: studentIds,
        grant: grant,
      );
  Future<int> extendCourseValidityForAll({
    required String courseId,
    required int additionalDays,
  }) =>
      _studentsRepository.extendCourseValidityForAll(
        courseId: courseId,
        additionalDays: additionalDays,
      );
  Future<void> extendStudentCourseValidity({
    required String studentId,
    required String courseId,
    required int additionalDays,
  }) =>
      _studentsRepository.extendStudentCourseValidity(
        studentId: studentId,
        courseId: courseId,
        additionalDays: additionalDays,
      );
  Future<int> revokeCourseAccessForAll(String courseId) =>
      _studentsRepository.revokeCourseAccessForAll(courseId);
  Future<void> bulkSuspendStudents({
    required List<String> studentIds,
    required bool suspend,
    String? reason,
  }) =>
      _studentsRepository.bulkSuspendStudents(
        studentIds: studentIds,
        suspend: suspend,
        reason: reason,
      );
  Future<void> bulkDeleteStudents(List<String> studentIds) =>
      _studentsRepository.bulkDeleteStudents(studentIds);

  // --- Requests Facade Methods ---
  Stream<List<CourseAccessRequest>> streamRequests() =>
      _requestsRepository.streamRequests();
  Stream<List<CourseAccessRequest>> streamStudentRequests(String studentId) =>
      _requestsRepository.streamStudentRequests(studentId);
  Future<void> approveRequest(
    String requestId,
    String studentId,
    String courseId, {
    String? levelId,
  }) =>
      _requestsRepository.approveRequest(
        requestId,
        studentId,
        courseId,
        levelId: levelId,
      );
  Future<void> rejectRequest(String requestId, {String adminNotes = ''}) =>
      _requestsRepository.rejectRequest(requestId, adminNotes: adminNotes);

  // --- Assignments Facade Methods ---
  Stream<List<Assignment>> streamAllAssignments() =>
      _assignmentsRepository.streamAllAssignments();
  Stream<List<Assignment>> streamCourseAssignments(String courseId) =>
      _assignmentsRepository.streamCourseAssignments(courseId);
  Stream<List<AssignmentSubmission>> streamAllSubmissions() =>
      _assignmentsRepository.streamAllSubmissions();
  Stream<List<AssignmentSubmission>> streamPendingSubmissions() =>
      _assignmentsRepository.streamPendingSubmissions();
  Stream<List<AssignmentSubmission>> streamStudentSubmissions(String studentId) =>
      _assignmentsRepository.streamStudentSubmissions(studentId);
  Future<List<AssignmentSubmission>> getCourseSubmissions(String courseId) =>
      _assignmentsRepository.getCourseSubmissions(courseId);
  Future<void> saveAssignment(Assignment assignment) =>
      _assignmentsRepository.saveAssignment(assignment);
  Future<void> deleteAssignment(String assignmentId) =>
      _assignmentsRepository.deleteAssignment(assignmentId);
  Future<void> sendSubmissionFeedback({
    required String submissionId,
    required String adminFeedback,
  }) =>
      _assignmentsRepository.sendSubmissionFeedback(
        submissionId: submissionId,
        feedback: adminFeedback,
      );
  Future<void> gradeSubmission({
    required String submissionId,
    required int score,
    required String adminFeedback,
  }) =>
      _assignmentsRepository.gradeSubmission(
        submissionId: submissionId,
        grade: score.toDouble(),
        feedback: adminFeedback,
      );

  // --- Analytics & Watch Logs Facade Methods ---
  Stream<List<WatchLogEntry>> streamAllWatchLogs({int limit = 50}) =>
      _analyticsRepository.streamAllWatchLogs(limit: limit);
  Future<List<WatchLogEntry>> getRecentWatchLogs({int limit = 50}) =>
      _analyticsRepository.getRecentWatchLogs(limit: limit);
  Stream<List<WatchLogEntry>> streamStudentWatchLogs(String studentId) =>
      _analyticsRepository.streamStudentWatchLogs(studentId);
  Stream<List<ActiveWatchSession>> streamActiveWatchSessions({
    String? courseId,
    String? lessonId,
  }) =>
      _analyticsRepository.streamActiveWatchSessions(
        courseId: courseId,
        lessonId: lessonId,
      );
  Stream<List<WatchLogEntry>> streamLessonWatchLogs({
    required String courseId,
    required String lessonId,
  }) =>
      _analyticsRepository.streamLessonWatchLogs(
        courseId: courseId,
        lessonId: lessonId,
      );

  // --- Admins Facade Methods ---
  Stream<List<AdminModel>> streamAdmins() => _adminsRepository.streamAdmins();
  Future<AdminModel?> getAdminByEmail(String email) =>
      _adminsRepository.getAdminByEmail(email);
  Future<AdminModel?> getAdminByUid(String uid) =>
      _adminsRepository.getAdminByUid(uid);
  Future<void> saveAdmin(AdminModel admin) =>
      _adminsRepository.saveAdmin(admin);
  Future<void> updateAdminPermissions(
    String adminId, {
    required AdminRole role,
    required List<String> permissions,
  }) =>
      _adminsRepository.updateAdminPermissions(
        adminId,
        role: role,
        permissions: permissions,
      );
  Future<void> toggleAdminStatus(String adminId, bool isActive) =>
      _adminsRepository.toggleAdminStatus(adminId, isActive);
  Future<void> deleteAdmin(String adminId) =>
      _adminsRepository.deleteAdmin(adminId);
  Future<AdminModel> ensureRootAdminProvisioned({
    required String rootEmail,
    String? rootUid,
  }) =>
      _adminsRepository.ensureRootAdminProvisioned(
        rootEmail: rootEmail,
        rootUid: rootUid,
      );

  // --- App Content Facade Methods ---
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamAppContent(String docId) =>
      _contentRepository.streamAppContent(docId);
  Future<void> saveAppContent({
    required String docId,
    required String title,
    required dynamic content,
  }) =>
      _contentRepository.saveAppContent(
        docId: docId,
        title: title,
        content: content,
      );
}

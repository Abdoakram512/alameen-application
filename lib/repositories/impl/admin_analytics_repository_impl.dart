import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/active_watch_session.dart';
import '../../models/watch_log_entry.dart';
import '../admin_analytics_repository.dart';

class AdminAnalyticsRepositoryImpl implements AdminAnalyticsRepository {
  final FirebaseFirestore? _explicitFirestore;

  AdminAnalyticsRepositoryImpl({FirebaseFirestore? firestore})
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

  CollectionReference<Map<String, dynamic>> get _watchLogsRef =>
      db.collection('watch_logs');

  CollectionReference<Map<String, dynamic>> get _activeSessionsRef =>
      db.collection('active_watch_sessions');

  @override
  Stream<List<WatchLogEntry>> streamAllWatchLogs({int limit = 50}) {
    if (!isAvailable) return Stream.value(const <WatchLogEntry>[]);
    return _watchLogsRef.limit(limit).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => WatchLogEntry.fromMap(doc.data(), id: doc.id))
          .toList();
      list.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      return list;
    });
  }

  @override
  Future<List<WatchLogEntry>> getRecentWatchLogs({int limit = 50}) async {
    if (!isAvailable) return const [];
    try {
      final snapshot = await _watchLogsRef
          .limit(limit)
          .get(const GetOptions(source: Source.serverAndCache));
      final list = snapshot.docs
          .map((doc) => WatchLogEntry.fromMap(doc.data(), id: doc.id))
          .toList();
      list.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      return list;
    } catch (_) {
      return const [];
    }
  }

  @override
  Stream<List<WatchLogEntry>> streamStudentWatchLogs(String studentId) {
    if (!isAvailable) return Stream.value(const <WatchLogEntry>[]);
    return _watchLogsRef
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => WatchLogEntry.fromMap(doc.data(), id: doc.id))
          .toList();
      list.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      return list;
    });
  }

  @override
  Stream<List<ActiveWatchSession>> streamActiveWatchSessions({
    String? courseId,
    String? lessonId,
  }) {
    if (!isAvailable) return Stream.value(const <ActiveWatchSession>[]);
    Query<Map<String, dynamic>> query = _activeSessionsRef;
    if (courseId != null && courseId.isNotEmpty) {
      query = query.where('courseId', isEqualTo: courseId);
    }
    if (lessonId != null && lessonId.isNotEmpty) {
      query = query.where('lessonId', isEqualTo: lessonId);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ActiveWatchSession.fromMap(doc.data(), id: doc.id))
          .where((sess) => !sess.isStaleWithGrace(60) && sess.isPlaying)
          .toList();
    });
  }

  @override
  Stream<List<WatchLogEntry>> streamLessonWatchLogs({
    required String courseId,
    required String lessonId,
  }) {
    if (!isAvailable) return Stream.value(const <WatchLogEntry>[]);
    return _watchLogsRef
        .where('courseId', isEqualTo: courseId)
        .where('lessonId', isEqualTo: lessonId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WatchLogEntry.fromMap(doc.data(), id: doc.id))
          .toList();
    });
  }
}

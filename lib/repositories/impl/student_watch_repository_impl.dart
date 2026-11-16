import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/active_watch_session.dart';
import '../../models/watch_log_entry.dart';
import '../student_watch_repository.dart';

class StudentWatchRepositoryImpl implements StudentWatchRepository {
  final FirebaseFirestore? _explicitFirestore;

  StudentWatchRepositoryImpl({FirebaseFirestore? firestore})
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

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      db.collection('users');

  @override
  Stream<List<WatchLogEntry>> streamStudentWatchLogs(String studentId) {
    if (!isAvailable) return Stream.value(const <WatchLogEntry>[]);
    return _watchLogsRef
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        return WatchLogEntry.fromMap(data, id: doc.id);
      }).toList();
      items.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      return items;
    });
  }

  @override
  Future<void> updateActiveWatchSession(ActiveWatchSession session) async {
    if (!isAvailable) return;
    try {
      final data = session.toMap()
        ..['lastHeartbeatAt'] = FieldValue.serverTimestamp()
        ..['startedAt'] = Timestamp.fromDate(session.startedAt);
      await _activeSessionsRef
          .doc(session.id)
          .set(data, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  @override
  Future<void> removeActiveWatchSession(String sessionId) async {
    if (!isAvailable) return;
    try {
      await _activeSessionsRef
          .doc(sessionId)
          .delete()
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  @override
  Future<String?> getLatestLessonCoverage({
    required String uid,
    required String courseId,
    required String lessonId,
  }) async {
    if (!isAvailable) return null;
    try {
      final snapshot = await _watchLogsRef
          .where('studentId', isEqualTo: uid)
          .where('courseId', isEqualTo: courseId)
          .where('lessonId', isEqualTo: lessonId)
          .limit(1)
          .get(const GetOptions(source: Source.serverAndCache));
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data()['coverageRanges'] as String?;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> toggleLessonCompletion(
    String uid,
    String lessonId,
    bool isCompleted,
  ) async {
    if (!isAvailable) return;
    await _usersRef.doc(uid).set(
      {
        'completedLessonIds': isCompleted
            ? FieldValue.arrayUnion([lessonId])
            : FieldValue.arrayRemove([lessonId]),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> recordWatchEvent(Map<String, dynamic> event) async {
    if (!isAvailable) return;
    final uid = event['uid'] as String;
    final seconds = (event['seconds'] as num?)?.toInt() ?? 0;
    final sessionSeconds = (event['sessionSeconds'] as num?)?.toInt() ?? seconds;
    final isSessionEnd = event['isSessionEnd'] == true;
    final isCompleted = event['isCompleted'] == true;
    final courseId = event['courseId'] as String? ?? '';
    final lessonId = event['lessonId'] as String? ?? '';
    final sessionId = event['sessionId'] as String?;
    final eventId = event['id'] as String? ?? '';
    final coverageRanges = event['coverageRanges'] as String?;

    final logDocId = (sessionId != null && sessionId.isNotEmpty)
        ? 'watch_${uid}_${courseId}_${lessonId}_$sessionId'
        : '${uid}_$eventId';
    final logRef = _watchLogsRef.doc(logDocId);

    if (isCompleted || isSessionEnd) {
      // Transaction ensures:
      // 1. Retry of the same session-end event NEVER double-increments users.totalWatchSeconds.
      // 2. Older checkpoints cannot overwrite newer progress (durationSeconds monotonically increases).
      // 3. User document completedLessonIds and watch seconds are committed atomically.
      await db.runTransaction((tx) async {
        final logSnap = await tx.get(logRef);
        final existingDuration = (logSnap.data()?['durationSeconds'] as num?)?.toInt() ?? 0;
        final safeSessionSeconds = sessionSeconds >= existingDuration ? sessionSeconds : existingDuration;
        final alreadyCommittedInLog = logSnap.data()?['sessionEndCommitted'] == true;

        final logData = <String, dynamic>{
          'id': logDocId,
          'studentId': uid,
          'studentUid': uid,
          'studentName': event['studentName'] ?? '',
          'studentEmail': event['studentEmail'] ?? '',
          'courseId': courseId,
          'lessonId': lessonId,
          'lessonTitle': event['lessonTitle'] ?? '',
          'durationSeconds': safeSessionSeconds,
          'secondsWatched': safeSessionSeconds,
          'maxPlayheadSeconds': event['maxPlayheadSeconds'] ?? safeSessionSeconds,
          'totalDurationSeconds': event['totalDurationSeconds'] ?? 0,
          'completionPercentage': event['completionPercentage'] ?? 0.0,
          'isCompleted': isCompleted || (logSnap.data()?['isCompleted'] == true),
          'sessionEndCommitted': alreadyCommittedInLog || isSessionEnd,
          'lastCheckpointId': eventId,
          if (coverageRanges != null && coverageRanges.isNotEmpty)
            'coverageRanges': coverageRanges,
          'ipAddress': event['ipAddress'] ?? 'غير محدد',
          'networkType': event['networkType'] ?? 'غير محدد',
          'devicePlatform': event['devicePlatform'] ?? 'جهاز ذكي',
          'recordedAt': FieldValue.serverTimestamp(),
        };
        tx.set(logRef, logData, SetOptions(merge: true));

        final userRef = _usersRef.doc(uid);
        final userSnap = await tx.get(userRef);
        final userData = userSnap.data() ?? {};
        final processedEvents = List<String>.from(userData['processedSessionEnds'] ?? []);

        final userUpdates = <String, dynamic>{
          'lastActiveAt': FieldValue.serverTimestamp(),
          if (event['ipAddress'] != null) 'lastKnownIp': event['ipAddress'],
          if (isCompleted && lessonId.isNotEmpty)
            'completedLessonIds': FieldValue.arrayUnion([lessonId]),
        };

        if (isSessionEnd && seconds > 0 && !alreadyCommittedInLog) {
          if (!processedEvents.contains(eventId)) {
            // First time processing this session-end event: increment totalWatchSeconds safely
            processedEvents.add(eventId);
            if (processedEvents.length > 50) {
              processedEvents.removeAt(0); // Maintain sliding window of 50
            }
            final currentTotal = (userData['totalWatchSeconds'] as num?)?.toInt() ?? 0;
            userUpdates['totalWatchSeconds'] = currentTotal + seconds;
            userUpdates['processedSessionEnds'] = processedEvents;
          }
        }

        tx.set(userRef, userUpdates, SetOptions(merge: true));
      }).timeout(const Duration(seconds: 15));
    } else {
      // Continuous intermediate playback checkpoint: writes only to watch_logs (0 writes to users/{uid})
      await db.runTransaction((tx) async {
        final logSnap = await tx.get(logRef);
        final existingDuration = (logSnap.data()?['durationSeconds'] as num?)?.toInt() ?? 0;
        final safeSessionSeconds = sessionSeconds >= existingDuration ? sessionSeconds : existingDuration;

        final logData = <String, dynamic>{
          'id': logDocId,
          'studentId': uid,
          'studentUid': uid,
          'studentName': event['studentName'] ?? '',
          'studentEmail': event['studentEmail'] ?? '',
          'courseId': courseId,
          'lessonId': lessonId,
          'lessonTitle': event['lessonTitle'] ?? '',
          'durationSeconds': safeSessionSeconds,
          'secondsWatched': safeSessionSeconds,
          'maxPlayheadSeconds': event['maxPlayheadSeconds'] ?? safeSessionSeconds,
          'totalDurationSeconds': event['totalDurationSeconds'] ?? 0,
          'completionPercentage': event['completionPercentage'] ?? 0.0,
          'isCompleted': isCompleted || (logSnap.data()?['isCompleted'] == true),
          'lastCheckpointId': eventId,
          if (coverageRanges != null && coverageRanges.isNotEmpty)
            'coverageRanges': coverageRanges,
          'ipAddress': event['ipAddress'] ?? 'غير محدد',
          'networkType': event['networkType'] ?? 'غير محدد',
          'devicePlatform': event['devicePlatform'] ?? 'جهاز ذكي',
          'recordedAt': FieldValue.serverTimestamp(),
        };
        tx.set(logRef, logData, SetOptions(merge: true));
      }).timeout(const Duration(seconds: 15));
    }
  }
}

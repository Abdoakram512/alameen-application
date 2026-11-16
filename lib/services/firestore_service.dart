import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/access_request.dart';
import '../models/active_watch_session.dart';
import '../models/assignment.dart';
import '../models/assignment_submission.dart';
import '../models/course.dart';
import '../models/course_level.dart';
import '../models/lesson.dart';
import '../models/user_profile.dart';
import '../models/watch_log_entry.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _coursesRef =>
      _db.collection('courses');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> get _requestsRef =>
      _db.collection('access_requests');

  CollectionReference<Map<String, dynamic>> get _assignmentsRef =>
      _db.collection('assignments');

  CollectionReference<Map<String, dynamic>> get _submissionsRef =>
      _db.collection('submissions');

  CollectionReference<Map<String, dynamic>> get _watchLogsRef =>
      _db.collection('watch_logs');

  CollectionReference<Map<String, dynamic>> get _activeSessionsRef =>
      _db.collection('active_watch_sessions');

  CollectionReference<Map<String, dynamic>> get _appContentRef =>
      _db.collection('app_content');

  // --- Realtime Streams ---

  Stream<List<Course>> streamCourses() {
    return _coursesRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        final course = Course.fromMap(data);

        // ضمان الترتيب الصارم للمستويات والدروس
        final sortedLevels = List<CourseLevel>.from(course.levels)
          ..sort((a, b) => a.order.compareTo(b.order));
        final finalLevels = sortedLevels.map((lvl) {
          final sortedLessons = List<Lesson>.from(lvl.lessons)
            ..sort((a, b) => a.order.compareTo(b.order));
          return lvl.copyWith(lessons: sortedLessons);
        }).toList();

        return course.copyWith(levels: finalLevels);
      }).toList();
    });
  }

  Future<List<Course>> getCourses({Source source = Source.serverAndCache}) async {
    try {
      final snapshot = await _coursesRef.get(GetOptions(source: source));
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        final course = Course.fromMap(data);

        final sortedLevels = List<CourseLevel>.from(course.levels)
          ..sort((a, b) => a.order.compareTo(b.order));
        final finalLevels = sortedLevels.map((lvl) {
          final sortedLessons = List<Lesson>.from(lvl.lessons)
            ..sort((a, b) => a.order.compareTo(b.order));
          return lvl.copyWith(lessons: sortedLessons);
        }).toList();

        return course.copyWith(levels: finalLevels);
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Stream<UserModel?> streamUser(String uid) {
    return _usersRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromMap(doc.data()!, uid: doc.id);
    });
  }

  Stream<List<CourseAccessRequest>> streamStudentRequests(String studentId) {
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

  Stream<List<Assignment>> streamCourseAssignments(String courseId) {
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

  Future<Assignment?> getAssignment(String assignmentId) async {
    try {
      final doc = await _assignmentsRef.doc(assignmentId).get();
      if (!doc.exists || doc.data() == null) return null;
      return Assignment.fromMap(doc.data()!, id: doc.id);
    } catch (_) {
      return null;
    }
  }

  Stream<List<AssignmentSubmission>> streamStudentSubmissions(String studentId) {
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

  Future<List<AssignmentSubmission>> getStudentSubmissions(String studentId) async {
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

  /// بث سجلات المشاهدة للمتدرب مرتبة زمنياً في Dart لتجنب الحاجة لفهرس مركب (Composite Index).
  Stream<List<WatchLogEntry>> streamStudentWatchLogs(String studentId) {
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

  /// جلب معرف البث المحمي للدرس من المجموعة الفرعية المحمية للمتدربين المشتركين فقط.
  Future<String?> fetchProtectedLessonPlaybackId({
    required String courseId,
    required String lessonId,
  }) async {
    final doc = await _coursesRef
        .doc(courseId)
        .collection('protected_lessons')
        .doc(lessonId)
        .get();
    final playbackId = (doc.data()?['muxPlaybackId'] as String?)?.trim();
    if (playbackId == null || playbackId.isEmpty) return null;
    return playbackId;
  }

  // --- عمليات الكتابة السحابية ---

  Future<UserModel> syncUserProfile(UserModel user) async {
    final docRef = _usersRef.doc(user.uid);
    DocumentSnapshot<Map<String, dynamic>>? existingSnap;
    try {
      existingSnap = await docRef.get().timeout(
            const Duration(seconds: 4),
            onTimeout: () => docRef.get(const GetOptions(source: Source.cache)),
          );
    } catch (_) {
      try {
        existingSnap = await docRef.get(const GetOptions(source: Source.cache));
      } catch (_) {}
    }
    final existingData = existingSnap?.data();
    final docExists = existingSnap?.exists ?? false;

    final payload = <String, dynamic>{
      'uid': user.uid,
      'id': user.uid,
      'email': user.email,
      'role': 'student',
      'appOrigin': 'alameen_speech_center',
      'registeredPlatform': 'alameen_mobile_app',
      'lastActiveAt': FieldValue.serverTimestamp(),
    };

    if (!docExists) {
      payload['displayName'] = user.displayName;
      payload['name'] = user.displayName;
      payload['photoUrl'] = user.photoUrl;
      payload['phone'] = user.phone;
      payload['createdAt'] = FieldValue.serverTimestamp();
      payload['joinedAt'] = FieldValue.serverTimestamp();
      payload['enrolledCourseIds'] = <String>[];
    } else {
      payload['name'] = user.displayName;
      if (user.displayName.trim().isNotEmpty &&
          user.displayName != 'طالب الأمين سنتر') {
        payload['displayName'] = user.displayName.trim();
      }
      if (user.photoUrl.trim().isNotEmpty) {
        payload['photoUrl'] = user.photoUrl.trim();
      }
      if (user.phone.trim().isNotEmpty) {
        payload['phone'] = user.phone.trim();
      }
    }

    bool needsWrite = !docExists;
    if (docExists && existingData != null) {
      if (payload.containsKey('displayName') &&
          existingData['displayName'] != payload['displayName']) {
        needsWrite = true;
      }
      if (payload.containsKey('photoUrl') &&
          existingData['photoUrl'] != payload['photoUrl']) {
        needsWrite = true;
      }
      if (payload.containsKey('phone') &&
          existingData['phone'] != payload['phone']) {
        needsWrite = true;
      }
      final lastActive = existingData['lastActiveAt'];
      if (lastActive is Timestamp) {
        if (DateTime.now().difference(lastActive.toDate()).inMinutes > 30) {
          needsWrite = true;
        }
      } else {
        needsWrite = true;
      }
    }

    if (needsWrite) {
      try {
        await docRef.set(payload, SetOptions(merge: true)).timeout(
              const Duration(seconds: 8),
            );
      } catch (e) {
        debugPrint('Firestore syncUserProfile set error: $e');
      }
    }

    if (existingData != null) {
      final merged = Map<String, dynamic>.from(existingData);
      if (payload.containsKey('displayName')) {
        merged['displayName'] = payload['displayName'];
      }
      if (payload.containsKey('photoUrl')) {
        merged['photoUrl'] = payload['photoUrl'];
      }
      if (payload.containsKey('phone')) {
        merged['phone'] = payload['phone'];
      }
      merged['email'] = user.email;
      return UserModel.fromMap(merged, uid: user.uid);
    }
    return user;
  }

  Future<void> sendAccessRequest(CourseAccessRequest request) async {
    await _db.runTransaction((transaction) async {
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

  Future<void> enrollInOpenCourse(String uid, String courseId) async {
    await _usersRef.doc(uid).set(
      {
        'enrolledCourseIds': FieldValue.arrayUnion([courseId]),
        'lastEnrolledCourseId': courseId,
      },
      SetOptions(merge: true),
    );
    try {
      await _coursesRef.doc(courseId).set(
        {
          'enrolledCount': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  Future<void> toggleLessonCompletion(
    String uid,
    String lessonId,
    bool isCompleted,
  ) async {
    await _usersRef.doc(uid).set(
      {
        'completedLessonIds': isCompleted
            ? FieldValue.arrayUnion([lessonId])
            : FieldValue.arrayRemove([lessonId]),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateStudentProfile({
    required String uid,
    required String displayName,
    required String phone,
  }) async {
    await _usersRef.doc(uid).set(
      {
        'displayName': displayName.trim(),
        'phone': phone.trim(),
        'lastActiveAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateStudentPhoto({
    required String uid,
    required String photoUrl,
  }) async {
    await _usersRef.doc(uid).set(
      {
        'photoUrl': photoUrl.trim(),
        'lastActiveAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> deleteStudentAccount(String uid) async {
    try {
      final sessions = await _activeSessionsRef
          .where('studentId', isEqualTo: uid)
          .get()
          .timeout(const Duration(seconds: 4));
      for (final doc in sessions.docs) {
        try {
          await doc.reference.delete().timeout(const Duration(seconds: 2));
        } catch (_) {}
      }
    } catch (_) {}

    try {
      final requests = await _requestsRef
          .where('studentId', isEqualTo: uid)
          .get()
          .timeout(const Duration(seconds: 4));
      for (final doc in requests.docs) {
        try {
          await doc.reference.delete().timeout(const Duration(seconds: 2));
        } catch (_) {}
      }
    } catch (_) {}

    try {
      await _usersRef.doc(uid).delete().timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('deleteStudentAccount usersRef error: $e');
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamAppContent(String docId) {
    return _appContentRef.doc(docId).snapshots();
  }

  Future<Map<String, dynamic>?> getAppContent(String docId) async {
    try {
      final doc = await _appContentRef.doc(docId).get();
      if (doc.exists && doc.data() != null) {
        return doc.data();
      }
    } catch (_) {}
    return null;
  }

  Future<void> submitAssignment(AssignmentSubmission submission) async {
    await _submissionsRef.doc(submission.id).set(submission.toMap());
  }

  Future<void> updateActiveWatchSession(ActiveWatchSession session) async {
    try {
      await _activeSessionsRef
          .doc(session.id)
          .set(session.toMap(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  Future<void> removeActiveWatchSession(String sessionId) async {
    try {
      await _activeSessionsRef
          .doc(sessionId)
          .delete()
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  Future<String?> getLatestLessonCoverage({
    required String uid,
    required String courseId,
    required String lessonId,
  }) async {
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

  Future<void> recordWatchEvent(Map<String, dynamic> event) async {
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
      await _db.runTransaction((tx) async {
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

        if (isSessionEnd && seconds > 0) {
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
      await _db.runTransaction((tx) async {
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

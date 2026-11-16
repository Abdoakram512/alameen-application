import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/access_request.dart';
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

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();
  FirebaseFirestore? _database;
  FirestoreService.forDatabase(FirebaseFirestore database)
      : _database = database;
  FirebaseFirestore get db => _database ?? FirebaseFirestore.instance;

  bool get isAvailable {
    try {
      FirebaseFirestore.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  CollectionReference<Map<String, dynamic>> get _coursesRef =>
      db.collection('courses');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      db.collection('users');

  CollectionReference<Map<String, dynamic>> get _requestsRef =>
      db.collection('access_requests');

  CollectionReference<Map<String, dynamic>> get _assignmentsRef =>
      db.collection('assignments');

  CollectionReference<Map<String, dynamic>> get _submissionsRef =>
      db.collection('submissions');

  CollectionReference<Map<String, dynamic>> get _watchLogsRef =>
      db.collection('watch_logs');

  CollectionReference<Map<String, dynamic>> get _activeSessionsRef =>
      db.collection('active_watch_sessions');

  CollectionReference<Map<String, dynamic>> get _adminsRef =>
      db.collection('admins');

  CollectionReference<Map<String, dynamic>> get _appContentRef =>
      db.collection('app_content');

  CollectionReference<Map<String, dynamic>> _protectedLessonsRef(
    String courseId,
  ) =>
      _coursesRef.doc(courseId).collection('protected_lessons');

  // --- Realtime Streams من Firestore الحقيقية ---

  /// استماع حي لقائمة الكورسات
  Stream<List<Course>> streamCourses() {
    return _coursesRef.snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Course.fromMap(data);
      }).toList();

      return list.map((c) {
        final sortedLevels = List<CourseLevel>.from(c.levels)
          ..sort((a, b) => a.order.compareTo(b.order));
        final finalLevels = sortedLevels.map((lvl) {
          final sortedLessons = List<Lesson>.from(lvl.lessons)
            ..sort((a, b) => a.order.compareTo(b.order));
          return lvl.copyWith(lessons: sortedLessons);
        }).toList();
        return c.copyWith(levels: finalLevels);
      }).toList();
    });
  }

  /// استماع حي لقائمة الطلاب الحقيقيين المسجلين في Firebase
  Stream<List<RegisteredStudent>> streamStudents() {
    return _usersRef.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return RegisteredStudent.fromJson(data);
          })
          .where(
            (s) =>
                s.role != 'admin' &&
                (s.appOrigin.isEmpty ||
                    s.appOrigin == 'alameen_speech_center'),
          )
          .toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  /// جلب قائمة الطلاب الحقيقيين المسجلين لمرة واحدة
  Future<List<RegisteredStudent>> getStudents({Source source = Source.serverAndCache}) async {
    try {
      final snapshot = await _usersRef.get(GetOptions(source: source));
      final list = snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return RegisteredStudent.fromJson(data);
          })
          .where(
            (s) =>
                s.role != 'admin' &&
                (s.appOrigin.isEmpty ||
                    s.appOrigin == 'alameen_speech_center'),
          )
          .toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (_) {
      return const [];
    }
  }

  /// جلب عدد الطلاب المسجلين بالاستعلام التجميعي دون قراءة الوثائق
  Future<int> getStudentsCount() async {
    try {
      final countQuery = await _usersRef.count().get();
      return countQuery.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// استماع حي لطلبات الانضمام الحقيقية
  Stream<List<CourseAccessRequest>> streamRequests() {
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

  /// استماع لطلبات طالب محدد
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

  /// استماع حي لسجلات المشاهدة العامة عبر المنصة (للإحصائيات العامة)
  Stream<List<WatchLogEntry>> streamAllWatchLogs({int limit = 50}) {
    return _watchLogsRef.limit(limit).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => WatchLogEntry.fromMap(doc.data(), id: doc.id))
          .toList();
      list.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      return list;
    });
  }

  /// جلب سجلات المشاهدة الأخيرة لمرة واحدة
  Future<List<WatchLogEntry>> getRecentWatchLogs({int limit = 50}) async {
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

  /// استماع حي لسجلات المشاهدة لطالب محدد (مرتبة في Dart دون الحاجة لـ Composite Index)
  Stream<List<WatchLogEntry>> streamStudentWatchLogs(String studentId) {
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

  /// استماع حي لجلسات المشاهدة النشطة حالياً عبر المنصة على الرادار
  Stream<List<ActiveWatchSession>> streamActiveWatchSessions({
    String? courseId,
    String? lessonId,
  }) {
    if (!isAvailable) {
      return Stream.value(const <ActiveWatchSession>[]);
    }
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

  /// استماع حي لسجلات المشاهدة لدرس محدد لمقارنة من شاهد ومن لم يشاهد بعد
  Stream<List<WatchLogEntry>> streamLessonWatchLogs({
    required String courseId,
    required String lessonId,
  }) {
    if (!isAvailable) {
      return Stream.value(const <WatchLogEntry>[]);
    }
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

  /// استماع لكافة المهام والتكليفات عبر جميع الكورسات
  Stream<List<Assignment>> streamAllAssignments() {
    if (!isAvailable) {
      return Stream.value(const <Assignment>[]);
    }
    return _assignmentsRef.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => Assignment.fromMap(doc.data(), id: doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// استماع لتكليفات كورس محدد
  Stream<List<Assignment>> streamCourseAssignments(String courseId) {
    if (!isAvailable) {
      return Stream.value(const <Assignment>[]);
    }
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

  /// استماع لكافة تسليمات الطلاب للتقييم
  Stream<List<AssignmentSubmission>> streamAllSubmissions() {
    return _submissionsRef.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => AssignmentSubmission.fromMap(doc.data(), id: doc.id))
          .toList();
      list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      return list;
    });
  }

  /// استماع لتسليمات الطلاب قيد الانتظار فقط (للإحصائيات السريعة والتنبيهات)
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

  /// جلب تسليمات كورس محدد لمرة واحدة
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

  /// استماع لتسليمات طالب محدد
  Stream<List<AssignmentSubmission>> streamStudentSubmissions(
    String studentId,
  ) {
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

  Future<void> saveAssignment(Assignment assignment) async {
    final docId = assignment.id.trim().isNotEmpty
        ? assignment.id.trim()
        : 'asg_${DateTime.now().millisecondsSinceEpoch}';
    final payload = assignment.toMap()..['id'] = docId;
    await _assignmentsRef.doc(docId).set(payload, SetOptions(merge: true));
  }

  Future<void> deleteAssignment(String assignmentId) async {
    await _assignmentsRef.doc(assignmentId).delete();
  }

  Future<void> sendSubmissionFeedback({
    required String submissionId,
    required String adminFeedback,
  }) async {
    await _submissionsRef.doc(submissionId).update({
      'adminFeedback': adminFeedback.trim(),
      'status': 'reviewed',
      'gradedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> gradeSubmission({
    required String submissionId,
    required int score,
    required String adminFeedback,
  }) async {
    await _submissionsRef.doc(submissionId).update({
      'score': score,
      'adminFeedback': adminFeedback.trim(),
      'status': 'graded',
      'gradedAt': DateTime.now().toIso8601String(),
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamAppContent(String docId) {
    return _appContentRef.doc(docId).snapshots();
  }

  Future<void> saveAppContent({
    required String docId,
    required String title,
    required dynamic content,
  }) async {
    await _appContentRef.doc(docId).set({
      'title': title,
      if (content is String) 'content': content,
      if (content is List) 'items': content,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  final Map<String, Future<void>> _courseMutationLocks = {};

  Future<T> _runSerializedCourseMutation<T>(
    String courseId,
    Future<T> Function() action,
  ) {
    final previousLock = _courseMutationLocks[courseId] ?? Future.value();
    final completer = Completer<T>();

    _courseMutationLocks[courseId] =
        previousLock.catchError((_) {}).then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });

    return completer.future;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _getCourseDoc(
    DocumentReference<Map<String, dynamic>> docRef, {
    bool forceServer = false,
  }) async {
    if (forceServer) {
      try {
        return await docRef.get(const GetOptions(source: Source.server)).timeout(
          const Duration(seconds: 8),
        );
      } catch (_) {
        // Fall back to cache or serverAndCache
      }
    }
    try {
      final cached = await docRef.get(const GetOptions(source: Source.cache));
      if (cached.exists && cached.data() != null) return cached;
    } catch (_) {}
    return docRef.get().timeout(
      const Duration(seconds: 25),
      onTimeout: () => throw TimeoutException('تعذر جلب بيانات الكورس من السيرفر.'),
    );
  }

  // --- عمليات Firestore المؤمنة مع عزل معرفات الدروس المدفوعة ---

  Future<void> saveCourse(Course course) async {
    try {
      final id = course.id.trim().isNotEmpty
          ? course.id.trim()
          : 'c_${DateTime.now().millisecondsSinceEpoch}';
      final batch = db.batch();
      bool hasProtectedLessons = false;

      final sanitizedLevels = course.levels.map((level) {
        final sanitizedLessons = level.lessons.map((lesson) {
          if (!lesson.isFreePreview &&
              lesson.muxPlaybackId.trim().isNotEmpty) {
            hasProtectedLessons = true;
            batch.set(
              _protectedLessonsRef(id).doc(lesson.id),
              {
                'courseId': id,
                'levelId': level.id,
                'lessonId': lesson.id,
                'muxPlaybackId': lesson.muxPlaybackId.trim(),
                'muxAssetId': lesson.muxAssetId,
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
            return lesson.copyWith(muxPlaybackId: '');
          }
          return lesson;
        }).toList();
        return level.copyWith(lessons: sanitizedLessons);
      }).toList();

      final map = course.copyWith(levels: sanitizedLevels).toMap();
      map['id'] = id;

      if (hasProtectedLessons) {
        batch.set(_coursesRef.doc(id), map, SetOptions(merge: true));
        await batch.commit().timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw TimeoutException('استغرق حفظ الكورس وقتاً أطول من المعتاد، يرجى التحقق من اتصال الإنترنت.'),
        );
      } else {
        await _coursesRef.doc(id).set(map, SetOptions(merge: true)).timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw TimeoutException('استغرق حفظ الكورس وقتاً أطول من المعتاد، يرجى التحقق من اتصال الإنترنت.'),
        );
      }
    } catch (e) {
      debugPrint('Firestore saveCourse error: $e');
      rethrow;
    }
  }

  Future<void> deleteCourse(String courseId) async {
    try {
      final protectedDocs = await _protectedLessonsRef(courseId).get();
      final batch = db.batch();
      for (final doc in protectedDocs.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_coursesRef.doc(courseId));
      await batch.commit().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('استغرق حذف الكورس وقتاً أطول من المعتاد.'),
      );
    } catch (e) {
      debugPrint('Firestore deleteCourse error: $e');
      rethrow;
    }
  }

  Future<void> addLevelToCourse(String courseId, CourseLevel level) {
    return _runSerializedCourseMutation(courseId, () async {
      try {
        final docRef = _coursesRef.doc(courseId);
        final doc = await _getCourseDoc(docRef, forceServer: true);
        if (!doc.exists || doc.data() == null) {
          throw StateError('الكورس ($courseId) غير موجود في قاعدة البيانات، يرجى حفظ الكورس أولاً.');
        }
        final data = doc.data()!;
        data['id'] = doc.id;
        final course = Course.fromMap(data);
        final updatedLevels = List<CourseLevel>.from(course.levels)..add(level);
        updatedLevels.sort((a, b) => a.order.compareTo(b.order));
        for (int i = 0; i < updatedLevels.length; i++) {
          updatedLevels[i] = updatedLevels[i].copyWith(order: i + 1);
        }

        await docRef.update({
          'levels': updatedLevels.map((l) => l.toMap()).toList(),
        }).timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw TimeoutException('استغرق إضافة المستوى وقتاً أطول من المعتاد.'),
        );
      } catch (e) {
        debugPrint('Firestore addLevelToCourse error: $e');
        rethrow;
      }
    });
  }

  Future<void> deleteLevelFromCourse(String courseId, String levelId) {
    return _runSerializedCourseMutation(courseId, () async {
      try {
        final docRef = _coursesRef.doc(courseId);
        final doc = await _getCourseDoc(docRef, forceServer: true);
        if (!doc.exists || doc.data() == null) {
          throw StateError('الكورس ($courseId) غير موجود في قاعدة البيانات.');
        }
        final data = doc.data()!;
        data['id'] = doc.id;
        final course = Course.fromMap(data);

        final batch = db.batch();
        for (final lvl in course.levels.where((l) => l.id == levelId)) {
          for (final les in lvl.lessons) {
            batch.delete(_protectedLessonsRef(courseId).doc(les.id));
          }
        }

        final updatedLevels =
            course.levels.where((l) => l.id != levelId).toList();
        for (int i = 0; i < updatedLevels.length; i++) {
          updatedLevels[i] = updatedLevels[i].copyWith(order: i + 1);
        }

        batch.update(docRef, {
          'levels': updatedLevels.map((l) => l.toMap()).toList(),
        });
        await batch.commit().timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw TimeoutException('استغرق حذف المستوى وقتاً أطول من المعتاد.'),
        );
      } catch (e) {
        debugPrint('Firestore deleteLevelFromCourse error: $e');
        rethrow;
      }
    });
  }

  /// إضافة درس لمستوى، ويمكن إرفاق تكليف به في نفس العملية الذرّية:
  /// إما يُحفظ الدرس مع تكليفه معاً أو لا يُحفظ شيء.
  Future<void> addLessonToLevel(
    String courseId,
    String levelId,
    Lesson lesson, {
    Assignment? assignment,
  }) {
    return _runSerializedCourseMutation(courseId, () async {
      try {
        final docRef = _coursesRef.doc(courseId);
        final doc = await _getCourseDoc(docRef, forceServer: true);
        if (!doc.exists || doc.data() == null) {
          throw StateError('الكورس ($courseId) غير موجود في قاعدة البيانات.');
        }
        final data = doc.data()!;
        data['id'] = doc.id;
        final course = Course.fromMap(data);
        final levelIndex = course.levels.indexWhere((l) => l.id == levelId);
        if (levelIndex == -1) {
          throw StateError('المستوى المحدد غير موجود داخل هذا الكورس.');
        }

        final targetLevel = course.levels[levelIndex];
        final nextOrder = targetLevel.lessons.length + 1;

        final assignmentId = assignment == null
            ? ''
            : (assignment.id.trim().isNotEmpty
                ? assignment.id.trim()
                : 'asg_${DateTime.now().millisecondsSinceEpoch}');
        final orderedLesson = lesson.copyWith(
          order: nextOrder,
          assignmentId: assignmentId,
          lockNextUntilSubmitted: assignment?.blocksNextLesson ?? false,
        );

        final batch = db.batch();

        if (assignment != null) {
          final payload = Assignment(
            id: assignmentId,
            courseId: courseId,
            courseTitle: course.title,
            levelId: levelId,
            lessonId: orderedLesson.id,
            title: assignment.title,
            instructions: assignment.instructions,
            maxScore: assignment.maxScore,
            deadline: assignment.deadline,
            createdAt: assignment.createdAt,
            timing: assignment.timing,
            blocksNextLesson: assignment.blocksNextLesson,
            attachmentUrl: assignment.attachmentUrl,
            pdfAttachmentName: assignment.pdfAttachmentName,
          ).toMap();
          batch.set(_assignmentsRef.doc(assignmentId), payload);
        }

        final Lesson publicLesson;
        if (orderedLesson.isFreePreview) {
          publicLesson = orderedLesson;
          batch.delete(
            _protectedLessonsRef(courseId).doc(orderedLesson.id),
          );
        } else {
          batch.set(
            _protectedLessonsRef(courseId).doc(orderedLesson.id),
            {
              'courseId': courseId,
              'levelId': levelId,
              'lessonId': orderedLesson.id,
              'muxPlaybackId': orderedLesson.muxPlaybackId.trim(),
              'muxAssetId': orderedLesson.muxAssetId,
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
          publicLesson = orderedLesson.copyWith(muxPlaybackId: '');
        }

        final updatedLessons = List<Lesson>.from(targetLevel.lessons)
          ..add(publicLesson);
        updatedLessons.sort((a, b) => a.order.compareTo(b.order));

        final updatedLevel = targetLevel.copyWith(lessons: updatedLessons);
        final updatedLevels = List<CourseLevel>.from(course.levels);
        updatedLevels[levelIndex] = updatedLevel;

        batch.update(docRef, {
          'levels': updatedLevels.map((l) => l.toMap()).toList(),
        });

        await batch.commit().timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw TimeoutException('استغرق حفظ الدرس وقتاً أطول من المعتاد.'),
        );
      } catch (e) {
        debugPrint('Firestore addLessonToLevel error: $e');
        rethrow;
      }
    });
  }

  Future<void> updateLessonVideoStatus(
    String courseId,
    String levelId,
    String lessonId, {
    required String videoStatus,
    double? videoProgress,
    String? duration,
    String? videoErrorMessage,
  }) async {
    if (!isAvailable) return;
    return _runSerializedCourseMutation(courseId, () async {
      try {
        final docRef = _coursesRef.doc(courseId);
        final doc = await _getCourseDoc(docRef, forceServer: true);
        if (!doc.exists || doc.data() == null) return;
        final data = doc.data()!;
        data['id'] = doc.id;
        final course = Course.fromMap(data);
        final levelIndex = course.levels.indexWhere((l) => l.id == levelId);
        if (levelIndex != -1) {
          final level = course.levels[levelIndex];
          final lessonIndex =
              level.lessons.indexWhere((les) => les.id == lessonId);
          if (lessonIndex != -1) {
            final existingLesson = level.lessons[lessonIndex];
            // تخطي الكتابة إذا كانت الحالة والمدة متطابقتين لتوفير استهلاك الكوتا
            if (existingLesson.videoStatus == videoStatus &&
                (videoProgress == null || (existingLesson.videoProgress - videoProgress).abs() < 5) &&
                (duration == null || existingLesson.duration == duration)) {
              return;
            }
            final updatedLesson = existingLesson.copyWith(
              videoStatus: videoStatus,
              videoProgress: videoProgress ?? existingLesson.videoProgress,
              duration: duration ?? existingLesson.duration,
              videoErrorMessage: videoErrorMessage,
            );
            final updatedLessons = List<Lesson>.from(level.lessons);
            updatedLessons[lessonIndex] = updatedLesson;
            final updatedLevels = List<CourseLevel>.from(course.levels);
            updatedLevels[levelIndex] = level.copyWith(lessons: updatedLessons);
            await docRef.update({
              'levels': updatedLevels.map((l) => l.toMap()).toList(),
            }).timeout(const Duration(seconds: 15));
          }
        }
      } catch (e) {
        debugPrint('Firestore updateLessonVideoStatus error: $e');
      }
    });
  }

  Future<void> updateLessonPublishStatus(
    String courseId,
    String levelId,
    String lessonId, {
    required bool isPublished,
    DateTime? scheduledPublishAt,
  }) async {
    if (!isAvailable) return;
    return _runSerializedCourseMutation(courseId, () async {
      try {
        final docRef = _coursesRef.doc(courseId);
        final doc = await _getCourseDoc(docRef, forceServer: true);
        if (!doc.exists || doc.data() == null) {
          throw StateError('الكورس ($courseId) غير موجود في قاعدة البيانات.');
        }
        final data = doc.data()!;
        data['id'] = doc.id;
        final course = Course.fromMap(data);
        final levelIndex = course.levels.indexWhere((l) => l.id == levelId);
        if (levelIndex != -1) {
          final level = course.levels[levelIndex];
          final lessonIndex =
              level.lessons.indexWhere((les) => les.id == lessonId);
          if (lessonIndex != -1) {
            final existingLesson = level.lessons[lessonIndex];
            final updatedLesson = existingLesson.copyWith(
              isPublished: isPublished,
              scheduledPublishAt: scheduledPublishAt,
            );
            final updatedLessons = List<Lesson>.from(level.lessons);
            updatedLessons[lessonIndex] = updatedLesson;
            final updatedLevels = List<CourseLevel>.from(course.levels);
            updatedLevels[levelIndex] = level.copyWith(lessons: updatedLessons);
            await docRef.update({
              'levels': updatedLevels.map((l) => l.toMap()).toList(),
            }).timeout(
              const Duration(seconds: 20),
              onTimeout: () => throw TimeoutException('استغرق تحديث حالة النشر وقتاً أطول من المعتاد.'),
            );
          }
        }
      } catch (e) {
        debugPrint('Firestore updateLessonPublishStatus error: $e');
        rethrow;
      }
    });
  }

  Future<void> deleteLessonFromLevel(
    String courseId,
    String levelId,
    String lessonId,
  ) {
    return _runSerializedCourseMutation(courseId, () async {
      try {
        final docRef = _coursesRef.doc(courseId);
        final doc = await _getCourseDoc(docRef, forceServer: true);
        if (!doc.exists || doc.data() == null) {
          throw StateError('الكورس ($courseId) غير موجود في قاعدة البيانات.');
        }

        final data = doc.data()!;
        data['id'] = doc.id;
        final course = Course.fromMap(data);
        final levelIndex = course.levels.indexWhere((l) => l.id == levelId);
        if (levelIndex != -1) {
          final targetLevel = course.levels[levelIndex];
          final batch = db.batch();

          for (final les in targetLevel.lessons.where((l) => l.id == lessonId)) {
            if (les.hasAssignment) {
              batch.delete(_assignmentsRef.doc(les.assignmentId!));
            }
          }
          final updatedLessons = targetLevel.lessons
              .where((les) => les.id != lessonId)
              .toList();
          for (int i = 0; i < updatedLessons.length; i++) {
            updatedLessons[i] = updatedLessons[i].copyWith(order: i + 1);
          }
          final updatedLevel = targetLevel.copyWith(lessons: updatedLessons);

          final updatedLevels = List<CourseLevel>.from(course.levels);
          updatedLevels[levelIndex] = updatedLevel;

          batch.delete(_protectedLessonsRef(courseId).doc(lessonId));
          batch.update(docRef, {
            'levels': updatedLevels.map((l) => l.toMap()).toList(),
          });
          await batch.commit().timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('استغرق حذف الدرس وقتاً أطول من المعتاد.'),
          );
        }
      } catch (e) {
        debugPrint('Firestore deleteLessonFromLevel error: $e');
        rethrow;
      }
    });
  }

  Future<void> approveRequest(
    String requestId,
    String studentId,
    String courseId,
  ) async {
    final batch = db.batch();
    final requestRef = _requestsRef.doc(requestId);
    final studentRef = _usersRef.doc(studentId);
    final courseRef = _coursesRef.doc(courseId);

    batch.update(requestRef, {
      'status': 'approved',
      'reviewedAt': FieldValue.serverTimestamp(),
    });

    batch.set(
      studentRef,
      {
        'enrolledCourseIds': FieldValue.arrayUnion([courseId]),
      },
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

  Future<void> rejectRequest(String requestId, {String adminNotes = ''}) async {
    await _requestsRef.doc(requestId).update({
      'status': 'rejected',
      'adminNotes': adminNotes,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleStudentCourse(
    String studentId,
    String courseId,
    bool grant,
  ) async {
    final batch = db.batch();
    final studentRef = _usersRef.doc(studentId);
    final courseRef = _coursesRef.doc(courseId);

    batch.set(
      studentRef,
      {
        'enrolledCourseIds': grant
            ? FieldValue.arrayUnion([courseId])
            : FieldValue.arrayRemove([courseId]),
      },
      SetOptions(merge: true),
    );

    batch.set(
      courseRef,
      {
        'enrolledCount': FieldValue.increment(grant ? 1 : -1),
        'allowedStudentIds': grant
            ? FieldValue.arrayUnion([studentId])
            : FieldValue.arrayRemove([studentId]),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  /// تغيير طريقة إتاحة الكورس (مفتوح/بموافقة/تعيين فقط/مغلق).
  Future<void> setCourseAccessMode(
    String courseId,
    CourseAccessMode mode,
  ) async {
    await _coursesRef.doc(courseId).set(
      {'accessMode': mode.name},
      SetOptions(merge: true),
    );
  }

  /// تعيين/إلغاء تعيين مجموعة طلاب لكورس دفعة واحدة (Bulk).
  /// - يقرأ حالة كل طالب أولاً ليحدّث `enrolledCount` بالفرق الحقيقي فقط.
  /// - يزامن `allowedStudentIds` في وثيقة الكورس (قاعدة الوصول للتعيين فقط).
  /// - يقسم العمليات على دفعات (حد Firestore = 500 عملية للدفعة).
  /// يعيد عدد الطلاب الذين تغيّرت حالتهم فعلاً.
  Future<int> assignStudentsToCourse({
    required String courseId,
    required List<String> studentIds,
    required bool grant,
  }) async {
    final ids = studentIds.toSet().toList();
    if (ids.isEmpty) return 0;

    var changed = 0;
    const chunkSize = 200;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(
        i,
        i + chunkSize > ids.length ? ids.length : i + chunkSize,
      );
      final snaps = await Future.wait(
        chunk.map((id) => _usersRef.doc(id).get()),
      );

      final batch = db.batch();
      var chunkChanged = 0;
      for (final snap in snaps) {
        if (!snap.exists) continue;
        final enrolled = List<String>.from(
          snap.data()?['enrolledCourseIds'] as List? ?? const [],
        );
        final isEnrolled = enrolled.contains(courseId);
        if (isEnrolled == grant) continue;
        batch.set(
          snap.reference,
          {
            'enrolledCourseIds': grant
                ? FieldValue.arrayUnion([courseId])
                : FieldValue.arrayRemove([courseId]),
          },
          SetOptions(merge: true),
        );
        chunkChanged++;
      }

      batch.set(
        _coursesRef.doc(courseId),
        {
          'allowedStudentIds': grant
              ? FieldValue.arrayUnion(chunk)
              : FieldValue.arrayRemove(chunk),
          if (chunkChanged > 0)
            'enrolledCount': FieldValue.increment(grant ? chunkChanged : -chunkChanged),
        },
        SetOptions(merge: true),
      );
      await batch.commit();
      changed += chunkChanged;
    }
    return changed;
  }

  /// تعليق أو إلغاء تعليق حساب طالب
  Future<void> toggleStudentSuspension(
    String studentId, {
    required bool suspend,
    String? reason,
  }) async {
    await _usersRef.doc(studentId).set(
      {
        'isSuspended': suspend,
        'suspensionReason': reason ?? '',
        'suspendedAt': suspend ? FieldValue.serverTimestamp() : null,
      },
      SetOptions(merge: true),
    );
  }

  /// حذف حساب الطالب نهائياً من النظام
  Future<void> deleteStudentAccount(String studentId) async {
    final batch = db.batch();
    batch.delete(_usersRef.doc(studentId));
    final activeSessions =
        await _activeSessionsRef.where('studentId', isEqualTo: studentId).get();
    for (final doc in activeSessions.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// تمديد صلاحية الكورس لجميع الطلاب المسجلين فيه بعدد محدد من الأيام
  Future<int> extendCourseValidityForAll({
    required String courseId,
    required int additionalDays,
  }) async {
    final query = await _usersRef.where('enrolledCourseIds', arrayContains: courseId).get();
    if (query.docs.isEmpty) return 0;

    final batch = db.batch();
    final now = DateTime.now();
    for (final doc in query.docs) {
      final data = doc.data();
      final expiryMap = Map<String, dynamic>.from(data['courseExpiryDates'] as Map? ?? {});
      DateTime currentExpiry = now;
      if (expiryMap.containsKey(courseId) && expiryMap[courseId] != null) {
        final parsed = DateTime.tryParse(expiryMap[courseId].toString());
        if (parsed != null && parsed.isAfter(now)) {
          currentExpiry = parsed;
        }
      }
      final newExpiry = currentExpiry.add(Duration(days: additionalDays));
      expiryMap[courseId] = newExpiry.toIso8601String();
      batch.update(doc.reference, {'courseExpiryDates': expiryMap});
    }
    await batch.commit();
    return query.docs.length;
  }

  /// تمديد صلاحية اشتراك طالب محدد في كورس
  Future<void> extendStudentCourseValidity({
    required String studentId,
    required String courseId,
    required int additionalDays,
  }) async {
    final doc = await _usersRef.doc(studentId).get();
    if (!doc.exists) return;
    final data = doc.data() ?? {};
    final expiryMap = Map<String, dynamic>.from(data['courseExpiryDates'] as Map? ?? {});
    final now = DateTime.now();
    DateTime currentExpiry = now;
    if (expiryMap.containsKey(courseId) && expiryMap[courseId] != null) {
      final parsed = DateTime.tryParse(expiryMap[courseId].toString());
      if (parsed != null && parsed.isAfter(now)) {
        currentExpiry = parsed;
      }
    }
    final newExpiry = currentExpiry.add(Duration(days: additionalDays));
    expiryMap[courseId] = newExpiry.toIso8601String();
    await _usersRef.doc(studentId).set({'courseExpiryDates': expiryMap}, SetOptions(merge: true));
  }

  /// إلغاء اشتراك جميع الطلاب المسجلين في كورس دفعة واحدة
  Future<int> revokeCourseAccessForAll(String courseId) async {
    final query = await _usersRef.where('enrolledCourseIds', arrayContains: courseId).get();
    if (query.docs.isEmpty) return 0;
    final batch = db.batch();
    for (final doc in query.docs) {
      batch.update(doc.reference, {
        'enrolledCourseIds': FieldValue.arrayRemove([courseId]),
      });
    }
    batch.update(_coursesRef.doc(courseId), {
      'enrolledCount': 0,
      'allowedStudentIds': <String>[],
    });
    await batch.commit();
    return query.docs.length;
  }

  /// تعليق أو تنشيط مجموعة طلاب محددين (Bulk)
  Future<void> bulkSuspendStudents({
    required List<String> studentIds,
    required bool suspend,
    String? reason,
  }) async {
    final batch = db.batch();
    for (final id in studentIds) {
      batch.update(_usersRef.doc(id), {
        'isSuspended': suspend,
        'suspensionReason': suspend ? (reason ?? 'تعليق جماعي من الإدارة') : null,
      });
    }
    await batch.commit();
  }

  /// حذف مجموعة طلاب نهائياً (Bulk)
  Future<void> bulkDeleteStudents(List<String> studentIds) async {
    final batch = db.batch();
    for (final id in studentIds) {
      batch.delete(_usersRef.doc(id));
    }
    await batch.commit();
  }

  // --- Multi-Admin & RBAC Management ---

  Stream<List<AdminModel>> streamAdmins() {
    return _adminsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return AdminModel.fromJson(doc.data(), doc.id);
      }).toList();
    });
  }

  Future<AdminModel?> getAdminByEmail(String email) async {
    final cleanEmail = email.toLowerCase().trim();
    final query = await _adminsRef
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    return AdminModel.fromJson(doc.data(), doc.id);
  }

  Future<AdminModel?> getAdminByUid(String uid) async {
    final doc = await _adminsRef.doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return AdminModel.fromJson(doc.data()!, doc.id);
    }
    // Also try search by 'uid' field
    final query = await _adminsRef.where('uid', isEqualTo: uid).limit(1).get();
    if (query.docs.isNotEmpty) {
      return AdminModel.fromJson(query.docs.first.data(), query.docs.first.id);
    }
    return null;
  }

  Future<void> saveAdmin(AdminModel admin) async {
    final docRef = admin.id.isNotEmpty
        ? _adminsRef.doc(admin.id)
        : (admin.uid.isNotEmpty ? _adminsRef.doc(admin.uid) : _adminsRef.doc());
    await docRef.set(admin.toJson(), SetOptions(merge: true));
  }

  Future<void> updateAdminPermissions(
    String adminId, {
    required AdminRole role,
    required List<String> permissions,
  }) async {
    await _adminsRef.doc(adminId).update({
      'role': role.code,
      'permissions': permissions,
    });
  }

  Future<void> toggleAdminStatus(String adminId, bool isActive) async {
    await _adminsRef.doc(adminId).update({
      'isActive': isActive,
    });
  }

  Future<void> deleteAdmin(String adminId) async {
    await _adminsRef.doc(adminId).delete();
  }

  Future<AdminModel> ensureRootAdminProvisioned({
    required String rootEmail,
    String? rootUid,
  }) async {
    final cleanEmail = rootEmail.toLowerCase().trim();
    final AdminModel? existing = await getAdminByEmail(cleanEmail);
    if (existing == null) {
      final docRef = rootUid != null && rootUid.isNotEmpty
          ? _adminsRef.doc(rootUid)
          : _adminsRef.doc();
      final rootAdmin = AdminModel(
        id: docRef.id,
        uid: rootUid ?? docRef.id,
        email: cleanEmail,
        name: 'الأمين سنتر (المدير العام)',
        role: AdminRole.superAdmin,
        permissions: AdminPermission.all,
        isActive: true,
        createdAt: DateTime.now(),
        createdBy: 'system',
      );
      await docRef.set(rootAdmin.toJson(), SetOptions(merge: true));
      return rootAdmin;
    }
    return existing;
  }
}

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/assignment.dart';
import '../../models/course.dart';
import '../../models/course_access_mode.dart';
import '../../models/course_level.dart';
import '../../models/lesson.dart';
import '../courses_repository.dart';

class CoursesRepositoryImpl implements CoursesRepository {
  final FirebaseFirestore? _explicitFirestore;

  CoursesRepositoryImpl({FirebaseFirestore? firestore})
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

  CollectionReference<Map<String, dynamic>> get _coursesRef =>
      db.collection('courses');

  CollectionReference<Map<String, dynamic>> get _assignmentsRef =>
      db.collection('assignments');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      db.collection('users');

  CollectionReference<Map<String, dynamic>> _protectedLessonsRef(String courseId) =>
      _coursesRef.doc(courseId).collection('protected_lessons');

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

  @override
  Stream<List<Course>> streamCourses() {
    if (!isAvailable) return Stream.value(const <Course>[]);
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
  Future<void> updateLessonVideoStatus(
    String courseId,
    String levelId,
    String lessonId, {
    required String videoStatus,
    double? videoProgress,
    String? duration,
    String? videoErrorMessage,
  }) async {
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

  @override
  Future<void> updateLessonPublishStatus(
    String courseId,
    String levelId,
    String lessonId, {
    required bool isPublished,
    DateTime? scheduledPublishAt,
  }) async {
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

  @override
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

  @override
  Future<void> setCourseAccessMode(
    String courseId,
    CourseAccessMode mode,
  ) async {
    await _coursesRef.doc(courseId).set(
      {'accessMode': mode.name},
      SetOptions(merge: true),
    );
  }

  @override
  Future<int> assignStudents({
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
}

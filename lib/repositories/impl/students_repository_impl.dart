import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/registered_student.dart';
import '../students_repository.dart';

class StudentsRepositoryImpl implements StudentsRepository {
  final FirebaseFirestore? _explicitFirestore;

  StudentsRepositoryImpl({FirebaseFirestore? firestore})
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

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      db.collection('users');

  CollectionReference<Map<String, dynamic>> get _coursesRef =>
      db.collection('courses');

  CollectionReference<Map<String, dynamic>> get _activeSessionsRef =>
      db.collection('active_watch_sessions');

  @override
  Stream<List<RegisteredStudent>> streamStudents() {
    if (!isAvailable) return Stream.value(const <RegisteredStudent>[]);
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

  @override
  Future<List<RegisteredStudent>> getStudents({bool forceRefresh = false}) async {
    try {
      final source = forceRefresh ? Source.server : Source.serverAndCache;
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
      final snapshot = await _usersRef.get(const GetOptions(source: Source.cache));
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
    }
  }

  @override
  Future<int> getStudentsCount() async {
    try {
      final aggregate = await _usersRef.count().get();
      return aggregate.count ?? 0;
    } catch (_) {
      final snapshot = await _usersRef.get(const GetOptions(source: Source.cache));
      return snapshot.docs.length;
    }
  }

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
  Future<void> bulkDeleteStudents(List<String> studentIds) async {
    final batch = db.batch();
    for (final id in studentIds) {
      batch.delete(_usersRef.doc(id));
    }
    await batch.commit();
  }
}

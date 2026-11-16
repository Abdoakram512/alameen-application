import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/user_profile.dart';
import '../student_profile_repository.dart';

class StudentProfileRepositoryImpl implements StudentProfileRepository {
  final FirebaseFirestore? _explicitFirestore;

  StudentProfileRepositoryImpl({FirebaseFirestore? firestore})
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

  CollectionReference<Map<String, dynamic>> get _requestsRef =>
      db.collection('access_requests');

  CollectionReference<Map<String, dynamic>> get _activeSessionsRef =>
      db.collection('active_watch_sessions');

  @override
  Stream<UserModel?> streamUser(String uid) {
    if (!isAvailable) return Stream.value(null);
    return _usersRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromMap(doc.data()!, uid: doc.id);
    });
  }

  @override
  Future<UserModel> syncUserProfile(UserModel user) async {
    if (!isAvailable) return user;
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

  @override
  Future<void> updateStudentProfile({
    required String uid,
    required String displayName,
    required String phone,
  }) async {
    if (!isAvailable) return;
    await _usersRef.doc(uid).set(
      {
        'displayName': displayName.trim(),
        'phone': phone.trim(),
        'lastActiveAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> updateStudentPhoto({
    required String uid,
    required String photoUrl,
  }) async {
    if (!isAvailable) return;
    await _usersRef.doc(uid).set(
      {
        'photoUrl': photoUrl.trim(),
        'lastActiveAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> deleteStudentAccount(String uid) async {
    if (!isAvailable) return;
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
}

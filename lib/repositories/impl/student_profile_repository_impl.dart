import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../core/di/injection_container.dart';
import '../../datasources/auth_remote_data_source.dart';
import '../../models/user_profile.dart';
import '../student_profile_repository.dart';

class StudentProfileRepositoryImpl implements StudentProfileRepository {
  final AuthRemoteDataSource? _explicitAuthRemoteDataSource;
  final FirebaseFirestore? _explicitFirestore;

  StudentProfileRepositoryImpl({
    AuthRemoteDataSource? authRemoteDataSource,
    FirebaseFirestore? firestore,
  })  : _explicitAuthRemoteDataSource = authRemoteDataSource,
        _explicitFirestore = firestore;

  AuthRemoteDataSource? get _remote {
    if (_explicitAuthRemoteDataSource != null) return _explicitAuthRemoteDataSource;
    if (sl.isRegistered<AuthRemoteDataSource>()) {
      return sl<AuthRemoteDataSource>();
    }
    return null;
  }

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

  @override
  Stream<UserModel?> streamUser(String uid) {
    if (!isAvailable) return Stream.value(null);
    return _usersRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromMap(doc.data()!, uid: doc.id);
    });
  }

  @override
  Future<UserModel?> getProfile() async {
    final remote = _remote;
    if (remote != null) {
      try {
        return await remote.getProfile();
      } catch (e) {
        debugPrint('getProfile error: $e');
      }
    }
    return null;
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
    }

    if (needsWrite) {
      try {
        await docRef.set(payload, SetOptions(merge: true));
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
    String? email,
    String? bio,
    String? locale,
    String? avatarFilePath,
  }) async {
    final remote = _remote;
    if (remote != null) {
      await remote.updateProfile(
        name: displayName,
        phone: phone,
        email: email,
        bio: bio,
        locale: locale,
        avatarFilePath: avatarFilePath,
      );
      return;
    }
  }

  @override
  Future<void> updateStudentPhoto({
    required String uid,
    required String photoUrl,
  }) async {
    final remote = _remote;
    if (remote != null) {
      // Photo update is part of multipart updateProfile in Laravel REST API
      await remote.updateProfile(
        name: '',
        phone: '',
      );
      return;
    }
  }

  @override
  Future<void> deleteStudentAccount(
    String uid, {
    String? currentPassword,
  }) async {
    final remote = _remote;
    if (remote != null && currentPassword != null && currentPassword.isNotEmpty) {
      await remote.deleteAccount(currentPassword: currentPassword);
      return;
    }
  }
}

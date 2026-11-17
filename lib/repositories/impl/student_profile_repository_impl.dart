import 'package:flutter/foundation.dart';
import '../../core/di/injection_container.dart';
import '../../datasources/auth_remote_data_source.dart';
import '../../models/user_profile.dart';
import '../student_profile_repository.dart';

class StudentProfileRepositoryImpl implements StudentProfileRepository {
  final AuthRemoteDataSource? _explicitAuthRemoteDataSource;

  StudentProfileRepositoryImpl({
    AuthRemoteDataSource? authRemoteDataSource,
    dynamic firestore,
  }) : _explicitAuthRemoteDataSource = authRemoteDataSource;

  AuthRemoteDataSource? get _remote {
    if (_explicitAuthRemoteDataSource != null) return _explicitAuthRemoteDataSource;
    if (sl.isRegistered<AuthRemoteDataSource>()) {
      return sl<AuthRemoteDataSource>();
    }
    return null;
  }

  @override
  Stream<UserModel?> streamUser(String uid) {
    return const Stream.empty();
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

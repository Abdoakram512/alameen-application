import '../models/user_profile.dart';

abstract class StudentProfileRepository {
  /// Stream user profile for real-time state changes
  Stream<UserModel?> streamUser(String uid);

  /// Fetch user profile from REST API (GET /student/settings/profile)
  Future<UserModel?> getProfile();

  /// Synchronize profile locally or with backend
  Future<UserModel> syncUserProfile(UserModel user);

  /// Update student profile (POST /student/settings/profile)
  Future<void> updateStudentProfile({
    required String uid,
    required String displayName,
    required String phone,
    String? email,
    String? bio,
    String? locale,
    String? avatarFilePath,
  });

  /// Update student photo URL
  Future<void> updateStudentPhoto({
    required String uid,
    required String photoUrl,
  });

  /// Delete student account (DELETE /student/settings/profile)
  Future<void> deleteStudentAccount(
    String uid, {
    String? currentPassword,
  });
}

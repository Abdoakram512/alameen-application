import '../models/user_profile.dart';

abstract class StudentProfileRepository {
  /// Fetch user profile from REST API (GET /student/settings/profile)
  Future<UserModel?> getProfile();

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

  /// Delete student account (DELETE /student/settings/profile)
  Future<void> deleteStudentAccount(
    String uid, {
    String? currentPassword,
  });
}

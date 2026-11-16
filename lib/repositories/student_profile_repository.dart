import '../models/user_profile.dart';

abstract class StudentProfileRepository {
  Stream<UserModel?> streamUser(String uid);
  Future<UserModel> syncUserProfile(UserModel user);
  Future<void> updateStudentProfile({
    required String uid,
    required String displayName,
    required String phone,
  });
  Future<void> updateStudentPhoto({
    required String uid,
    required String photoUrl,
  });
  Future<void> deleteStudentAccount(String uid);
}

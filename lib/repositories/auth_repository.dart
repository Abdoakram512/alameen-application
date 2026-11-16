import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  User? get currentFirebaseUser;
  Future<bool> isAuthorizedAdmin(String? email);
  Future<AdminUser?> getAdminProfile(User user);
  Future<AdminUser> signInWithEmailPassword({
    required String email,
    required String password,
  });
  Future<void> signOut();
}


import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AdminAuthService _authService;

  AuthRepositoryImpl({AdminAuthService? authService})
      : _authService = authService ?? AdminAuthService();

  @override
  Stream<User?> get authStateChanges => _authService.authStateChanges;

  @override
  User? get currentFirebaseUser => _authService.currentFirebaseUser;

  @override
  Future<bool> isAuthorizedAdmin(String? email) => _authService.isAuthorizedAdmin(email);

  @override
  Future<AdminUser?> getAdminProfile(User user) => _authService.getAdminProfile(user);

  @override
  Future<AdminUser> signInWithEmailPassword({
    required String email,
    required String password,
  }) {
    return _authService.signInWithEmailPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() => _authService.signOut();
}


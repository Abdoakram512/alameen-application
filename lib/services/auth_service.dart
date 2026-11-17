import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/config/app_config.dart';
import 'notification_service.dart';

/// Legacy Firebase Authentication service retained strictly for transition bridge
/// and FCM/Google session teardown. All primary authentication is handled by
/// [StudentAuthRepository].
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: AppConfig.googleServerClientId,
  );

  User? get currentFirebaseUser => _auth?.currentUser;

  /// Retrieve Firebase ID Token for Laravel transition bridge (POST /auth/firebase)
  Future<String?> getFirebaseIdToken() async {
    try {
      return await _auth?.currentUser?.getIdToken();
    } catch (_) {
      return null;
    }
  }

  /// Delete current user from Firebase Auth
  Future<void> deleteCurrentUser({String? password}) async {
    final user = _auth?.currentUser;
    if (user != null) {
      if (password != null && password.trim().isNotEmpty && user.email != null) {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password.trim(),
        );
        await user.reauthenticateWithCredential(credential);
      }
      try {
        final uid = user.uid;
        await NotificationService().clearFCMToken(uid).timeout(const Duration(seconds: 4));
      } catch (_) {}
      try {
        await _googleSignIn.signOut().timeout(const Duration(seconds: 4));
      } catch (_) {}
      await user.delete().timeout(const Duration(seconds: 10));
    }
  }

  /// Sign out from Firebase and Google Sign-In
  Future<void> signOut() async {
    try {
      final uid = _auth?.currentUser?.uid;
      if (uid != null) {
        await NotificationService().clearFCMToken(uid).timeout(const Duration(seconds: 4));
      }
    } catch (_) {}
    try {
      await _googleSignIn.signOut().timeout(const Duration(seconds: 4));
    } catch (_) {}
    try {
      await _auth?.signOut().timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
}

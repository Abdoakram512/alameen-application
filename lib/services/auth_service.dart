import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/config/app_config.dart';
import '../models/user_profile.dart';
import 'notification_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: AppConfig.googleServerClientId,
  );

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentFirebaseUser => _auth.currentUser;

  /// تسجيل الدخول الحقيقي بـ Google مع ربطه بـ Firebase Auth
  Future<UserModel?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // ألغى المستخدم العملية
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        return UserModel(
          uid: user.uid,
          displayName: user.displayName ?? googleUser.displayName ?? 'طالب الأمين سنتر',
          email: user.email ?? googleUser.email,
          photoUrl: user.photoURL ?? googleUser.photoUrl ?? '',
          createdAt: DateTime.now(),
        );
      }
      return null;
    } catch (e) {
      debugPrint('Google Sign-In direct error: $e');
      rethrow;
    }
  }

  /// تسجيل الدخول بالبريد الإلكتروني وكلمة المرور
  Future<UserModel?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        return UserModel(
          uid: user.uid,
          displayName: user.displayName ?? 'طالب الأمين سنتر',
          email: user.email ?? email.trim(),
          photoUrl: user.photoURL ?? '',
          createdAt: DateTime.now(),
        );
      }
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('Email Sign-In error: ${e.code} - ${e.message}');
      throw getReadableAuthError(e);
    } catch (e) {
      debugPrint('Email Sign-In general error: $e');
      rethrow;
    }
  }

  /// إنشاء حساب طالب جديد بالبريد الإلكتروني وكلمة المرور
  Future<UserModel?> signUpWithEmailAndPassword({
    required String name,
    required String email,
    required String password,
    String phone = '',
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(name.trim());
        return UserModel(
          uid: user.uid,
          displayName: name.trim(),
          email: email.trim(),
          photoUrl: '',
          phone: phone.trim(),
          createdAt: DateTime.now(),
        );
      }
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('Email Sign-Up error: ${e.code} - ${e.message}');
      throw getReadableAuthError(e);
    } catch (e) {
      debugPrint('Email Sign-Up general error: $e');
      rethrow;
    }
  }

  /// إرسال رابط استعادة كلمة المرور
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw getReadableAuthError(e);
    } catch (e) {
      rethrow;
    }
  }

  /// ترجمة أخطاء Firebase إلى رسائل عربية واضحة ومباشرة للمستخدم
  String getReadableAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'لا يوجد حساب مسجل بهذا البريد الإلكتروني. يرجى إنشاء حساب جديد.';
        case 'wrong-password':
          return 'كلمة المرور غير صحيحة، يرجى المحاولة مجدداً.';
        case 'invalid-credential':
          return 'بيانات تسجيل الدخول غير صحيحة، يرجى التأكد من البريد وكلمة المرور.';
        case 'email-already-in-use':
          return 'هذا البريد مسجل مسبقاً لدى الأمين سنتر، يمكنك تسجيل الدخول به مباشرة.';
        case 'invalid-email':
          return 'صيغة البريد الإلكتروني غير صالحة، يرجى كتابة بريد صالح.';
        case 'weak-password':
          return 'كلمة المرور ضعيفة جداً، يرجى كتابة 6 أحرف أو أرقام على الأقل.';
        case 'user-disabled':
          return 'تم تعطيل هذا الحساب. يرجى التواصل مع إدارة الأمين سنتر.';
        case 'network-request-failed':
          return 'تعذر الاتصال بالشبكة، يرجى التحقق من اتصال هاتفك بالإنترنت.';
        case 'too-many-requests':
          return 'تم حظر المحاولات مؤقتاً لأسباب أمنية، يرجى الانتظار بضع دقائق ثم المحاولة.';
        default:
          return error.message ?? 'حدث خطأ في عملية المصادقة، يرجى المحاولة لاحقاً.';
      }
    }
    final errStr = error.toString();
    if (errStr.contains('10') || errStr.contains('sign_in_failed')) {
      return 'تعذر التوثيق عبر Google، يرجى المحاولة مجدداً أو الدخول بالبريد وكلمة المرور.';
    }
    return error.toString();
  }

  /// تسجيل الخروج وتنظيف بيانات إشعارات الجلسة
  Future<void> signOut() async {
    try {
      final uid = _auth.currentUser?.uid;
      await NotificationService().clearFCMToken(uid);
    } catch (_) {}
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }
}

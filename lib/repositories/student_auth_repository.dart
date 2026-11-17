import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/config/app_config.dart';
import '../core/network/api_exceptions.dart';
import '../core/storage/secure_token_storage.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/user_profile.dart';

/// Abstract contract for authentication business operations.
abstract class StudentAuthRepository {
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? phone,
    String? country,
    String? city,
    String? address,
  });

  Future<AuthResult> login({
    required String email,
    required String password,
    bool remember = true,
  });

  Future<AuthResult> loginWithGoogle();

  Future<UserModel?> restoreSession();

  Future<void> logout({bool allDevices = false});

  Future<String> forgotPassword(String email);

  Future<bool> verifyOtp(String email, String otp);

  Future<String> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  });

  Future<AuthResult?> tryFirebaseMigrationBridge();
}

/// Concrete implementation of [StudentAuthRepository] integrating Laravel REST API,
/// [SecureTokenStorage], Google Sign-In, and legacy Firebase account bridge.
class StudentAuthRepositoryImpl implements StudentAuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final SecureTokenStorage _tokenStorage;
  final GoogleSignIn _googleSignIn;
  final fb.FirebaseAuth? _firebaseAuth;

  StudentAuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required SecureTokenStorage tokenStorage,
    GoogleSignIn? googleSignIn,
    fb.FirebaseAuth? firebaseAuth,
  })  : _remoteDataSource = remoteDataSource,
        _tokenStorage = tokenStorage,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              serverClientId: AppConfig.googleServerClientId,
            ),
        _firebaseAuth = firebaseAuth ?? _resolveFirebaseAuth();

  static fb.FirebaseAuth? _resolveFirebaseAuth() {
    try {
      return fb.FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? phone,
    String? country,
    String? city,
    String? address,
  }) async {
    final result = await _remoteDataSource.register(
      name: name,
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
      phone: phone,
      country: country,
      city: city,
      address: address,
    );

    // Registration creates account in pending status; no Sanctum token is issued yet
    return result;
  }

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
    bool remember = true,
  }) async {
    final result = await _remoteDataSource.login(
      email: email,
      password: password,
      remember: remember,
    );

    if (result.isAuthenticated && result.token != null) {
      await _tokenStorage.saveToken(result.token!);
      if (result.user != null) {
        await _tokenStorage.saveUserData(result.user!.toMap());
      }
    }

    return result;
  }

  @override
  Future<AuthResult> loginWithGoogle() async {
    try {
      final GoogleSignInAccount? googleAccount = await _googleSignIn.signIn();
      if (googleAccount == null) {
        return const AuthResult(
          status: 'cancelled',
          message: 'تم إلغاء عملية تسجيل الدخول باستخدام Google.',
        );
      }

      final GoogleSignInAuthentication googleAuth = await googleAccount.authentication;
      final String? accessToken = googleAuth.accessToken;

      if (accessToken == null || accessToken.trim().isEmpty) {
        throw const ApiException(
          'تعذر الحصول على رمز الوصول (OAuth Access Token) من Google.',
        );
      }

      final result = await _remoteDataSource.loginWithGoogleToken(
        accessToken: accessToken,
      );

      if (result.isAuthenticated && result.token != null) {
        await _tokenStorage.saveToken(result.token!);
        if (result.user != null) {
          await _tokenStorage.saveUserData(result.user!.toMap());
        }
      }

      return result;
    } catch (e) {
      debugPrint('Google Sign-In repository error: $e');
      if (e is ApiException) rethrow;
      throw ApiException(
        'حدث خطأ أثناء الاتصال بخدمة Google: ${e.toString()}',
      );
    }
  }

  @override
  Future<UserModel?> restoreSession() async {
    final hasToken = await _tokenStorage.hasToken();

    if (!hasToken) {
      // Check if a legacy Firebase user session exists that can be bridged to Laravel Sanctum
      final bridgeResult = await tryFirebaseMigrationBridge();
      if (bridgeResult != null && bridgeResult.isAuthenticated && bridgeResult.user != null) {
        return bridgeResult.user;
      }
      return null;
    }

    try {
      final user = await _remoteDataSource.getMe();
      await _tokenStorage.saveUserData(user.toMap());
      return user;
    } on UnauthorizedException {
      // Token is invalid or revoked on server — clear local session
      await _tokenStorage.clearAll();
      return null;
    } on NetworkTimeoutException {
      // Offline startup: Do NOT revoke token! Fall back to hardware cached user profile
      final cachedData = await _tokenStorage.getUserData();
      if (cachedData != null) {
        return UserModel.fromMap(cachedData);
      }
      return null;
    } catch (e) {
      debugPrint('restoreSession error: $e');
      final cachedData = await _tokenStorage.getUserData();
      if (cachedData != null) {
        return UserModel.fromMap(cachedData);
      }
      return null;
    }
  }

  @override
  Future<void> logout({bool allDevices = false}) async {
    try {
      await _remoteDataSource.logout(allDevices: allDevices);
    } catch (_) {}

    await _tokenStorage.clearAll();

    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    try {
      await _firebaseAuth?.signOut();
    } catch (_) {}
  }

  @override
  Future<String> forgotPassword(String email) async {
    return await _remoteDataSource.forgotPassword(email: email);
  }

  @override
  Future<bool> verifyOtp(String email, String otp) async {
    return await _remoteDataSource.verifyOtp(email: email, otp: otp);
  }

  @override
  Future<String> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    return await _remoteDataSource.resetPassword(
      email: email,
      otp: otp,
      password: password,
      passwordConfirmation: passwordConfirmation,
    );
  }

  @override
  Future<AuthResult?> tryFirebaseMigrationBridge() async {
    try {
      final fbUser = _firebaseAuth?.currentUser;
      if (fbUser == null) return null;

      final idToken = await fbUser.getIdToken();
      if (idToken == null || idToken.isEmpty) return null;

      final result = await _remoteDataSource.loginWithFirebaseIdToken(idToken: idToken);
      if (result.isAuthenticated && result.token != null) {
        await _tokenStorage.saveToken(result.token!);
        if (result.user != null) {
          await _tokenStorage.saveUserData(result.user!.toMap());
        }
        return result;
      }
    } catch (e) {
      debugPrint('Firebase transition bridge check: $e');
    }
    return null;
  }
}

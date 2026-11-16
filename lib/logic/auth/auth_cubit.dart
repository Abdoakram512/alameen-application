import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthService _authService;
  final FirestoreService _firestoreService;
  StreamSubscription? _userSubscription;
  StreamSubscription? _authSubscription;

  AuthCubit({AuthService? authService, FirestoreService? firestoreService})
      : _authService = authService ?? AuthService(),
        _firestoreService = firestoreService ?? FirestoreService(),
        super(AuthInitial()) {
    _listenToAuth();
  }

  void _listenToAuth() {
    _authSubscription = _authService.authStateChanges.listen((firebaseUser) {
      if (firebaseUser != null) {
        _userSubscription?.cancel();
        _userSubscription = _firestoreService.streamUser(firebaseUser.uid).listen((userModel) {
          if (userModel != null) {
            emit(Authenticated(userModel));
          } else {
            final fallbackUser = UserModel(
              uid: firebaseUser.uid,
              displayName: firebaseUser.displayName ?? 'طالب الأمين سنتر',
              email: firebaseUser.email ?? '',
              photoUrl: firebaseUser.photoURL ?? '',
              phone: firebaseUser.phoneNumber ?? '',
              createdAt: DateTime.now(),
            );
            unawaited(_ensureUserProfileSynced(fallbackUser));
            emit(Authenticated(fallbackUser));
          }
        });
      } else {
        _userSubscription?.cancel();
        _userSubscription = null;
        if (state is! Unauthenticated) {
          emit(Unauthenticated());
        }
      }
    });
  }

  Future<void> _ensureUserProfileSynced(UserModel user) async {
    try {
      final synced = await _firestoreService.syncUserProfile(user).timeout(const Duration(seconds: 8));
      if (!isClosed && state is Authenticated) {
        emit(Authenticated(synced));
      }
    } catch (e) {
      debugPrint('ensureUserProfileSynced warning: $e');
    }
  }

  /// تسجيل الدخول بالبريد الإلكتروني وكلمة المرور فورياً دون حجز الواجهة
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    emit(AuthLoading());
    try {
      final user = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (user != null) {
        // انتقال فوري متفائل للشاشة الرئيسية فور نجاح المصادقة
        emit(Authenticated(user));
        // مزامنة وتأكيد وثيقة الطالب في Firestore
        unawaited(_ensureUserProfileSynced(user));
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError(_authService.getReadableAuthError(e)));
    }
  }

  /// إنشاء حساب طالب جديد فورياً
  Future<void> signUpWithEmailAndPassword({
    required String name,
    required String email,
    required String password,
    String phone = '',
  }) async {
    emit(AuthLoading());
    try {
      final user = await _authService.signUpWithEmailAndPassword(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );
      if (user != null) {
        emit(Authenticated(user));
        unawaited(_ensureUserProfileSynced(user));
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError(_authService.getReadableAuthError(e)));
    }
  }

  /// إرسال رابط استعادة كلمة المرور
  Future<void> sendPasswordReset(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
    } catch (e) {
      throw _authService.getReadableAuthError(e);
    }
  }

  /// تحديث بيانات الملف الشخصي للمتدرب (الاسم ورقم الهاتف)
  Future<void> updateProfileInfo({
    required String displayName,
    required String phone,
  }) async {
    final current = state;
    if (current is! Authenticated) return;
    final trimmedName = displayName.trim();
    final trimmedPhone = phone.trim();
    await _firestoreService.updateStudentProfile(
      uid: current.user.uid,
      displayName: trimmedName,
      phone: trimmedPhone,
    );
    emit(
      Authenticated(
        current.user.copyWith(
          displayName: trimmedName,
          phone: trimmedPhone,
        ),
      ),
    );
  }

  /// تحديث الصورة الشخصية للطالب
  Future<void> updateProfilePhoto(String photoUrl) async {
    final current = state;
    if (current is! Authenticated) return;
    final trimmedUrl = photoUrl.trim();
    await _firestoreService.updateStudentPhoto(
      uid: current.user.uid,
      photoUrl: trimmedUrl,
    );
    try {
      await _authService.currentFirebaseUser?.updatePhotoURL(trimmedUrl);
    } catch (_) {}
    emit(
      Authenticated(
        current.user.copyWith(photoUrl: trimmedUrl),
      ),
    );
  }

  /// حذف حساب الطالب نهائياً من المنصة مع حماية كاملة من التعليق وإعادة المصادقة
  Future<void> deleteAccount({String? password}) async {
    final current = state;
    if (current is! Authenticated) return;
    final userModel = current.user;
    final uid = userModel.uid;
    emit(AuthLoading());
    try {
      _userSubscription?.cancel();
      _userSubscription = null;

      // 1. حذف مستخدم Firebase Auth أولاً مع التحقق من كلمة المرور لتأكيد الحذف النهائي الحقيقي
      await _authService.deleteCurrentUser(password: password).timeout(
            const Duration(seconds: 12),
          );

      // 2. مسح بيانات الطالب من Firestore نهائياً
      try {
        await _firestoreService.deleteStudentAccount(uid).timeout(
              const Duration(seconds: 8),
            );
      } catch (e) {
        debugPrint('deleteStudentAccount non-fatal: $e');
      }

      // 3. مسح الجلسة المحلية بالكامل وتأكيد تسجيل الخروج
      await _authService.signOut().catchError((_) {});
      emit(Unauthenticated());
    } catch (e) {
      debugPrint('deleteAccount error: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('wrong-password') || errStr.contains('invalid-credential')) {
        emit(Authenticated(userModel));
        emit(
          AuthError(
            'كلمة المرور غير صحيحة، يرجى كتابتها بدقة لتأكيد حذف الحساب نهائياً.',
          ),
        );
        return;
      }
      if (errStr.contains('requires-recent-login')) {
        await _authService.signOut().catchError((_) {});
        emit(Unauthenticated());
        emit(
          AuthError(
            'لدواعي الأمان، انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً ثم محاولة الحذف.',
          ),
        );
        return;
      }
      emit(Authenticated(userModel));
      emit(AuthError(_authService.getReadableAuthError(e)));
    }
  }

  /// تسجيل الدخول بحساب Google
  Future<void> signInWithGoogle() async {
    emit(AuthLoading());
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        emit(Authenticated(user));
        unawaited(_ensureUserProfileSynced(user));
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError(_authService.getReadableAuthError(e)));
    }
  }

  /// تسجيل الخروج الفوري دون حجز الواجهة
  Future<void> signOut() async {
    _userSubscription?.cancel();
    _userSubscription = null;
    emit(Unauthenticated());
    try {
      await _authService.signOut().timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    _userSubscription?.cancel();
    return super.close();
  }
}

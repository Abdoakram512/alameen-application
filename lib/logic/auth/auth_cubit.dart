import 'dart:async';
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
            _firestoreService.syncUserProfile(fallbackUser);
            emit(Authenticated(fallbackUser));
          }
        });
      } else {
        _userSubscription?.cancel();
        emit(Unauthenticated());
      }
    });
  }

  /// تسجيل الدخول بالبريد الإلكتروني وكلمة المرور
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
        final syncedUser = await _firestoreService.syncUserProfile(user);
        emit(Authenticated(syncedUser));
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError(_authService.getReadableAuthError(e)));
    }
  }

  /// إنشاء حساب طالب جديد
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
        final syncedUser = await _firestoreService.syncUserProfile(user);
        emit(Authenticated(syncedUser));
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

  /// تسجيل الدخول بحساب Google
  Future<void> signInWithGoogle() async {
    emit(AuthLoading());
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        final syncedUser = await _firestoreService.syncUserProfile(user);
        emit(Authenticated(syncedUser));
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError(_authService.getReadableAuthError(e)));
    }
  }

  /// تسجيل الخروج
  Future<void> signOut() async {
    emit(AuthLoading());
    await _authService.signOut();
    emit(Unauthenticated());
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    _userSubscription?.cancel();
    return super.close();
  }
}

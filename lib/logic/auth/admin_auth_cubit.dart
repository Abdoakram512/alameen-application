import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/impl/auth_repository_impl.dart';
import 'admin_auth_state.dart';

class AdminAuthCubit extends Cubit<AdminAuthState> {
  final AuthRepository _authRepository;
  StreamSubscription? _authSubscription;

  AdminAuthCubit({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepositoryImpl(),
        super(AdminAuthInitial()) {
    _listenToAuth();
  }

  void _listenToAuth() {
    _authSubscription = _authRepository.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser != null) {
        // Prevent duplicate network calls if already authenticated as the same user
        if (state is AdminAuthenticated && (state as AdminAuthenticated).user.uid == firebaseUser.uid) {
          return;
        }
        try {
          final adminUser = await _authRepository.getAdminProfile(firebaseUser);
          if (adminUser != null) {
            emit(AdminAuthenticated(adminUser));
          } else {
            // في حال تسجيل دخول أي حساب غير مصرح به يتم طرده فوراً
            await _authRepository.signOut();
            emit(const AdminAuthError('هذا الحساب غير مصرح له بالدخول للوحة تحكم الإدارة.'));
            emit(AdminUnauthenticated());
          }
        } catch (e) {
          emit(AdminUnauthenticated());
        }
      } else {
        if (state is! AdminUnauthenticated) {
          emit(AdminUnauthenticated());
        }
      }
    });
  }

  /// تسجيل الدخول بالبريد وكلمة المرور
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    emit(AdminAuthLoading());
    try {
      final adminUser = await _authRepository.signInWithEmailPassword(
        email: email,
        password: password,
      );
      emit(AdminAuthenticated(adminUser));
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'unauthorized-admin':
          errorMessage = e.message ?? 'هذا الحساب غير مصرح له بالدخول للوحة التحكم.';
          break;
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          errorMessage = 'بيانات الدخول غير صحيحة. يرجى التأكد من البريد وكلمة المرور.';
          break;
        case 'invalid-email':
          errorMessage = 'صيغة البريد الإلكتروني غير صالحة.';
          break;
        case 'user-disabled':
          errorMessage = 'تم تعطيل هذا الحساب من قبل النظام.';
          break;
        case 'too-many-requests':
          errorMessage = 'تم قفل المحاولات مؤقتاً بسبب كثرة المحاولات الخاطئة. حاول لاحقاً.';
          break;
        case 'network-request-failed':
          errorMessage = 'تعذر الاتصال بالسيرفر. يرجى التحقق من اتصال الإنترنت.';
          break;
        default:
          errorMessage = e.message ?? 'فشل تسجيل الدخول. يرجى المحاولة مرة أخرى.';
      }
      emit(AdminAuthError(errorMessage));
    } catch (e) {
      emit(AdminAuthError('حدث خطأ غير متوقع: $e'));
    }
  }

  /// تسجيل الخروج
  Future<void> signOut() async {
    emit(AdminAuthLoading());
    await _authRepository.signOut();
    emit(AdminUnauthenticated());
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}

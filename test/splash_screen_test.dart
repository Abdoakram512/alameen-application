import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:secure_admin_app/core/constants/app_constants.dart';
import 'package:secure_admin_app/core/routing/app_routes.dart';
import 'package:secure_admin_app/core/widgets/app_lottie_box.dart';
import 'package:secure_admin_app/logic/auth/admin_auth_cubit.dart';
import 'package:secure_admin_app/repositories/auth_repository.dart';
import 'package:secure_admin_app/screens/splash/splash_screen.dart';
import 'package:secure_admin_app/services/auth_service.dart';

class MockAuthRepo implements AuthRepository {
  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  User? get currentFirebaseUser => null;

  @override
  Future<bool> isAuthorizedAdmin(String? email) async => true;

  @override
  Future<AdminUser?> getAdminProfile(User user) async => null;

  @override
  Future<AdminUser> signInWithEmailPassword({required String email, required String password}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('SplashScreen displays brand assets and titles correctly', (tester) async {
    final mockRepo = MockAuthRepo();
    final authCubit = AdminAuthCubit(authRepository: mockRepo);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AdminAuthCubit>.value(
          value: authCubit,
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: SplashScreen(),
          ),
        ),
      ),
    );

    // Initial render
    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.text(AppConstants.appNameAr), findsOneWidget);
    expect(find.byType(AppLottieBox), findsOneWidget);

    // Pump frames for animation
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 1000));

    await authCubit.close();
  });

  test('AppRoutes contains splash route constant', () {
    expect(AppRoutes.splash, equals('/splash'));
  });
}

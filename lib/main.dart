import 'dart:async';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:screen_protector/screen_protector.dart';

import 'logic/access/access_cubit.dart';
import 'logic/auth/auth_cubit.dart';
import 'logic/auth/auth_state.dart';
import 'logic/courses/courses_cubit.dart';
import 'navigation/app_router.dart';
import 'screens/security/security_protection_watcher.dart';
import 'core/di/injection_container.dart';
import 'services/notification_service.dart';
import 'services/watch_queue.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: AppConfig.supportedLocales,
      path: AppConfig.translationsPath,
      fallbackLocale: AppConfig.fallbackLocale,
      saveLocale: true,
      useOnlyLangCode: true,
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: SplashScreen(),
        ),
      ),
    ),
  );

  await Future.wait<void>([
    _initFirebase(),
    initDependencies(),
  ]);

  unawaited(_enableScreenProtection());
  unawaited(sl<NotificationService>().initialize());

  runApp(
    EasyLocalization(
      supportedLocales: AppConfig.supportedLocales,
      path: AppConfig.translationsPath,
      fallbackLocale: AppConfig.fallbackLocale,
      saveLocale: true,
      useOnlyLangCode: true,
      child: const SecureStudentApp(),
    ),
  );
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init check: $e');
  }
}

Future<void> _enableScreenProtection() async {
  try {
    await ScreenProtector.preventScreenshotOn();
    await ScreenProtector.protectDataLeakageWithColor(AppConfig.securityShieldColor);
  } catch (e) {
    debugPrint('ScreenProtector init: $e');
  }
}

class SecureStudentApp extends StatefulWidget {
  const SecureStudentApp({super.key});

  @override
  State<SecureStudentApp> createState() => _SecureStudentAppState();
}

class _SecureStudentAppState extends State<SecureStudentApp> {
  late final AuthCubit _authCubit;
  late final CoursesCubit _coursesCubit;
  late final AccessCubit _accessCubit;
  late final GoRouter _router;
  StreamSubscription<AuthState>? _authSubscription;
  String? _lastSyncedUid;

  @override
  void initState() {
    super.initState();
    _authCubit = sl<AuthCubit>();
    _coursesCubit = sl<CoursesCubit>();
    _accessCubit = sl<AccessCubit>();
    _router = createStudentRouter(_authCubit);

    void handleAuthState(AuthState state) {
      if (state is Authenticated) {
        if (_lastSyncedUid != state.user.uid) {
          _lastSyncedUid = state.user.uid;
          _accessCubit.listenToStudentRequests(state.user.uid);
          unawaited(_coursesCubit.syncStudentState(authCubit: _authCubit));
          if (sl.isRegistered<WatchQueue>()) {
            unawaited(sl<WatchQueue>().flush(state.user.uid).catchError((_) {}));
          }
          sl<NotificationService>().syncFCMToken(state.user.uid);
        }
      } else if (state is Unauthenticated || state is AuthSuspended || state is AuthPendingApproval) {
        _lastSyncedUid = null;
        _accessCubit.reset();
        _coursesCubit.clearStudentSession();
      }
    }

    handleAuthState(_authCubit.state);
    _authSubscription = _authCubit.stream.listen(handleAuthState);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _router.dispose();
    _authCubit.close();
    _coursesCubit.close();
    _accessCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: _authCubit),
        BlocProvider<CoursesCubit>.value(value: _coursesCubit),
        BlocProvider<AccessCubit>.value(value: _accessCubit),
      ],
      child: MaterialApp.router(
        key: ValueKey(context.locale.languageCode),
        title: 'app_name'.tr(),
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        builder: (context, child) {
          return BlocBuilder<AuthCubit, AuthState>(
            bloc: _authCubit,
            builder: (context, authState) {
              final studentId = authState is Authenticated
                  ? authState.user.uid
                  : null;
              final apiClient = sl.isRegistered<ApiClient>() ? sl<ApiClient>() : null;
              return SecurityProtectionWatcher(
                studentId: studentId,
                apiClient: apiClient,
                child: OnboardingGate(
                  onSelectRegister: () {
                    if (_authCubit.state is! Authenticated) {
                      _router.go('/register');
                    }
                  },
                  onSelectLogin: () {
                    if (_authCubit.state is! Authenticated) {
                      _router.go('/login');
                    }
                  },
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
          );
        },
        theme: AppTheme.lightTheme,
      ),
    );
  }
}

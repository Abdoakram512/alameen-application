import 'dart:async';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/config/app_config.dart';
import 'core/di/injection_container.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/courses/presentation/cubits/course_entitlement/course_entitlement_cubit.dart';
import 'features/payments/presentation/cubits/receipts/receipts_cubit.dart';
import 'logic/auth/auth_cubit.dart';
import 'logic/auth/auth_state.dart';
import 'logic/courses/courses_cubit.dart';
import 'navigation/app_router.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/security/security_protection_watcher.dart';
import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize localization before its inherited widgets are used.
  // Do not block the first Flutter frame on dependency registration.
  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: AppConfig.supportedLocales,
      path: AppConfig.translationsPath,
      fallbackLocale: AppConfig.fallbackLocale,
      saveLocale: true,
      useOnlyLangCode: true,
      child: const _BootstrapGate(),
    ),
  );
}

/// Render the existing Flutter splash before registering lazy dependencies.
/// Native Android launch themes remain the unmodified Flutter defaults.
class _BootstrapGate extends StatefulWidget {
  const _BootstrapGate();

  @override
  State<_BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<_BootstrapGate> {
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Register dependencies only after the splash has had a chance to paint.
    // This is event-driven; no arbitrary splash delay is introduced.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_initialize());
    });
  }

  Future<void> _initialize() async {
    try {
      await initDependencies();
      if (mounted) setState(() => _ready = true);
    } catch (error, stackTrace) {
      // Keep a retryable state rather than permanently blocking on the splash.
      assert(() {
        debugPrint('App dependency initialization failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        return true;
      }());
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const SecureStudentApp();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      home: _failed
          ? Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.locale.languageCode == 'ar'
                          ? 'تعذر بدء تشغيل التطبيق.'
                          : 'Unable to start the application.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(() => _failed = false);
                        unawaited(_initialize());
                      },
                      child: Text(
                        context.locale.languageCode == 'ar'
                            ? 'إعادة المحاولة'
                            : 'Retry',
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SplashScreen(),
    );
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
  late final ReceiptsCubit _receiptsCubit;
  late final CourseEntitlementCubit _courseEntitlementCubit;
  late final GoRouter _router;
  String? _lastSyncedUid;

  @override
  void initState() {
    super.initState();
    _authCubit = sl<AuthCubit>();
    _coursesCubit = sl<CoursesCubit>();
    _receiptsCubit = sl<ReceiptsCubit>();
    _courseEntitlementCubit = sl<CourseEntitlementCubit>();
    _router = createStudentRouter(_authCubit);

    _syncSessionState(_authCubit.state);
  }

  void _syncSessionState(AuthState state) {
    if (state is Authenticated) {
      final uid = state.user.uid;
      if (_lastSyncedUid != uid) {
        if (_lastSyncedUid != null) _coursesCubit.clearStudentSession();
        _lastSyncedUid = uid;

        // الطلب الوحيد الضروري لإظهار حالة قفل الدورات والوصول في الشاشة الرئيسية
        unawaited(
          _courseEntitlementCubit.syncStudentEnrollments(studentId: uid),
        );
      }
    } else if (state is Unauthenticated ||
        state is AuthSuspended ||
        state is AuthPendingApproval) {
      _lastSyncedUid = null;
      _courseEntitlementCubit.clear();
      _coursesCubit.clearStudentSession();
      _receiptsCubit.clear();
    }
  }

  @override
  void dispose() {
    _router.dispose();
    _authCubit.close();
    _coursesCubit.close();
    _receiptsCubit.close();
    _courseEntitlementCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: _authCubit),
        BlocProvider<CoursesCubit>.value(value: _coursesCubit),
        BlocProvider<ReceiptsCubit>.value(value: _receiptsCubit),
        BlocProvider<CourseEntitlementCubit>.value(
          value: _courseEntitlementCubit,
        ),
      ],
      child: BlocListener<AuthCubit, AuthState>(
        bloc: _authCubit,
        listener: (context, authState) => _syncSessionState(authState),
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
                final apiClient = sl.isRegistered<ApiClient>()
                    ? sl<ApiClient>()
                    : null;
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
      ),
    );
  }
}

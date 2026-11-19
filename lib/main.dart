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
import 'services/notification_service.dart';
import 'services/watch_queue.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. تهيئة التدويل وحقن التبعيات الأساسية قبل الإقلاع
  await EasyLocalization.ensureInitialized();
  await initDependencies();

  // 2. إطلاق التطبيق مرة واحدة؛ شاشة البداية (Splash) تدار بسلاسة عبر GoRouter
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

        // مزامنة غير معطلة للواجهة في الخلفية للطالب المعتمد فقط
        unawaited(_receiptsCubit.loadReceipts(studentId: uid));
        unawaited(_courseEntitlementCubit.syncStudentEnrollments(studentId: uid));
        unawaited(_coursesCubit.syncStudentState(authCubit: _authCubit));

        if (sl.isRegistered<WatchQueue>()) {
          unawaited(sl<WatchQueue>().flush(uid).catchError((_) {}));
        }
        if (sl.isRegistered<NotificationService>()) {
          unawaited(sl<NotificationService>().syncFCMToken(uid));
        }
      }
    } else if (state is Unauthenticated ||
        state is AuthSuspended ||
        state is AuthPendingApproval) {
      _lastSyncedUid = null;
      _receiptsCubit.clear();
      _courseEntitlementCubit.clear();
      _coursesCubit.clearStudentSession();
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
                final studentId =
                    authState is Authenticated ? authState.user.uid : null;
                final apiClient =
                    sl.isRegistered<ApiClient>() ? sl<ApiClient>() : null;
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

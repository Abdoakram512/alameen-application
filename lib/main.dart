import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'core/config/app_config.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة الترجمة فورياً من الملفات المحلية قبل أول إطار
  await EasyLocalization.ensureInitialized();

  // 1. إظهار شاشة splash_screen.dart مع الترجمة المحلية فورياً في أول إطار
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

  // 2. تهيئة فيربيس وحقن التبعيات في الخلفية أثناء استمتاع المتدرب بشاشة السبلاش
  await Future.wait<void>([
    _initFirebase(),
    initDependencies(),
  ]);

  // تشغيل الحماية الإضافية والإشعارات في الخلفية دون تعطيل أول إطار (First Frame)
  // ملاحظة: حماية الشاشة الأصلية مفعلة بالفعل على مستوى Android OS في MainActivity.kt
  unawaited(_enableScreenProtection());
  unawaited(sl<NotificationService>().initialize());

  // 3. تسليم التحكم الكامل لتطبيق SecureStudentApp
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
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
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

  @override
  void initState() {
    super.initState();
    _authCubit = sl<AuthCubit>();
    _coursesCubit = sl<CoursesCubit>();
    _accessCubit = sl<AccessCubit>();
    _router = createStudentRouter(_authCubit);

    _authSubscription = _authCubit.stream.listen((state) {
      if (state is Authenticated) {
        _accessCubit.listenToStudentRequests(state.user.uid);
        sl<NotificationService>().syncFCMToken(state.user.uid);
      } else {
        _accessCubit.reset();
      }
    });
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
              final studentEmail = authState is Authenticated
                  ? authState.user.email
                  : null;
              return SecurityProtectionWatcher(
                studentId: studentId,
                studentEmail: studentEmail,
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

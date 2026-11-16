import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/di/injection_container.dart';
import 'screens/splash/splash_screen.dart';
import 'services/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    _installErrorHandlers();

    await EasyLocalization.ensureInitialized();

    // 1. إظهار splash_screen.dart فورياً مع الترجمة المحلية في أول إطار
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
            child: SplashScreen(isBootstrapping: true),
          ),
        ),
      ),
    );

    // 2. تهيئة فيربيس وحقن التبعيات في الخلفية أثناء استمتاع المستخدم بشاشة السبلاش
    await Future.wait<void>([
      _initFirebase(),
      initDependencies(),
    ]);

    unawaited(_enableScreenProtection());
    unawaited(sl<AdminNotificationService>().initialize());

    // 3. تسليم التحكم الكامل لتطبيق SecureAdminApp والتوجيه السلس
    runApp(
      EasyLocalization(
        supportedLocales: AppConfig.supportedLocales,
        path: AppConfig.translationsPath,
        fallbackLocale: AppConfig.fallbackLocale,
        saveLocale: true,
        useOnlyLangCode: true,
        child: const SecureAdminApp(),
      ),
    );
  }, (error, stack) => debugPrint('Uncaught zone error: $error\n$stack'));
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firebase init check: $e');
  }
}

Future<void> _enableScreenProtection() async {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return;
  }
  try {
    await ScreenProtector.preventScreenshotOn();
    await ScreenProtector.protectDataLeakageWithColor(
      AppConfig.securityShieldColor,
    );
  } catch (e) {
    debugPrint('ScreenProtector admin init: $e');
  }
}

void _installErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PlatformDispatcher error: $error\n$stack');
    return true;
  };
}

import 'package:flutter/material.dart';

class AppConfig {
  static const String appName = 'Elameen Center';
  static const String appVersion = '1.0.1';
  static const int appBuildNumber = 3000;

  // إعدادات اللغات
  static const String translationsPath = 'assets/translations';
  static const Locale arabicLocale = Locale('ar');
  static const Locale englishLocale = Locale('en');
  static const List<Locale> supportedLocales = [arabicLocale, englishLocale];
  static const Locale fallbackLocale = arabicLocale;

  // مفتاح التوثيق لعميل الويب (OAuth Web Client ID) - مستخرج من إعدادات البيئة
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '950331031350-122fhuqtc01c5l6goeu703m3cq0kcu19.apps.googleusercontent.com',
  );

  // إعدادات درع الحماية الأمني
  static const Color securityShieldColor = Color(0xFF0F172A);
  static const int recordingCheckIntervalSeconds = 2;
}


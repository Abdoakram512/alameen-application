import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';

class TestLocalizationDelegate extends LocalizationsDelegate<Localization> {
  const TestLocalizationDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<Localization> load(Locale locale) => Future.value(Localization.instance);

  @override
  bool shouldReload(TestLocalizationDelegate old) => false;
}

Map<String, dynamic>? _cachedArMap;
Map<String, dynamic>? _cachedEnMap;

Future<void> initTestLocalization({Locale locale = const Locale('ar')}) async {
  if (_cachedArMap == null || _cachedEnMap == null) {
    try {
      _cachedArMap = jsonDecode(await rootBundle.loadString('assets/translations/ar.json')) as Map<String, dynamic>;
      _cachedEnMap = jsonDecode(await rootBundle.loadString('assets/translations/en.json')) as Map<String, dynamic>;
    } catch (_) {
      final arFile = File('assets/translations/ar.json');
      final enFile = File('assets/translations/en.json');
      if (arFile.existsSync()) {
        _cachedArMap = jsonDecode(arFile.readAsStringSync()) as Map<String, dynamic>;
      }
      if (enFile.existsSync()) {
        _cachedEnMap = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
      }
    }
  }

  setTestLocale(locale);
}

void setTestLocale(Locale locale) {
  if (_cachedArMap == null || _cachedEnMap == null) return;
  final current = locale.languageCode == 'ar' ? _cachedArMap! : _cachedEnMap!;
  final fallback = _cachedArMap!;

  Localization.load(
    locale,
    translations: Translations(current),
    fallbackTranslations: Translations(fallback),
  );
}

Widget testAppWrapper({
  required Widget child,
  Locale locale = const Locale('ar'),
  bool wrapInScaffold = true,
}) {
  setTestLocale(locale);
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      TestLocalizationDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: wrapInScaffold
        ? Scaffold(
            body: Directionality(
              textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
              child: SingleChildScrollView(child: child),
            ),
          )
        : Directionality(
            textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            child: child,
          ),
  );
}

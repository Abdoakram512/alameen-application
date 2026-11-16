// File generated for Al-Ameen Center Firebase configuration.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// خيارات تكوين Firebase الافتراضية لمنصات التشغيل المختلفة (Android, Windows, Web).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return windows;
      default:
        return windows;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAMOrq6LW3goTDaKvgodhindv9RDSHrSRM',
    appId: '1:950331031350:android:ca31d5be2c9c635ba7bd97',
    messagingSenderId: '950331031350',
    projectId: 'elameen',
    storageBucket: 'elameen.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAMOrq6LW3goTDaKvgodhindv9RDSHrSRM',
    appId: '1:950331031350:web:ca31d5be2c9c635ba7bd97',
    messagingSenderId: '950331031350',
    projectId: 'elameen',
    authDomain: 'elameen.firebaseapp.com',
    storageBucket: 'elameen.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAMOrq6LW3goTDaKvgodhindv9RDSHrSRM',
    appId: '1:950331031350:web:ca31d5be2c9c635ba7bd97',
    messagingSenderId: '950331031350',
    projectId: 'elameen',
    authDomain: 'elameen.firebaseapp.com',
    storageBucket: 'elameen.firebasestorage.app',
  );
}


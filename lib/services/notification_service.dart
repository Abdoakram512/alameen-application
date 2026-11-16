import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'mux_service.dart';

class AdminNotificationService {
  static final AdminNotificationService _instance =
      AdminNotificationService._internal();
  factory AdminNotificationService() => _instance;
  AdminNotificationService._internal();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'alameen_admin_channel',
    'إشعارات لوحة الإدارة',
    description: 'تنبيهات فورية لطلبات الاشتراك وتسليمات الطلاب',
    importance: Importance.high,
    playSound: true,
  );

  bool _initialized = false;

  Future<void> initialize({Function(String? payload)? onNotificationClick}) async {
    if (_initialized) return;

    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) {
      _initialized = true;
      return;
    }

    try {
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          onNotificationClick?.call(response.payload);
        },
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null) {
          showInstantNotification(
            id: notification.hashCode,
            title: notification.title ?? 'لوحة الإدارة',
            body: notification.body ?? '',
            payload: message.data['route'],
          );
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        onNotificationClick?.call(message.data['route']);
      });

      _initialized = true;
    } catch (e) {
      debugPrint('AdminNotificationService init error: $e');
    }
  }

  Future<void> showInstantNotification({
    int id = 0,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('showInstantNotification error: $e');
    }
  }

  Future<void> syncAdminToken(String uid) async {
    try {
      await MuxService().restoreAdminVaultCredentials();
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
        await _fcm.subscribeToTopic('admin_alerts');
        // ignore: deprecated_member_use
        final token = await _fcm.getToken();
        if (token != null) {
          await FirebaseFirestore.instance.collection('admins').doc(uid).set(
            {
              'fcmToken': token,
              'lastActive': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      }
    } catch (e) {
      debugPrint('syncAdminToken error: $e');
    }
  }

  Future<void> clearAdminSession(String? uid) async {
    try {
      await MuxService().clearCredentials();
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
        await _fcm.unsubscribeFromTopic('admin_alerts');
      }
      if (uid != null && uid.isNotEmpty) {
        await FirebaseFirestore.instance.collection('admins').doc(uid).set(
          {
            'fcmToken': FieldValue.delete(),
            'lastActive': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
        // ignore: deprecated_member_use
        await _fcm.deleteToken();
      }
    } catch (e) {
      debugPrint('clearAdminSession error: $e');
    }
  }
}

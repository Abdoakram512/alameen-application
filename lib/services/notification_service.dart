import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'alameen_channel',
    'تنبيهات الأمين سنتر',
    description: 'قناة إشعارات الاشتراكات، الدروس والواجبات',
    importance: Importance.high,
    playSound: true,
  );

  bool _initialized = false;

  Future<void> initialize({Function(String? payload)? onNotificationClick}) async {
    if (_initialized) return;

    try {
      // 1. طلب الصلاحيات
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Notification permissions denied by user');
      }

      // 2. تهيئة الإشعارات المحلية
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

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

      // 3. إنشاء قناة أندرويد
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // 4. الاستماع لإشعارات الـ Foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;

        if (notification != null) {
          showInstantNotification(
            id: notification.hashCode,
            title: notification.title ?? 'الأمين سنتر',
            body: notification.body ?? '',
            payload: message.data['route'],
          );
        }
      });

      // 5. الاستماع لفتح الإشعار أثناء وجود التطبيق بالخلفية
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        onNotificationClick?.call(message.data['route']);
      });

      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// عرض إشعار محلي فوري منبثق
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

  /// حفظ توكن الجهاز في ملف الطالب في فايرستور
  Future<void> syncFCMToken(String uid) async {
    try {
      // ignore: deprecated_member_use
      final token = await _fcm.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set(
          {
            'fcmToken': token,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    } catch (e) {
      debugPrint('syncFCMToken error: $e');
    }
  }

  /// الاشتراك في موضوع الكورس لاستقبال إشعارات الدروس الجديدة
  Future<void> subscribeToCourse(String courseId) async {
    try {
      await _fcm.subscribeToTopic('course_$courseId');
    } catch (e) {
      debugPrint('subscribeToCourse error: $e');
    }
  }

  /// إلغاء الاشتراك
  Future<void> unsubscribeFromCourse(String courseId) async {
    try {
      await _fcm.unsubscribeFromTopic('course_$courseId');
    } catch (e) {
      debugPrint('unsubscribeFromCourse error: $e');
    }
  }

  /// حذف توكن الإشعارات عند تسجيل خروج الطالب لحماية الخصوصية على الأجهزة المشتركة
  Future<void> clearFCMToken(String? uid) async {
    try {
      if (uid != null && uid.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set(
          {
            'fcmToken': FieldValue.delete(),
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      // ignore: deprecated_member_use
      await _fcm.deleteToken();
    } catch (e) {
      debugPrint('clearFCMToken error: $e');
    }
  }
}

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/screen_capture_shield_overlay.dart';

/// نطاق وراثي يمكّن مشغل الفيديو من إيقاف الصوت والصورة تلقائياً فور رصد تسجيل الشاشة.
class ScreenProtectionScope extends InheritedNotifier<ValueNotifier<bool>> {
  const ScreenProtectionScope({
    super.key,
    required ValueNotifier<bool> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static bool isCapturedOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ScreenProtectionScope>();
    return scope?.notifier?.value ?? false;
  }

  static ValueNotifier<bool>? notifierOf(BuildContext context) {
    final scope = context
        .getInheritedWidgetOfExactType<ScreenProtectionScope>();
    return scope?.notifier;
  }
}

class SecurityProtectionWatcher extends StatefulWidget {
  final Widget child;
  final String? studentId;
  final String? studentEmail;

  const SecurityProtectionWatcher({
    super.key,
    required this.child,
    this.studentId,
    this.studentEmail,
  });

  @override
  State<SecurityProtectionWatcher> createState() =>
      _SecurityProtectionWatcherState();
}

class _SecurityProtectionWatcherState extends State<SecurityProtectionWatcher>
    with WidgetsBindingObserver {
  final ValueNotifier<bool> _captureNotifier = ValueNotifier<bool>(false);
  bool _isRecordingDetected = false;
  Timer? _pollingTimer;
  DateTime? _lastAlertSentAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSecurity();
  }

  Future<void> _initializeSecurity() async {
    try {
      // 1. تفعيل الحظر العتادي للقطات الشاشة وتسجيل الشاشة (يدعم Android & iOS)
      await ScreenProtector.preventScreenshotOn();

      // 2. تعتيم شاشة تعدد المهام لمنع تسريب المحتوى عند التبديل بين التطبيقات
      await ScreenProtector.protectDataLeakageWithColor(
        AppColors.darkBackground,
      );

      // 3. الاستماع الحي لأي بدء لتسجيل الشاشة أو لقطات الشاشة
      ScreenProtector.addListener(
        () {
          if (mounted) {
            _reportSecurityViolation('screenshot_attempt');
          }
        },
        (isRecording) {
          if (mounted) {
            _setCaptureDetected(isRecording);
            if (isRecording) {
              _reportSecurityViolation('live_screen_record_started');
            }
          }
        },
      );

      // 4. فحص استباقي فوري: هل يوجد مسجل شاشة يعمل مسبقاً قبل فتح التطبيق؟
      await _checkScreenRecordingStatus();

      // 5. فحص دوري خفيف للتأكد في حال عدم إطلاق النظام لحدث المستمع
      _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _checkScreenRecordingStatus();
      });
    } catch (e) {
      debugPrint('Security Shield Init: $e');
    }
  }

  void _setCaptureDetected(bool value) {
    if (_isRecordingDetected == value) return;
    setState(() {
      _isRecordingDetected = value;
    });
    _captureNotifier.value = value;
  }

  Future<void> _checkScreenRecordingStatus() async {
    try {
      final isRecording = await ScreenProtector.isRecording();
      if (mounted && isRecording != _isRecordingDetected) {
        _setCaptureDetected(isRecording);
        if (isRecording) {
          _reportSecurityViolation('pre_opened_screen_recorder');
        }
      }
    } catch (_) {}
  }

  Future<void> _reportSecurityViolation(String alertType) async {
    final uid = widget.studentId;
    if (uid == null || uid.isEmpty) return;

    final now = DateTime.now();
    if (_lastAlertSentAt != null &&
        now.difference(_lastAlertSentAt!) < const Duration(seconds: 15)) {
      return;
    }
    _lastAlertSentAt = now;

    try {
      final platformName = mounted ? Theme.of(context).platform.name : 'unknown';
      await FirebaseFirestore.instance.collection('security_alerts').add({
        'userId': uid,
        'studentId': uid,
        'studentEmail': widget.studentEmail ?? '',
        'role': 'student_app',
        'alertType': alertType,
        'platform': platformName,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkScreenRecordingStatus();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _captureNotifier.dispose();
    try {
      ScreenProtector.removeListener();
    } catch (_) {}
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenProtectionScope(
      notifier: _captureNotifier,
      child: Stack(
        children: [
          widget.child,
          if (_isRecordingDetected)
            Positioned.fill(
              child: ScreenCaptureShieldOverlay(
                title: 'تم رصد تسجيل نشط للشاشة',
                description:
                    'محتوى مركز الأمين للتخاطب محمي لحفظ حقوق الملكية الفكرية للمحاضرات.\n\n'
                    'تم إيقاف التشغيل وحجب الشاشة مؤقتاً بسبب تشغيل أداة تسجيل شاشة على جهازك. '
                    'يرجى إيقاف التسجيل تماماً ثم الضغط على إعادة الفحص للمتابعة.',
                onRetryCheck: () async {
                  await _checkScreenRecordingStatus();
                  if (!_isRecordingDetected && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم التحقق بنجاح، يمكنك متابعة التعلم الآن.'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

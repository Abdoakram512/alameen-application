import 'dart:async';
import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';
import '../../core/di/injection_container.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/screen_capture_shield_overlay.dart';

/// نطاق وراثي يمكّن مشغل الفيديو من إيقاف الصوت والصورة فور رصد تسجيل الشاشة،
/// كما يتتبع معرّف الفيديو النشط لربطه ببلاغات الحماية الرسمية.
class ScreenProtectionScope extends InheritedNotifier<ValueNotifier<bool>> {
  final ValueNotifier<int?>? activeVideoIdNotifier;

  const ScreenProtectionScope({
    super.key,
    required ValueNotifier<bool> notifier,
    this.activeVideoIdNotifier,
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

  static void setActiveVideoId(BuildContext context, int? videoId) {
    final scope = context
        .getInheritedWidgetOfExactType<ScreenProtectionScope>();
    if (scope?.activeVideoIdNotifier != null) {
      scope!.activeVideoIdNotifier!.value = videoId;
    }
  }
}

class SecurityProtectionWatcher extends StatefulWidget {
  final Widget child;
  final String? studentId;
  final String? studentEmail;
  final ApiClient? apiClient;

  const SecurityProtectionWatcher({
    super.key,
    required this.child,
    this.studentId,
    this.studentEmail,
    this.apiClient,
  });

  @override
  State<SecurityProtectionWatcher> createState() =>
      SecurityProtectionWatcherState();
}

class SecurityProtectionWatcherState extends State<SecurityProtectionWatcher>
    with WidgetsBindingObserver {
  final ValueNotifier<bool> _captureNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int?> _activeVideoIdNotifier = ValueNotifier<int?>(null);
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

      // 5. فحص دوري خفيف في الخلفية دون استهلاك الـ Main Thread (المستمع الأصلي Event-driven نشط بالفعل)
      _pollingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
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

  /// الإبلاغ الحصري عبر Laravel REST API بدون أي كتابة احتياطية في Firestore
  /// ودون إرسال بيانات شخصية غير ضرورية (مثل البريد الإلكتروني) في التفاصيل.
  Future<void> _reportSecurityViolation(
    String alertType, {
    int? videoId,
  }) async {
    final uid = widget.studentId;
    if (uid == null || uid.isEmpty) return;

    final now = DateTime.now();
    if (_lastAlertSentAt != null &&
        now.difference(_lastAlertSentAt!) < const Duration(seconds: 15)) {
      return;
    }
    _lastAlertSentAt = now;

    try {
      final platformName = mounted
          ? Theme.of(context).platform.name
          : 'unknown';
      final effectiveVideoId = videoId ?? _activeVideoIdNotifier.value;

      final client =
          widget.apiClient ??
          (sl.isRegistered<ApiClient>() ? sl<ApiClient>() : null);
      if (client == null) return;

      await client.post(
        '/student/security/violation',
        data: <String, dynamic>{
          'type': alertType,
          'video_id': ?effectiveVideoId,
          'details': 'platform: $platformName',
        },
      );
    } catch (e) {
      debugPrint('Security violation report non-fatal: $e');
    }
  }

  @visibleForTesting
  Future<void> reportSecurityViolationForTesting(
    String alertType, {
    int? videoId,
  }) => _reportSecurityViolation(alertType, videoId: videoId);

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
    _activeVideoIdNotifier.dispose();
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
      activeVideoIdNotifier: _activeVideoIdNotifier,
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
                        content: Text(
                          'تم التحقق بنجاح، يمكنك متابعة التعلم الآن.',
                        ),
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

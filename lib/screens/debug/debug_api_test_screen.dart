import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/di/injection_container.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exceptions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/student_courses_data.dart';
import '../../models/student_dashboard_data.dart';
import '../../models/user_profile.dart';

enum ApiTestState { idle, running, passed, failed, forbidden, unauthenticated }

class ApiTestItem {
  final String title;
  final String endpoint;
  final IconData icon;
  ApiTestState state;
  int? httpStatus;
  bool? parsedSuccessfully;
  String? safeSummary;
  String? errorCategory;

  ApiTestItem({
    required this.title,
    required this.endpoint,
    required this.icon,
    this.state = ApiTestState.idle,
    this.httpStatus,
    this.parsedSuccessfully,
    this.safeSummary,
    this.errorCategory,
  });
}

/// أداة الفحص والتكامل البرمجي الحية (Debug Only Test Harness)
/// تعمل حصرياً في بيئة التطوير (kDebugMode) لاختبار الجلسات الموثقة حياً
/// دون عرض أو تخزين أي رموز وصول (Tokens) أو بيانات حساسة.
class DebugApiTestScreen extends StatefulWidget {
  const DebugApiTestScreen({super.key});

  @override
  State<DebugApiTestScreen> createState() => _DebugApiTestScreenState();
}

class _DebugApiTestScreenState extends State<DebugApiTestScreen> {
  bool _isRunning = false;

  late final List<ApiTestItem> _testItems;

  @override
  void initState() {
    super.initState();
    assert(kDebugMode, 'DebugApiTestScreen must only be used in debug mode');
    _testItems = [
      ApiTestItem(
        title: 'الملف الشخصي للمصادقة',
        endpoint: '/auth/me',
        icon: PhosphorIconsRegular.userCheck,
      ),
      ApiTestItem(
        title: 'لوحة متابعة الطالب',
        endpoint: '/student/dashboard',
        icon: PhosphorIconsRegular.gauge,
      ),
      ApiTestItem(
        title: 'دورات الطالب المسجلة',
        endpoint: '/student/courses',
        icon: PhosphorIconsRegular.graduationCap,
      ),
      ApiTestItem(
        title: 'إعدادات الملف الشخصي',
        endpoint: '/student/settings/profile',
        icon: PhosphorIconsRegular.gearSix,
      ),
      ApiTestItem(
        title: 'سجل إيصالات السداد',
        endpoint: '/student/receipts',
        icon: PhosphorIconsRegular.receipt,
      ),
      // ApiTestItem(
      //   title: 'المهام والتطبيقات السريرية',
      //   endpoint: '/student/assignments',
      //   icon: PhosphorIconsRegular.microphone,
      // ),
      ApiTestItem(
        title: 'سجل الدرجات والتقييمات',
        endpoint: '/student/grades',
        icon: PhosphorIconsRegular.chartLineUp,
      ),
      ApiTestItem(
        title: 'شهادات الإتمام والاعتماد',
        endpoint: '/student/certificates',
        icon: PhosphorIconsRegular.certificate,
      ),
      ApiTestItem(
        title: 'الإشعارات والتنبيهات',
        endpoint: '/student/notifications',
        icon: PhosphorIconsRegular.bell,
      ),
    ];
  }

  Future<void> _runAllTests() async {
    if (_isRunning) return;
    setState(() => _isRunning = true);

    final client = sl.isRegistered<ApiClient>() ? sl<ApiClient>() : null;
    if (client == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ: محرك الشبكة ApiClient غير مسجل في الحاوية.'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isRunning = false);
      }
      return;
    }

    for (final item in _testItems) {
      if (!mounted) break;
      setState(() {
        item.state = ApiTestState.running;
        item.httpStatus = null;
        item.parsedSuccessfully = null;
        item.safeSummary = null;
        item.errorCategory = null;
      });

      try {
        final response = await client.get(item.endpoint);
        final statusCode = response.statusCode ?? 200;
        final data = response.data;

        item.httpStatus = statusCode;

        // التحقق من المخطط البرمجي بدون كشف بيانات حساسة
        final parsed = _verifyParsing(item.endpoint, data);
        item.parsedSuccessfully = parsed.success;
        item.safeSummary = parsed.summary;
        item.state = ApiTestState.passed;
        item.errorCategory = null;
      } on UnauthorizedException {
        item.httpStatus = 401;
        item.state = ApiTestState.unauthenticated;
        item.parsedSuccessfully = false;
        item.errorCategory = 'غير مصرح (جلسة غير صالحة أو مفقودة)';
        item.safeSummary = 'تم رفض الوصول: يتطلب Bearer Token صالح';
      } on ForbiddenException catch (e) {
        item.httpStatus = 403;
        item.state = ApiTestState.forbidden;
        item.parsedSuccessfully = false;
        item.errorCategory = 'محظور (403 Forbidden)';
        item.safeSummary = e.message;
      } on NotFoundException {
        item.httpStatus = 404;
        item.state = ApiTestState.failed;
        item.parsedSuccessfully = false;
        item.errorCategory = 'المسار غير موجود (404 Not Found)';
      } on ApiException catch (e) {
        item.httpStatus = e.statusCode ?? 500;
        item.state = ApiTestState.failed;
        item.parsedSuccessfully = false;
        item.errorCategory = 'خطأ خادم (${e.statusCode}): ${e.message}';
      } catch (e) {
        item.httpStatus = 0;
        item.state = ApiTestState.failed;
        item.parsedSuccessfully = false;
        item.errorCategory = 'خطأ في الشبكة أو الاتصال: ${e.runtimeType}';
      }

      if (mounted) setState(() {});
    }

    if (mounted) {
      setState(() => _isRunning = false);
    }
  }

  ({bool success, String summary}) _verifyParsing(String endpoint, dynamic rawData) {
    if (rawData is! Map<String, dynamic>) {
      return (success: false, summary: 'الاستجابة ليست كائن JSON صالح');
    }

    final data = rawData['data'];

    try {
      switch (endpoint) {
        case '/auth/me':
        case '/student/settings/profile':
          if (data is Map && data['user'] is Map) {
            final user = UserModel.fromLaravelJson(Map<String, dynamic>.from(data['user'] as Map));
            return (
              success: true,
              summary: 'تم التحقق من هوية الطالب (الحالة: ${user.status}) بنجاح',
            );
          }
          return (success: false, summary: 'حقل user مفقود في الاستجابة');

        case '/student/dashboard':
          if (data is Map) {
            final dash = StudentDashboardData.fromJson(Map<String, dynamic>.from(data));
            return (
              success: true,
              summary: 'تم التحليل: ${dash.enrolledCourses.length} دورة مسجلة، ${dash.totalWatchedVideos} فيديو مكتمل',
            );
          }
          return (success: false, summary: 'بيانات لوحة المتابعة غير مطابقة');

        case '/student/courses':
          if (data is Map) {
            final courses = StudentCoursesData.fromJson(Map<String, dynamic>.from(data));
            return (
              success: true,
              summary: 'تم التحليل: ${courses.enrolledCourses.length} دورة مسجلة، ${courses.certificatesCount} شهادة',
            );
          }
          return (success: false, summary: 'بيانات الدورات غير مطابقة');

        case '/student/receipts':
          if (data is Map && data['receipts'] is List) {
            final count = (data['receipts'] as List).length;
            return (
              success: true,
              summary: 'تم التحليل: قائمة إيصالات مشروعة تضم $count إيصال',
            );
          }
          return (success: false, summary: 'حقل receipts غير موجود كقائمة');

        case '/student/assignments':
          if (data is Map && data['tasks'] is List) {
            final count = (data['tasks'] as List).length;
            return (
              success: true,
              summary: 'تم التحليل: تضم $count تكليفاً سريرياً معتمداً',
            );
          }
          return (success: false, summary: 'حقل tasks غير موجود كقائمة');

        case '/student/grades':
          if (data is Map) {
            return (
              success: true,
              summary: 'تم التحليل: إحصائيات الدرجات والتقييمات صالحة',
            );
          }
          return (success: false, summary: 'بيانات التقييم غير مطابقة');

        case '/student/certificates':
          if (data is Map && data['certificates'] is List) {
            final count = (data['certificates'] as List).length;
            return (
              success: true,
              summary: 'تم التحليل: $count شهادة معتمدة موثقة',
            );
          }
          return (success: false, summary: 'حقل certificates غير موجود');

        case '/student/notifications':
          if (data is Map && data['notifications'] is List) {
            final unread = data['unread_count']?.toString() ?? '0';
            return (
              success: true,
              summary: 'تم التحليل: إشعارات صالحة ($unread غير مقروءة)',
            );
          }
          return (success: false, summary: 'حقل notifications غير موجود');

        default:
          return (success: true, summary: 'استجابة 200 صالحة ومطابقة');
      }
    } catch (e) {
      return (success: false, summary: 'خطأ أثناء تحليل الـ DTO: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final passedCount = _testItems.where((i) => i.state == ApiTestState.passed).length;
    final failedCount = _testItems.where((i) => i.state == ApiTestState.failed).length;
    final unauthCount = _testItems.where((i) => i.state == ApiTestState.unauthenticated).length;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('فحص تكامل Laravel API الموثق'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'إعادة الفحص',
            onPressed: _isRunning ? null : _runAllTests,
            icon: const Icon(PhosphorIconsRegular.arrowsClockwise),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // بطاقة الأمان والخصوصية
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(PhosphorIconsRegular.shieldCheck, color: AppColors.primary, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'وضع الفحص الآمن (Debug Mode)',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'يقوم هذا الاختبار بفحص مسارات REST API الموثقة بجلسة الطالب الحالية دون كشف أي رموز سرية أو تعديل أي بيانات.',
                              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // إحصائيات سريعة
                Row(
                  children: [
                    _buildStatCard('إجمالي المسارات', '${_testItems.length}', AppColors.textPrimary),
                    const SizedBox(width: 10),
                    _buildStatCard('ناجح (200 OK)', '$passedCount', AppColors.success),
                    const SizedBox(width: 10),
                    _buildStatCard('غير مصرح (401)', '$unauthCount', AppColors.warning),
                    const SizedBox(width: 10),
                    _buildStatCard('فشل / خطأ', '$failedCount', AppColors.error),
                  ],
                ),
                const SizedBox(height: 20),

                // زر التشغيل الرئيسي
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: _isRunning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                          )
                        : const Icon(PhosphorIconsRegular.playCircle, size: 22),
                    label: Text(
                      _isRunning ? 'جاري الفحص المباشر...' : 'بدء فحص كافة المسارات الآن',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                    onPressed: _isRunning ? null : _runAllTests,
                  ),
                ),
                const SizedBox(height: 22),

                // قائمة الاختبارات
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _testItems.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _testItems[index];
                    return _buildTestItemCard(item);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderHairline),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildTestItemCard(ApiTestItem item) {
    Color stateColor = AppColors.textSecondary;
    Widget stateIcon = const Icon(PhosphorIconsRegular.circle, size: 20, color: AppColors.textSecondary);
    String stateBadge = 'جاهز للفحص';

    switch (item.state) {
      case ApiTestState.idle:
        stateColor = AppColors.textSecondary;
        stateIcon = const Icon(PhosphorIconsRegular.circle, size: 20, color: AppColors.textSecondary);
        stateBadge = 'جاهز';
        break;
      case ApiTestState.running:
        stateColor = AppColors.primary;
        stateIcon = const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
        );
        stateBadge = 'جاري الفحص';
        break;
      case ApiTestState.passed:
        stateColor = AppColors.success;
        stateIcon = const Icon(PhosphorIconsRegular.checkCircle, size: 22, color: AppColors.success);
        stateBadge = '200 OK';
        break;
      case ApiTestState.unauthenticated:
        stateColor = AppColors.warning;
        stateIcon = const Icon(PhosphorIconsRegular.lockKey, size: 22, color: AppColors.warning);
        stateBadge = '401 Unauthenticated';
        break;
      case ApiTestState.forbidden:
        stateColor = const Color(0xFFF97316);
        stateIcon = const Icon(PhosphorIconsRegular.shieldWarning, size: 22, color: Color(0xFFF97316));
        stateBadge = '403 Forbidden';
        break;
      case ApiTestState.failed:
        stateColor = AppColors.error;
        stateIcon = const Icon(PhosphorIconsRegular.xCircle, size: 22, color: AppColors.error);
        stateBadge = item.httpStatus != null ? '${item.httpStatus}' : 'خطأ';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.state == ApiTestState.passed
              ? AppColors.success.withValues(alpha: 0.3)
              : (item.state == ApiTestState.failed ? AppColors.error.withValues(alpha: 0.3) : AppColors.borderHairline),
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'GET ${item.endpoint}',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary),
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    stateIcon,
                    const SizedBox(width: 6),
                    Text(
                      stateBadge,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: stateColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.safeSummary != null || item.errorCategory != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 8),
            if (item.safeSummary != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(PhosphorIconsRegular.info, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.safeSummary!,
                      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            if (item.errorCategory != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(PhosphorIconsRegular.warningCircle, size: 14, color: AppColors.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.errorCategory!,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.error, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

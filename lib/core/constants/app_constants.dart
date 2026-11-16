import 'package:url_launcher/url_launcher.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'مركز الأمين للتخاطب';
  static const String appNameEn = 'Al-Ameen Speech Training & Rehabilitation Center';
  static const String appVersion = '1.0.0';
  static const String logoAsset = 'assets/images/logo.png';

  // Support & Contact
  static const String supportPhone = '01115240237';
  static const String supportWhatsApp = '201115240237';
  static const String supportWhatsAppUrl = 'https://wa.me/201115240237';

  /// فتح محادثة الدعم الفني عبر واتساب مباشرة مع رسالة اختيارية
  static Future<bool> launchWhatsApp({String? customMessage}) async {
    final text = Uri.encodeComponent(
      customMessage ??
          'السلام عليكم، أتواصل معكم بخصوص الاستفسار والدعم الفني في تطبيق مركز الأمين للتخاطب.',
    );
    final uri = Uri.parse('https://wa.me/$supportWhatsApp?text=$text');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// الاتصال المباشر برقم الدعم الفني
  static Future<bool> launchPhoneCall() async {
    final uri = Uri.parse('tel:$supportPhone');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}


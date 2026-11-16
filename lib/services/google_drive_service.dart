import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/google_drive_file.dart';

/// خدمة التكامل المباشر مع حساب Google Drive للأدمن:
/// - تسجيل الدخول بحساب Google بصلاحية قراءة ملفات Drive.
/// - استعراض والبحث في ملفات الفيديو المخزنة في Drive مباشرة داخل التطبيق.
/// - توليد روابط الاستيراد المباشر إلى Mux.
/// - فتح تطبيق Google Drive بضغطة زر واحدة.
class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const [
      'https://www.googleapis.com/auth/drive.readonly',
    ],
  );

  GoogleSignInAccount? get currentAccount => _googleSignIn.currentUser;
  bool get isSignedIn => _googleSignIn.currentUser != null;

  /// محاولة تسجيل الدخول الصامت إن كان المستخدم قد سجّل مسبقاً.
  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('Google Drive signInSilently error: $e');
      return null;
    }
  }

  /// تسجيل الدخول التفاعلي عبر حساب Google.
  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      return account;
    } catch (e) {
      debugPrint('Google Drive signIn error: $e');
      return null;
    }
  }

  /// تسجيل الخروج من حساب Google Drive المربوط.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Google Drive signOut error: $e');
    }
  }

  /// جلب ملفات الفيديو المخزنة في حساب Google Drive.
  Future<List<GoogleDriveFile>> fetchVideos({String searchQuery = ''}) async {
    final account = _googleSignIn.currentUser ?? await signInSilently();
    if (account == null) {
      throw Exception('يرجى تسجيل الدخول بحساب Google أولاً للوصول لملفات Drive');
    }

    final headers = await account.authHeaders;

    // بناء استعلام بحث Drive: ملفات الفيديو غير المحذوفة
    var query = "mimeType contains 'video/' and trashed = false";
    final cleanSearch = searchQuery.trim();
    if (cleanSearch.isNotEmpty) {
      final escaped = cleanSearch.replaceAll("'", r"\'");
      query += " and name contains '$escaped'";
    }

    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'q': query,
      'fields':
          'files(id, name, mimeType, size, webViewLink, thumbnailLink, modifiedTime)',
      'pageSize': '50',
      'orderBy': 'modifiedTime desc',
    });

    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final filesList = data['files'] as List? ?? [];
      return filesList
          .map((f) => GoogleDriveFile.fromJson(Map<String, dynamic>.from(f as Map)))
          .toList();
    } else if (response.statusCode == 401) {
      // انتهت صلاحية الـ Token، نحاول تسجيل الدخول مجدداً
      final reAuthAccount = await signIn();
      if (reAuthAccount != null) {
        return fetchVideos(searchQuery: searchQuery);
      }
      throw Exception('انتهت صلاحية جلسة Google، يرجى إعادة تسجيل الدخول');
    } else if (response.statusCode == 403) {
      try {
        final decoded =
            json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final error = decoded['error'] as Map<String, dynamic>?;
        final message = (error?['message'] as String?) ?? '';
        if (message.contains('Google Drive API has not been used') ||
            message.contains('is disabled') ||
            response.body.contains('SERVICE_DISABLED') ||
            response.body.contains('accessNotConfigured')) {
          throw Exception(
            'خدمة Google Drive API غير مفعّلة في مشروع Google Cloud Console الخاص بالتطبيق.\n\n'
            'يمكنك تفعيلها من Google Cloud Console، أو استخدام خيار "رابط" ولصق رابط ملف Drive وسيقوم Mux بسحبه فوراً دون الحاجة لتفعيل الـ API.',
          );
        }
      } catch (e) {
        if (e is Exception && !e.toString().contains('FormatException')) {
          rethrow;
        }
      }
      throw Exception(
        'تم رفض الوصول إلى Google Drive (403). يرجى التأكد من صلاحيات الحساب أو مشاركة رابط الملف مباشرة.',
      );
    } else {
      String cleanError =
          'تعذر جلب ملفات Google Drive (كود ${response.statusCode})';
      try {
        final decoded =
            json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final error = decoded['error'] as Map<String, dynamic>?;
        final msg = error?['message'] as String?;
        if (msg != null && msg.isNotEmpty) {
          cleanError = msg;
        }
      } catch (_) {}
      throw Exception(cleanError);
    }
  }

  /// فتح تطبيق Google Drive المثبت على الهاتف أو المتصفح مباشرة.
  Future<bool> openGoogleDriveApp() async {
    final driveUri = Uri.parse('https://drive.google.com');
    try {
      return await launchUrl(
        driveUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Could not launch Google Drive URL: $e');
      return false;
    }
  }
}


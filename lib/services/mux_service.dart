import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MuxUploadResult {
  final String playbackId;
  final String? assetId;
  final String? uploadId;

  MuxUploadResult({
    required this.playbackId,
    this.assetId,
    this.uploadId,
  });
}

class MuxAssetStatusInfo {
  final String assetId;
  final String playbackId;
  final String status; // 'preparing', 'ready', 'errored'
  final double progress;
  final double? durationSeconds;
  final String? errorMessage;

  MuxAssetStatusInfo({
    required this.assetId,
    required this.playbackId,
    required this.status,
    required this.progress,
    this.durationSeconds,
    this.errorMessage,
  });

  bool get isReady => status == 'ready';
  bool get isErrored => status == 'errored';
  bool get isProcessing => status == 'preparing';

  String formatDuration() {
    if (durationSeconds == null || durationSeconds! <= 0) return 'تلقائية (Mux)';
    final totalSec = durationSeconds!.round();
    final hours = totalSec ~/ 3600;
    final minutes = (totalSec % 3600) ~/ 60;
    final seconds = totalSec % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class MuxService {
  static final MuxService _instance = MuxService._internal();
  factory MuxService() => _instance;
  MuxService._internal() {
    _purgeLegacyDiskSecrets();
  }

  /// رابط دوال السحابة الآمنة (Firebase Cloud Functions) لعزل مفاتيح Mux عن الجهاز.
  static const String _functionsBaseUrl = String.fromEnvironment(
    'FUNCTIONS_BASE_URL',
    defaultValue: 'https://us-central1-elameen.cloudfunctions.net',
  );

  /// مفاتيح Mux API تُحقن عبر متغيرات البيئة (--dart-define) أو تُسترجع من خزينة المشرف في Firestore (/admins/{uid}).
  /// خالية تماماً من أي مفاتيح سرية مدمجة في الكود المصدري.
  static const String defaultTokenId = '';
  static const String defaultTokenSecret = '';

  static const String _envTokenId = String.fromEnvironment(
    'MUX_TOKEN_ID',
    defaultValue: defaultTokenId,
  );
  static const String _envTokenSecret = String.fromEnvironment(
    'MUX_TOKEN_SECRET',
    defaultValue: defaultTokenSecret,
  );

  String tokenId = _envTokenId;
  String tokenSecret = _envTokenSecret;
  bool _cloudEndpointVerified = false;
  bool _cloudEndpointUnavailable = false;

  Future<void> _purgeLegacyDiskSecrets() async {
    try {
      final prefs = SharedPreferencesAsync();
      await prefs.remove('mux_token_id');
      await prefs.remove('mux_token_secret');
    } catch (_) {}
  }

  /// استرجاع مفاتيح Mux من وثيقة المشرف المعزولة في Firestore (/admins/{uid})
  Future<void> restoreAdminVaultCredentials() async {
    if (hasLocalSessionCredentials) return;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) return;
      final doc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(uid)
          .get();
      final data = doc.data();
      if (data == null) return;
      final savedId = (data['muxTokenId'] as String?)?.trim() ?? '';
      final savedSecret = (data['muxTokenSecret'] as String?)?.trim() ?? '';
      if (savedId.isNotEmpty && savedSecret.isNotEmpty) {
        tokenId = savedId;
        tokenSecret = savedSecret;
      } else {
        tokenId = defaultTokenId;
        tokenSecret = defaultTokenSecret;
      }
    } catch (_) {
      tokenId = defaultTokenId;
      tokenSecret = defaultTokenSecret;
    }
  }

  Future<void> saveCredentials(String id, String secret) async {
    tokenId = id.trim().isNotEmpty ? id.trim() : defaultTokenId;
    tokenSecret = secret.trim().isNotEmpty ? secret.trim() : defaultTokenSecret;
    await _purgeLegacyDiskSecrets();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        await FirebaseFirestore.instance.collection('admins').doc(uid).set(
          {
            'muxTokenId': tokenId,
            'muxTokenSecret': tokenSecret,
            'muxUpdatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    } catch (_) {}
  }

  Future<void> clearCredentials() async {
    tokenId = defaultTokenId;
    tokenSecret = defaultTokenSecret;
    _cloudEndpointVerified = false;
    await _purgeLegacyDiskSecrets();
  }

  bool get hasLocalSessionCredentials =>
      tokenId.trim().isNotEmpty && tokenSecret.trim().isNotEmpty;

  bool get isConfigured =>
      _cloudEndpointVerified || hasLocalSessionCredentials;

  String _getAuthHeader() {
    final credentials = '$tokenId:$tokenSecret';
    return 'Basic ${base64Encode(utf8.encode(credentials))}';
  }

  Future<String?> _getAdminBearerToken() async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (_) {
      return null;
    }
  }

  /// اختبار الاتصال عبر الخادم السحابي أولاً ثم مفاتيح الجلسة عند الحاجة
  Future<bool> verifyCredentials() async {
    await restoreAdminVaultCredentials();
    if (hasLocalSessionCredentials) {
      try {
        final response = await http.get(
          Uri.parse('https://api.mux.com/video/v1/assets?limit=1'),
          headers: {'Authorization': _getAuthHeader()},
        );
        if (response.statusCode == 200) return true;
      } catch (_) {}
    }

    final idToken = await _getAdminBearerToken();
    if (idToken != null &&
        _functionsBaseUrl.isNotEmpty &&
        !_cloudEndpointUnavailable) {
      try {
        final resp = await http
            .get(
              Uri.parse('$_functionsBaseUrl/getMuxUploadStatus?uploadId=ping'),
              headers: {'Authorization': 'Bearer $idToken'},
            )
            .timeout(const Duration(seconds: 5));
        if (resp.statusCode == 404) {
          _cloudEndpointUnavailable = true;
        } else if (resp.statusCode == 200 ||
            resp.statusCode == 400 ||
            resp.statusCode == 502) {
          _cloudEndpointVerified = true;
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// 1. إنشاء رابط رفع مباشر من Mux
  Future<Map<String, dynamic>> createDirectUpload() async {
    await restoreAdminVaultCredentials();
    if (!hasLocalSessionCredentials) {
      throw StateError('بيانات اعتماد Mux غير مهيأة. يرجى إدخال المفاتيح في إعدادات المنصة.');
    }

    final response = await http.post(
      Uri.parse('https://api.mux.com/video/v1/uploads'),
      headers: {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'cors_origin': '*',
        'new_asset_settings': {
          'playback_policy': ['public'],
        },
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'];
      return {
        'uploadId': data['id'],
        'uploadUrl': data['url'],
        'viaCloud': false,
      };
    } else {
      throw Exception('فشل إنشاء رابط الرفع من Mux: ${response.body}');
    }
  }

  /// 2. رفع ملف الفيديو بنظام المقاطع المعتمد من Mux (Resumable Chunked PUT)
  /// وفق بروتوكول UpChunk حيث يُرفع الفيديو بمقاطع مضاعفة لـ 256KB مع ترويسة Content-Range
  /// لتوفير تتبع حي وحقيقي 100% لنسبة الإرسال عبر الشبكة مع إعادة المحاولة التلقائية عند تعثر أي مقطع.
  Future<void> uploadVideoFile(
    String uploadUrl,
    File file, {
    void Function(int sentBytes, int totalBytes)? onProgress,
    void Function(String statusMessage)? onStatusUpdate,
  }) async {
    final fileLength = await file.length();
    if (fileLength == 0) {
      throw Exception('ملف الفيديو المختار فارغ (0 بايت).');
    }

    const chunkSize = 2 * 1024 * 1024; // 2 MB (مضاعف لـ 256KB)
    final totalChunks = (fileLength / chunkSize).ceil();
    final randomAccess = await file.open(mode: FileMode.read);
    final client = http.Client();

    try {
      int uploadedBytes = 0;
      int chunkIndex = 0;
      onProgress?.call(0, fileLength);

      while (uploadedBytes < fileLength) {
        chunkIndex++;
        final remaining = fileLength - uploadedBytes;
        final currentChunkSize = remaining > chunkSize ? chunkSize : remaining;
        final chunkData = await randomAccess.read(currentChunkSize);
        if (chunkData.isEmpty) break;

        final startByte = uploadedBytes;
        final endByte = uploadedBytes + chunkData.length - 1;
        final pct = ((uploadedBytes + chunkData.length) / fileLength * 100).clamp(0, 100).toInt();

        onStatusUpdate?.call('جاري رفع المقطع $chunkIndex من $totalChunks إلى Mux ($pct%)...');

        int retryCount = 0;
        bool chunkSuccess = false;
        String lastError = '';

        while (!chunkSuccess && retryCount < 3) {
          try {
            final response = await client.put(
              Uri.parse(uploadUrl),
              headers: {
                'Content-Length': '${chunkData.length}',
                'Content-Range': 'bytes $startByte-$endByte/$fileLength',
                'Content-Type': 'video/mp4',
              },
              body: chunkData,
            ).timeout(const Duration(seconds: 60));

            // UpChunk protocol: 308 for partial chunk, 200/201/204 for success
            if (response.statusCode == 200 ||
                response.statusCode == 201 ||
                response.statusCode == 204 ||
                response.statusCode == 308) {
              chunkSuccess = true;
            } else {
              lastError = 'HTTP ${response.statusCode}: ${response.body}';
            }
          } catch (e) {
            lastError = e.toString();
          }

          if (!chunkSuccess) {
            retryCount++;
            if (retryCount < 3) {
              onStatusUpdate?.call('إعادة محاولة المقطع $chunkIndex (محاولة $retryCount من 3)...');
              await Future.delayed(Duration(seconds: retryCount * 2));
            }
          }
        }

        if (!chunkSuccess) {
          throw Exception(
            'تعثر رفع مقطع الفيديو رقم $chunkIndex من $totalChunks: $lastError',
          );
        }

        uploadedBytes += chunkData.length;
        onProgress?.call(uploadedBytes, fileLength);
      }
    } finally {
      await randomAccess.close();
      client.close();
    }
  }

  /// 3. استرجاع Asset ID و Playback ID بعد اكتمال الرفع
  Future<MuxUploadResult> waitForPlaybackId(
    String uploadId, {
    bool viaCloud = false,
    int maxAttempts = 40,
    void Function(String statusMessage)? onStatusUpdate,
  }) async {
    for (int i = 1; i <= maxAttempts; i++) {
      onStatusUpdate?.call('جاري تجهيز البث في سيرفرات Mux (فحص $i من $maxAttempts)...');
      await Future.delayed(const Duration(seconds: 3));

      final uploadResp = await http.get(
        Uri.parse('https://api.mux.com/video/v1/uploads/$uploadId'),
        headers: {'Authorization': _getAuthHeader()},
      );

      if (uploadResp.statusCode == 200) {
        final uploadData = jsonDecode(uploadResp.body)['data'];
        final assetId = uploadData['asset_id'];

        if (assetId != null) {
          final assetResp = await http.get(
            Uri.parse('https://api.mux.com/video/v1/assets/$assetId'),
            headers: {'Authorization': _getAuthHeader()},
          );

          if (assetResp.statusCode == 200) {
            final assetData = jsonDecode(assetResp.body)['data'];
            final playbackIds = assetData['playback_ids'] as List?;
            if (playbackIds != null && playbackIds.isNotEmpty) {
              final playbackId = playbackIds.first['id'];
              return MuxUploadResult(
                playbackId: playbackId,
                assetId: assetId,
                uploadId: uploadId,
              );
            }
          }
        }
      }
    }
    throw Exception(
      'استغرق تجهيز البث وقتاً أطول من المعتاد، يرجى المحاولة بعد لحظات.',
    );
  }

  Future<MuxUploadResult> processFullUpload(
    File videoFile, {
    void Function(int sentBytes, int totalBytes)? onProgress,
    void Function(String statusMessage)? onStatusUpdate,
  }) async {
    onStatusUpdate?.call('جاري تجهيز جلسة الرفع في Mux...');
    final directUpload = await createDirectUpload();

    onStatusUpdate?.call('جاري بدء نقل مقاطع الفيديو...');
    await uploadVideoFile(
      directUpload['uploadUrl'] as String,
      videoFile,
      onProgress: onProgress,
      onStatusUpdate: onStatusUpdate,
    );

    onStatusUpdate?.call('اكتمل نقل الملف بنسبة 100%! جاري تجهيز البث وجودات الفيديو في سيرفرات Mux...');
    return waitForPlaybackId(
      directUpload['uploadId'] as String,
      viaCloud: directUpload['viaCloud'] == true,
      maxAttempts: 40,
      onStatusUpdate: onStatusUpdate,
    );
  }

  // ---------------------------------------------------------------------------
  // استيراد فيديو من رابط (Drive / Dropbox / أي رابط HTTPS مباشر) ليسحبه Mux
  // ---------------------------------------------------------------------------

  /// يسجل الفيديو فورياً في Mux من رابط سحابي ويعيد معرف الـ Asset والـ Playback ID خلال 1-2 ثانية فقط
  /// دون إجبار الأدمن على الانتظار المتزامن لملفات الـ 10GB!
  Future<MuxUploadResult> registerUrlAsset(String videoUrl) async {
    await restoreAdminVaultCredentials();
    if (!hasLocalSessionCredentials) {
      throw StateError('بيانات اعتماد Mux غير مهيأة. يرجى إدخال المفاتيح في إعدادات المنصة.');
    }

    final response = await http.post(
      Uri.parse('https://api.mux.com/video/v1/assets'),
      headers: {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'input': [
          {'url': videoUrl},
        ],
        'playback_policy': ['public'],
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'] as Map<String, dynamic>;
      final assetId = data['id'] as String;
      final playbackIds = data['playback_ids'] as List?;
      final playbackId = (playbackIds != null && playbackIds.isNotEmpty)
          ? playbackIds.first['id'] as String
          : '';
      return MuxUploadResult(
        playbackId: playbackId,
        assetId: assetId,
      );
    }

    String errorMsg = 'فشل تسجيل الفيديو في Mux من الرابط';
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>?;
      final msg = error?['message'] as String?;
      if (msg != null && msg.isNotEmpty) {
        errorMsg = msg;
      }
    } catch (_) {}
    throw Exception(errorMsg);
  }

  /// يستعلم عن حالة الـ Asset في Mux لمعرفة التقدم والجاهزية والمدة
  Future<MuxAssetStatusInfo> getAssetStatus(String assetId) async {
    await restoreAdminVaultCredentials();
    if (!hasLocalSessionCredentials) {
      throw StateError('بيانات اعتماد Mux غير مهيأة. يرجى إدخال المفاتيح في إعدادات المنصة.');
    }

    final resp = await http.get(
      Uri.parse('https://api.mux.com/video/v1/assets/$assetId'),
      headers: {'Authorization': _getAuthHeader()},
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body)['data'] as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'preparing';
      final playbackIds = data['playback_ids'] as List?;
      final playbackId = (playbackIds != null && playbackIds.isNotEmpty)
          ? playbackIds.first['id'] as String
          : '';
      final durationSeconds = (data['duration'] as num?)?.toDouble();

      final progressMap = data['progress'] as Map<String, dynamic>?;
      final progressVal = (progressMap?['progress'] as num?)?.toDouble() ??
          (status == 'ready' ? 100.0 : 0.0);

      String? errorMessage;
      if (status == 'errored') {
        final errors = data['errors'] as Map<String, dynamic>?;
        final msgs = errors?['messages'] as List?;
        if (msgs != null && msgs.isNotEmpty) {
          errorMessage = msgs.first.toString();
        } else {
          errorMessage = 'تعذر على خوادم Mux سحب ملف الفيديو أو معالجته';
        }
      }

      return MuxAssetStatusInfo(
        assetId: assetId,
        playbackId: playbackId,
        status: status,
        progress: progressVal,
        durationSeconds: durationSeconds,
        errorMessage: errorMessage,
      );
    }
    throw Exception('تعذر استعلام حالة الفيديو من Mux (كود ${resp.statusCode})');
  }

  /// ينشئ Asset في Mux من رابط. يحاول عبر Cloud Function أولاً ثم مفاتيح الجلسة.
  Future<({String assetId, bool viaCloud})> createAssetFromUrl(
    String videoUrl,
  ) async {
    final idToken = await _getAdminBearerToken();
    if (idToken != null &&
        _functionsBaseUrl.isNotEmpty &&
        !_cloudEndpointUnavailable) {
      try {
        final cloudResp = await http
            .post(
              Uri.parse('$_functionsBaseUrl/createMuxAssetFromUrl'),
              headers: {
                'Authorization': 'Bearer $idToken',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'url': videoUrl}),
            )
            .timeout(const Duration(seconds: 15));

        if (cloudResp.statusCode == 404) {
          _cloudEndpointUnavailable = true;
        } else if (cloudResp.statusCode == 201 || cloudResp.statusCode == 200) {
          _cloudEndpointVerified = true;
          final data = jsonDecode(cloudResp.body) as Map<String, dynamic>;
          return (assetId: data['assetId'] as String, viaCloud: true);
        } else if (cloudResp.statusCode == 400) {
          throw Exception('الرابط غير صالح. يجب أن يبدأ بـ https وأن يكون مباشراً.');
        }
      } on TimeoutException {
        // نتراجع لمفاتيح الجلسة.
      } on http.ClientException {
        // نتراجع لمفاتيح الجلسة.
      }
    }

    await restoreAdminVaultCredentials();
    if (!hasLocalSessionCredentials) {
      throw StateError('بيانات اعتماد Mux غير مهيأة. يرجى إدخال المفاتيح في إعدادات المنصة.');
    }

    final response = await http.post(
      Uri.parse('https://api.mux.com/video/v1/assets'),
      headers: {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'input': [
          {'url': videoUrl},
        ],
        'playback_policy': ['public'],
      }),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'] as Map<String, dynamic>;
      return (assetId: data['id'] as String, viaCloud: false);
    }
    throw Exception('فشل إنشاء الفيديو في Mux من الرابط: ${response.body}');
  }

  /// ينتظر جاهزية الـ Asset المنشأ من رابط ويعيد Playback ID.
  Future<MuxUploadResult> waitForAssetPlaybackId(
    String assetId, {
    bool viaCloud = false,
    int maxAttempts = 60,
    void Function(int attempt)? onPoll,
  }) async {
    for (var i = 0; i < maxAttempts; i++) {
      await Future<void>.delayed(const Duration(seconds: 4));
      onPoll?.call(i + 1);

      Map<String, dynamic>? status;
      if (viaCloud) {
        final idToken = await _getAdminBearerToken();
        if (idToken != null) {
          final resp = await http.get(
            Uri.parse(
              '$_functionsBaseUrl/getMuxAssetStatus?assetId=${Uri.encodeComponent(assetId)}',
            ),
            headers: {'Authorization': 'Bearer $idToken'},
          );
          if (resp.statusCode == 200) {
            status = jsonDecode(resp.body) as Map<String, dynamic>;
          }
        }
      } else {
        final resp = await http.get(
          Uri.parse('https://api.mux.com/video/v1/assets/$assetId'),
          headers: {'Authorization': _getAuthHeader()},
        );
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body)['data'] as Map<String, dynamic>;
          final playbackIds = data['playback_ids'] as List?;
          final playbackId = (playbackIds != null && playbackIds.isNotEmpty)
              ? playbackIds.first['id'] as String?
              : null;
          status = {
            'ready': data['status'] == 'ready' && playbackId != null,
            'errored': data['status'] == 'errored',
            'playbackId': playbackId,
          };
        }
      }

      if (status == null) continue;
      if (status['errored'] == true) {
        throw Exception(
          'تعذر على Mux قراءة الفيديو من الرابط. تأكد أن الملف مشارك للجميع وأن الرابط مباشر.',
        );
      }
      if (status['ready'] == true && status['playbackId'] != null) {
        return MuxUploadResult(
          playbackId: status['playbackId'] as String,
          assetId: assetId,
        );
      }
    }
    throw Exception(
      'استغرق سحب الفيديو وقتاً أطول من المعتاد. سيستمر Mux في معالجته؛ أعد المحاولة بعد قليل.',
    );
  }

  Future<MuxUploadResult> processUrlImport(
    String videoUrl, {
    void Function(int attempt)? onPoll,
  }) async {
    final created = await createAssetFromUrl(videoUrl);
    return waitForAssetPlaybackId(
      created.assetId,
      viaCloud: created.viaCloud,
      onPoll: onPoll,
    );
  }
}

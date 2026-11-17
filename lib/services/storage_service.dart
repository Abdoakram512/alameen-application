import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../core/utils/app_media_compressor.dart';

class StorageService {
  static const String mediaScheme = 'firestore-media://';
  static const int _maxVaultBytes = 12 * 1024 * 1024; // 12 MB
  static const int _inlineBase64Limit = 680000;
  static const int _chunkBase64Size = 650000;
  static const int _maxMemoryCacheEntries = 40;

  // By default true to avoid 4-second timeout on Firebase Spark plan (which has no cloud storage bucket)
  static bool _firebaseStorageUnavailable = true;
  static final Map<String, Uint8List> _memoryCache = <String, Uint8List>{};
  static final Map<String, Future<Uint8List>> _inFlight =
      <String, Future<Uint8List>>{};

  final FirebaseStorage? _injectedStorage;
  final FirebaseFirestore? _injectedFirestore;

  StorageService({
    FirebaseStorage? storage,
    FirebaseFirestore? firestore,
  })  : _injectedStorage = storage,
        _injectedFirestore = firestore;

  FirebaseStorage get _storage => _injectedStorage ?? FirebaseStorage.instance;
  FirebaseFirestore get _db => _injectedFirestore ?? FirebaseFirestore.instance;

  static bool isEmbeddedMediaUri(String url) {
    final trimmed = url.trim();
    return trimmed.startsWith(mediaScheme) || trimmed.startsWith('data:');
  }

  static Uint8List? getCachedBytes(String uri) {
    return _memoryCache[uri.trim()];
  }

  static void cacheBytes(String uri, Uint8List bytes) {
    if (_memoryCache.length >= _maxMemoryCacheEntries &&
        !_memoryCache.containsKey(uri)) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
    _memoryCache[uri] = bytes;
  }

  static Future<Uint8List> resolveMediaBytes(
    String uri, {
    FirebaseFirestore? firestore,
  }) {
    final trimmed = uri.trim();
    final cached = _memoryCache[trimmed];
    if (cached != null) return Future<Uint8List>.value(cached);

    final active = _inFlight[trimmed];
    if (active != null) return active;

    final future = _loadMediaBytes(trimmed, firestore: firestore);
    _inFlight[trimmed] = future;
    return future.whenComplete(() => _inFlight.remove(trimmed));
  }

  static Future<Uint8List> _loadMediaBytes(
    String uri, {
    FirebaseFirestore? firestore,
  }) async {
    if (uri.startsWith('data:')) {
      final bytes = UriData.parse(uri).contentAsBytes();
      cacheBytes(uri, bytes);
      return bytes;
    }

    if (!uri.startsWith(mediaScheme)) {
      throw ArgumentError('Unsupported embedded media URI: $uri');
    }

    final mediaId = uri.substring(mediaScheme.length).trim();
    if (mediaId.isEmpty) {
      throw StateError('معرف المرفق السحابي فارغ.');
    }

    final db = firestore ?? FirebaseFirestore.instance;
    final doc = await db.collection('media_vault').doc(mediaId).get();
    if (!doc.exists || doc.data() == null) {
      throw StateError('لم يتم العثور على الملف المرفق في قاعدة البيانات.');
    }

    final data = doc.data()!;
    final chunkCount = (data['chunkCount'] as num?)?.toInt() ?? 0;
    String fullBase64;

    if (chunkCount <= 0) {
      fullBase64 = (data['inlineData'] as String?) ?? '';
    } else {
      final chunksSnap = await db
          .collection('media_vault')
          .doc(mediaId)
          .collection('chunks')
          .orderBy('index')
          .get();
      final buffer = StringBuffer();
      for (final chunkDoc in chunksSnap.docs) {
        buffer.write((chunkDoc.data()['data'] as String?) ?? '');
      }
      fullBase64 = buffer.toString();
    }

    if (fullBase64.isEmpty) {
      throw StateError('محتوى الملف المرفق فارغ.');
    }

    final bytes = base64Decode(fullBase64);
    cacheBytes(uri, bytes);
    return bytes;
  }

  static String _resolveContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'pdf':
        return 'application/pdf';
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
      case 'aac':
        return 'audio/mp4';
      case 'wav':
        return 'audio/wav';
      case 'mp4':
      case 'mov':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }

  static String _extractExtension(String path, {String fallback = 'jpg'}) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return fallback;
    return path.substring(dot + 1).toLowerCase();
  }

  Future<String> _uploadWithVaultFallback({
    required String storagePath,
    required String mediaId,
    required String ownerId,
    required String scope,
    required String contentType,
    required File file,
  }) async {
    if (!Platform.isWindows && !_firebaseStorageUnavailable) {
      try {
        _storage.setMaxUploadRetryTime(const Duration(seconds: 3));
        _storage.setMaxOperationRetryTime(const Duration(seconds: 3));
        final ref = _storage.ref().child(storagePath);
        final uploadTask = ref.putFile(
          file,
          SettableMetadata(contentType: contentType),
        );
        try {
          final snap = await uploadTask.timeout(const Duration(seconds: 4));
          return await snap.ref
              .getDownloadURL()
              .timeout(const Duration(seconds: 4));
        } catch (_) {
          unawaited(uploadTask.cancel());
          _firebaseStorageUnavailable = true;
        }
      } catch (_) {
        _firebaseStorageUnavailable = true;
      }
    }

    final isImage = contentType.startsWith('image/');
    final uploadFile = isImage ? await AppMediaCompressor.compressImage(file) : file;
    final bytes = await uploadFile.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('الملف المختار فارغ.');
    }
    if (bytes.length > _maxVaultBytes) {
      throw StateError(
        'حجم الملف يتجاوز الحد المسموح (12 ميجابايت)، يرجى اختيار صورة أو ملف أصغر.',
      );
    }

    final encoded = base64Encode(bytes);
    final vaultRef = _db.collection('media_vault').doc(mediaId);

    if (encoded.length <= _inlineBase64Limit) {
      await vaultRef.set({
        'ownerId': ownerId,
        'scope': scope,
        'contentType': contentType,
        'byteLength': bytes.length,
        'chunkCount': 0,
        'inlineData': encoded,
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 15));
    } else {
      final parts = <String>[];
      for (var i = 0; i < encoded.length; i += _chunkBase64Size) {
        final end = (i + _chunkBase64Size < encoded.length)
            ? i + _chunkBase64Size
            : encoded.length;
        parts.add(encoded.substring(i, end));
      }

      await vaultRef.set({
        'ownerId': ownerId,
        'scope': scope,
        'contentType': contentType,
        'byteLength': bytes.length,
        'chunkCount': parts.length,
        'inlineData': '',
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 15));

      final batch = _db.batch();
      for (var i = 0; i < parts.length; i++) {
        final chunkRef = vaultRef.collection('chunks').doc(
              i.toString().padLeft(4, '0'),
            );
        batch.set(chunkRef, {
          'index': i,
          'ownerId': ownerId,
          'scope': scope,
          'data': parts[i],
        });
      }
      await batch.commit().timeout(const Duration(seconds: 20));
    }

    final uri = '$mediaScheme$mediaId';
    cacheBytes(uri, bytes);
    return uri;
  }

  /// رفع ملف حل الواجب أو التدريب العملي (يعمل على خطتي Spark و Blaze)
  Future<String> uploadAssignmentAttachment({
    required String studentId,
    required String assignmentId,
    required File file,
    String? extension,
  }) async {
    final ext = (extension ?? _extractExtension(file.path, fallback: 'jpg'))
        .toLowerCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final mediaId = 'sub_${studentId}_${assignmentId}_$timestamp.$ext';

    return _uploadWithVaultFallback(
      storagePath: 'submissions/$studentId/${assignmentId}_$timestamp.$ext',
      mediaId: mediaId,
      ownerId: studentId,
      scope: 'submission',
      contentType: _resolveContentType(ext),
      file: file,
    );
  }
}

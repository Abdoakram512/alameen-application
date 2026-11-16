import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  Future<String> uploadCourseThumbnail({
    required String courseId,
    required File file,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'courses/$courseId/thumbnail_$timestamp.jpg';

    if (!Platform.isWindows && !_firebaseStorageUnavailable) {
      try {
        _storage.setMaxUploadRetryTime(const Duration(seconds: 3));
        _storage.setMaxOperationRetryTime(const Duration(seconds: 3));
        final ref = _storage.ref().child(storagePath);
        final uploadTask = ref.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
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

    final optimizedFile = await AppMediaCompressor.compressImage(file);
    final bytes = await optimizedFile.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('ملف الصورة المختار فارغ.');
    }
    if (bytes.length > _maxVaultBytes) {
      throw StateError(
        'حجم صورة الغلاف يتجاوز الحد المسموح (12 ميجابايت)، يرجى اختيار صورة أصغر.',
      );
    }

    final encoded = base64Encode(bytes);
    final mediaId = 'cover_${courseId}_$timestamp.jpg';
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid.trim().isEmpty) {
      throw StateError('يجب تسجيل الدخول كمسؤول أولاً لإجراء الرفع.');
    }
    final ownerId = currentUid.trim();
    final vaultRef = _db.collection('media_vault').doc(mediaId);

    if (encoded.length <= _inlineBase64Limit) {
      await vaultRef.set({
        'ownerId': ownerId,
        'scope': 'public_course',
        'contentType': 'image/jpeg',
        'byteLength': bytes.length,
        'chunkCount': 0,
        'inlineData': encoded,
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('استغرق رفع صورة الغلاف وقتاً أطول من المعتاد، يرجى التحقق من اتصال الإنترنت.'),
      );
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
        'scope': 'public_course',
        'contentType': 'image/jpeg',
        'byteLength': bytes.length,
        'chunkCount': parts.length,
        'inlineData': '',
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('استغرق تجهيز بيانات الغلاف وقتاً أطول من المعتاد.'),
      );

      final batch = _db.batch();
      for (var i = 0; i < parts.length; i++) {
        final chunkRef = vaultRef.collection('chunks').doc(
              i.toString().padLeft(4, '0'),
            );
        batch.set(chunkRef, {
          'index': i,
          'ownerId': ownerId,
          'scope': 'public_course',
          'data': parts[i],
        });
      }
      await batch.commit().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('استغرق تخزين مقاطع الغلاف وقتاً أطول من المعتاد.'),
      );
    }

    final uri = '$mediaScheme$mediaId';
    cacheBytes(uri, bytes);
    return uri;
  }

  Future<String> uploadLessonThumbnail({
    required String lessonId,
    required File file,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'lessons/$lessonId/thumbnail_$timestamp.jpg';

    if (!Platform.isWindows && !_firebaseStorageUnavailable) {
      try {
        _storage.setMaxUploadRetryTime(const Duration(seconds: 3));
        _storage.setMaxOperationRetryTime(const Duration(seconds: 3));
        final ref = _storage.ref().child(storagePath);
        final uploadTask = ref.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
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

    final optimizedFile = await AppMediaCompressor.compressImage(file);
    final bytes = await optimizedFile.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('ملف الصورة المختار فارغ.');
    }
    if (bytes.length > _maxVaultBytes) {
      throw StateError('حجم صورة الغلاف يتجاوز الحد المسموح (12 ميجابايت).');
    }

    final encoded = base64Encode(bytes);
    final mediaId = 'lesson_${lessonId}_$timestamp.jpg';
    final ownerId = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    final vaultRef = _db.collection('media_vault').doc(mediaId);

    if (encoded.length <= _inlineBase64Limit) {
      await vaultRef.set({
        'ownerId': ownerId,
        'scope': 'public_lesson_thumb',
        'contentType': 'image/jpeg',
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
        'scope': 'public_lesson_thumb',
        'contentType': 'image/jpeg',
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
          'scope': 'public_lesson_thumb',
          'data': parts[i],
        });
      }
      await batch.commit().timeout(const Duration(seconds: 20));
    }

    final uri = '$mediaScheme$mediaId';
    cacheBytes(uri, bytes);
    return uri;
  }

  Future<String> uploadAssignmentAttachment({
    required String assignmentId,
    required File file,
    required String filename,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final isPdf = filename.toLowerCase().endsWith('.pdf');
    final ext = isPdf ? 'pdf' : 'bin';
    final storagePath = 'assignments/$assignmentId/attachment_${timestamp}_$filename';

    if (!Platform.isWindows && !_firebaseStorageUnavailable) {
      try {
        _storage.setMaxUploadRetryTime(const Duration(seconds: 5));
        _storage.setMaxOperationRetryTime(const Duration(seconds: 5));
        final ref = _storage.ref().child(storagePath);
        final uploadTask = ref.putFile(
          file,
          SettableMetadata(contentType: isPdf ? 'application/pdf' : 'application/octet-stream'),
        );
        try {
          final snap = await uploadTask.timeout(const Duration(seconds: 8));
          return await snap.ref
              .getDownloadURL()
              .timeout(const Duration(seconds: 5));
        } catch (_) {
          unawaited(uploadTask.cancel());
          _firebaseStorageUnavailable = true;
        }
      } catch (_) {
        _firebaseStorageUnavailable = true;
      }
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('الملف المختار فارغ.');
    }
    if (bytes.length > _maxVaultBytes) {
      throw StateError('حجم الملف يتجاوز الحد المسموح (12 ميجابايت).');
    }

    final encoded = base64Encode(bytes);
    final mediaId = 'asg_${assignmentId}_$timestamp.$ext';
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid.trim().isEmpty) {
      throw StateError('يجب تسجيل الدخول كمسؤول أولاً لرفع المرفق.');
    }
    final ownerId = currentUid.trim();
    final vaultRef = _db.collection('media_vault').doc(mediaId);

    if (encoded.length <= _inlineBase64Limit) {
      await vaultRef.set({
        'ownerId': ownerId,
        'scope': 'assignment_attachment',
        'contentType': isPdf ? 'application/pdf' : 'application/octet-stream',
        'byteLength': bytes.length,
        'chunkCount': 0,
        'inlineData': encoded,
        'filename': filename,
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('استغرق رفع ملف التكليف وقتاً أطول من المعتاد.'),
      );
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
        'scope': 'assignment_attachment',
        'contentType': isPdf ? 'application/pdf' : 'application/octet-stream',
        'byteLength': bytes.length,
        'chunkCount': parts.length,
        'inlineData': '',
        'filename': filename,
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('استغرق تجهيز ملف التكليف وقتاً أطول من المعتاد.'),
      );

      final batch = _db.batch();
      for (var i = 0; i < parts.length; i++) {
        final chunkRef = vaultRef.collection('chunks').doc(
              i.toString().padLeft(4, '0'),
            );
        batch.set(chunkRef, {
          'index': i,
          'ownerId': ownerId,
          'scope': 'assignment_attachment',
          'data': parts[i],
        });
      }
      await batch.commit().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('استغرق تخزين مقاطع ملف التكليف وقتاً أطول من المعتاد.'),
      );
    }

    final uri = '$mediaScheme$mediaId';
    cacheBytes(uri, bytes);
    return uri;
  }
}

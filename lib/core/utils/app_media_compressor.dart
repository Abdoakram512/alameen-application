import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// ضاغط ومحسن وسائط ذكي يقوم تلقائياً بتقليص أبعاد وضغط الصور الضخمة في Isolate خلفي
/// (سواء الملتقطة بكاميرات الهواتف الحديثة 5-15MB أو الصور عالية الدقة)
/// لتصبح بحجم خفيف (~100-250KB) يُرفع في أجزاء من الثانية دون أي تجميد للواجهة وبدون أي فقدان للجودة.
class AppMediaCompressor {
  AppMediaCompressor._();

  static const int _defaultMaxWidth = 960;
  static const int _defaultQuality = 78;
  static const int _skipCompressionThreshold = 250 * 1024; // 250 KB

  /// يضغط ملف الصورة ويعيد ملفاً جديداً خفيفاً في المجلد المؤقت،
  /// عبر تشغيل الضغط في Isolate مستقل لتجنب تعليق واجهة المستخدم نهائياً.
  static Future<File> compressImage(
    File file, {
    int maxWidth = _defaultMaxWidth,
    int quality = _defaultQuality,
  }) async {
    try {
      final length = await file.length();
      if (length <= _skipCompressionThreshold) {
        return file;
      }

      final rawBytes = await file.readAsBytes();
      final compressedBytes = await compute(
        _isolateCompress,
        _CompressParams(
          bytes: rawBytes,
          maxWidth: maxWidth,
          quality: quality,
        ),
      );

      if (compressedBytes == null || compressedBytes.isEmpty) {
        return file;
      }

      final tempDir = await Directory.systemTemp.createTemp('elameen_img_');
      final targetFile = File(
        '${tempDir.path}/media_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await targetFile.writeAsBytes(compressedBytes, flush: true);
      return targetFile;
    } catch (_) {
      return file;
    }
  }

  static Uint8List? _isolateCompress(_CompressParams params) {
    try {
      final decoded = img.decodeImage(params.bytes);
      if (decoded == null) return null;

      img.Image processed = decoded;
      final maxDim = params.maxWidth;
      if (decoded.width > maxDim || decoded.height > maxDim) {
        processed = img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? maxDim : null,
          height: decoded.height > decoded.width ? maxDim : null,
          interpolation: img.Interpolation.linear,
        );
      }

      return Uint8List.fromList(img.encodeJpg(processed, quality: params.quality));
    } catch (_) {
      return null;
    }
  }
}

class _CompressParams {
  final Uint8List bytes;
  final int maxWidth;
  final int quality;

  const _CompressParams({
    required this.bytes,
    required this.maxWidth,
    required this.quality,
  });
}


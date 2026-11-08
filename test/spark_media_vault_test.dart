import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/core/widgets/app_cached_image.dart';
import 'package:secure_screen_app/services/storage_service.dart';

void main() {
  // 1x1 transparent PNG
  final Uint8List onePixelPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  );

  group('Spark Media Vault Fallback & Embedded Rendering', () {
    test('Detects firestore-media:// and data: URIs accurately', () {
      expect(
        StorageService.isEmbeddedMediaUri('firestore-media://rcpt_123.jpg'),
        isTrue,
      );
      expect(
        StorageService.isEmbeddedMediaUri('data:image/png;base64,AAAA'),
        isTrue,
      );
      expect(
        StorageService.isEmbeddedMediaUri('https://example.com/cover.jpg'),
        isFalse,
      );
    });

    test('Resolves cached firestore-media:// and data: URIs to exact bytes',
        () async {
      const vaultUri = 'firestore-media://rcpt_test_u1_c1.png';
      StorageService.cacheBytes(vaultUri, onePixelPng);

      final resolvedVault = await StorageService.resolveMediaBytes(vaultUri);
      expect(resolvedVault, equals(onePixelPng));

      final dataUri = 'data:image/png;base64,${base64Encode(onePixelPng)}';
      final resolvedData = await StorageService.resolveMediaBytes(dataUri);
      expect(resolvedData, equals(onePixelPng));
    });

    testWidgets('AppCachedImage renders firestore-media:// URI via Image.memory',
        (tester) async {
      const coverUri = 'firestore-media://cover_c1_demo.png';
      StorageService.cacheBytes(coverUri, onePixelPng);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppCachedImage(
              imageUrl: coverUri,
              width: 120,
              height: 80,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
    });
  });
}


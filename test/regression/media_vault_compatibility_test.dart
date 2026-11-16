import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/services/storage_service.dart';

void main() {
  group('Regression Suite 7: Media Vault Compatibility & Base64 Chunking', () {
    test('StorageService media scheme and embedded URI recognition is preserved', () {
      expect(StorageService.mediaScheme, 'firestore-media://');
      expect(StorageService.isEmbeddedMediaUri('firestore-media://vault_doc_123'), isTrue);
      expect(StorageService.isEmbeddedMediaUri('data:image/png;base64,iVBORw0KGgo='), isTrue);
      expect(StorageService.isEmbeddedMediaUri('https://example.com/photo.jpg'), isFalse);
    });

    test('Simulated multi-chunk media upload and reassembly preserves binary integrity', () {
      // Create a 1.5MB simulated binary file (exceeds single 650KB chunk size)
      final originalBytes = Uint8List(1500 * 1024);
      for (var i = 0; i < originalBytes.length; i++) {
        originalBytes[i] = i % 256;
      }

      final base64String = base64Encode(originalBytes);
      const chunkSize = 650000;

      // Slicing into chunks
      final chunks = <String>[];
      for (var i = 0; i < base64String.length; i += chunkSize) {
        final end = (i + chunkSize < base64String.length) ? i + chunkSize : base64String.length;
        chunks.add(base64String.substring(i, end));
      }

      expect(chunks.length, greaterThan(1), reason: '1.5MB file must split into multiple chunks');

      // Reassembly
      final reassembledBase64 = chunks.join('');
      final reassembledBytes = base64Decode(reassembledBase64);

      expect(reassembledBytes.length, originalBytes.length);
      expect(reassembledBytes, orderedEquals(originalBytes), reason: 'Reassembled binary bytes must match original exactly');
    });
  });
}

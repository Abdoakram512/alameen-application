import 'package:flutter_test/flutter_test.dart';
import 'package:secure_admin_app/models/google_drive_file.dart';

void main() {
  group('GoogleDriveFile', () {
    test('parses from JSON correctly', () {
      final json = {
        'id': 'file_123456789',
        'name': 'Lecture_01-Speech_Disorders.mp4',
        'mimeType': 'video/mp4',
        'size': '157286400', // 150 MB
        'webViewLink': 'https://drive.google.com/file/d/file_123456789/view',
        'modifiedTime': '2026-11-09T08:00:00Z',
      };

      final file = GoogleDriveFile.fromJson(json);

      expect(file.id, 'file_123456789');
      expect(file.name, 'Lecture_01-Speech_Disorders.mp4');
      expect(file.mimeType, 'video/mp4');
      expect(file.sizeBytes, 157286400);
      expect(file.webViewLink, 'https://drive.google.com/file/d/file_123456789/view');
      expect(file.modifiedTime, isNotNull);
      expect(file.modifiedTime!.year, 2026);
    });

    test('generates direct Mux-compatible download URL', () {
      const file = GoogleDriveFile(
        id: '1AbCdEfGhIjKlMnOpQrStUvWxYz',
        name: 'intro.mp4',
        mimeType: 'video/mp4',
      );

      expect(
        file.directDownloadUrl,
        'https://drive.google.com/uc?export=download&id=1AbCdEfGhIjKlMnOpQrStUvWxYz',
      );
      expect(
        file.shareableUrl,
        'https://drive.google.com/file/d/1AbCdEfGhIjKlMnOpQrStUvWxYz/view',
      );
    });

    test('computes clean title by stripping extension and replacing delimiters', () {
      const file1 = GoogleDriveFile(
        id: '1',
        name: 'Lecture_02-Advanced_Stuttering_Therapy.mp4',
        mimeType: 'video/mp4',
      );
      expect(file1.cleanTitle, 'Lecture 02 Advanced Stuttering Therapy');

      const file2 = GoogleDriveFile(
        id: '2',
        name: 'جلسة_التأتأة_العملية_رقم-3.mov',
        mimeType: 'video/quicktime',
      );
      expect(file2.cleanTitle, 'جلسة التأتأة العملية رقم 3');
    });

    test('formats size correctly for KB, MB, and GB', () {
      const kbFile = GoogleDriveFile(
        id: '1',
        name: 'clip.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 512 * 1024,
      );
      expect(kbFile.sizeFormatted, '512 KB');

      const mbFile = GoogleDriveFile(
        id: '2',
        name: 'lecture.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 52428800, // 50 MB
      );
      expect(mbFile.sizeFormatted, '50.0 MB');

      const gbFile = GoogleDriveFile(
        id: '3',
        name: 'workshop.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 2684354560, // 2.5 GB
      );
      expect(gbFile.sizeFormatted, '2.5 GB');

      const zeroFile = GoogleDriveFile(
        id: '4',
        name: 'unknown.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 0,
      );
      expect(zeroFile.sizeFormatted, 'حجم غير محدد');
    });

    test('supports equality via Equatable', () {
      final now = DateTime(2026, 11, 9);
      final file1 = GoogleDriveFile(
        id: 'same_id',
        name: 'video.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 1000,
        modifiedTime: now,
      );
      final file2 = GoogleDriveFile(
        id: 'same_id',
        name: 'video.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 1000,
        modifiedTime: now,
      );

      expect(file1, equals(file2));
    });
  });
}


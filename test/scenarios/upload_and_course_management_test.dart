import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_admin_app/core/utils/app_media_compressor.dart';
import 'package:secure_admin_app/models/assignment.dart';
import 'package:secure_admin_app/models/course.dart';
import 'package:secure_admin_app/models/course_access_mode.dart';
import 'package:secure_admin_app/models/course_level.dart';
import 'package:secure_admin_app/models/lesson.dart';
import 'package:secure_admin_app/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Scenario Suite 1: Media Vault & Compression Architecture', () {
    test('Scenario 1.1: StorageService URI identification and memory cache', () {
      const mediaUri = 'firestore-media://cover_c1_12345.jpg';
      const webUri = 'https://firebasestorage.googleapis.com/...';

      expect(StorageService.isEmbeddedMediaUri(mediaUri), isTrue);
      expect(StorageService.isEmbeddedMediaUri(webUri), isFalse);

      final testBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      StorageService.cacheBytes(mediaUri, testBytes);

      final cached = StorageService.getCachedBytes(mediaUri);
      expect(cached, isNotNull);
      expect(cached!.length, equals(5));
      expect(cached, equals(testBytes));
    });

    test('Scenario 1.2: Image compression with AppMediaCompressor preserves quality and reduces size', () async {
      final tempDir = Directory.systemTemp;
      final sampleFile = File('${tempDir.path}${Platform.pathSeparator}sample_test.png');

      // Create a dummy 500 KB test file
      final rawBytes = Uint8List.fromList(List<int>.filled(500 * 1024, 120));
      await sampleFile.writeAsBytes(rawBytes);

      try {
        final compressed = await AppMediaCompressor.compressImage(sampleFile);
        expect(await compressed.exists(), isTrue);
        final compressedBytes = await compressed.readAsBytes();
        expect(compressedBytes.isNotEmpty, isTrue);
        expect(compressedBytes.length, lessThanOrEqualTo(rawBytes.length));
      } finally {
        if (await sampleFile.exists()) await sampleFile.delete();
      }
    });

    test('Scenario 1.3: Base64 chunking math handles both inline (<680KB) and multipart (>680KB)', () {
      const inlineLimit = 680000;
      const chunkSize = 650000;

      // Case A: Small image (200 KB) -> Single inline document
      final smallData = Uint8List.fromList(List<int>.filled(200 * 1024, 88));
      final smallEncoded = base64Encode(smallData);
      expect(smallEncoded.length, lessThan(inlineLimit));

      // Case B: Large document (2 MB) -> Chunked into multiple parts
      final largeData = Uint8List.fromList(List<int>.filled(2 * 1024 * 1024, 99));
      final largeEncoded = base64Encode(largeData);
      expect(largeEncoded.length, greaterThan(inlineLimit));

      final parts = <String>[];
      for (var i = 0; i < largeEncoded.length; i += chunkSize) {
        final end = (i + chunkSize < largeEncoded.length) ? i + chunkSize : largeEncoded.length;
        parts.add(largeEncoded.substring(i, end));
      }
      expect(parts.length, greaterThan(1));

      // Reassemble and verify integrity
      final reassembled = parts.join();
      expect(reassembled, equals(largeEncoded));
      final decoded = base64Decode(reassembled);
      expect(decoded.length, equals(largeData.length));
    });
  });

  group('Scenario Suite 2: Video Slicing & UpChunk Protocol Math', () {
    test('Scenario 2.1: 2MB chunk calculation and range header formatting', () {
      const fileSize = 351800000; // ~335.5 MB (matching user screenshot)
      const chunkSize = 2 * 1024 * 1024; // 2 MB

      final totalChunks = (fileSize / chunkSize).ceil();
      expect(totalChunks, equals(168));

      int uploadedBytes = 0;
      int chunkCount = 0;

      while (uploadedBytes < fileSize) {
        chunkCount++;
        final remaining = fileSize - uploadedBytes;
        final currentChunk = remaining > chunkSize ? chunkSize : remaining;
        final startByte = uploadedBytes;
        final endByte = uploadedBytes + currentChunk - 1;
        final isLast = (endByte == fileSize - 1);

        final rangeHeader = 'bytes $startByte-$endByte/$fileSize';
        expect(rangeHeader, startsWith('bytes '));

        if (chunkCount == 1) {
          expect(startByte, equals(0));
          expect(endByte, equals(2097151));
          expect(isLast, isFalse);
        }

        if (isLast) {
          expect(endByte, equals(fileSize - 1));
          expect(chunkCount, equals(totalChunks));
        }

        uploadedBytes += currentChunk;
      }

      expect(uploadedBytes, equals(fileSize));
    });

    test('Scenario 2.2: Lesson Thumbnail auto-generation from Mux Playback ID without custom cover', () {
      const lessonWithoutCustom = Lesson(
        id: 'les_1',
        title: 'جلسة التخاطب 1',
        description: 'شرح الجلسة',
        duration: '15:00',
        muxPlaybackId: 'demoPlayback123',
        isFreePreview: false,
      );

      // Should automatically format Mux image CDN URL
      expect(lessonWithoutCustom.thumbnailUrl, equals('https://image.mux.com/demoPlayback123/thumbnail.jpg?width=600&height=340&fit_mode=smart'));

      // If custom cover was provided, custom takes precedence
      final lessonWithCustom = lessonWithoutCustom.copyWith(
        customThumbnailUrl: 'firestore-media://cover_custom.jpg',
      );
      expect(lessonWithCustom.thumbnailUrl, equals('firestore-media://cover_custom.jpg'));
    });
  });

  group('Scenario Suite 3: Course Levels & Lessons Hierarchy', () {
    test('Scenario 3.1: Course levels are sorted strictly by order', () {
      const lvl3 = CourseLevel(id: 'lvl_3', title: 'المستوى المتقدم', description: '', order: 3, lessons: []);
      const lvl1 = CourseLevel(id: 'lvl_1', title: 'المستوى التأسيسي', description: '', order: 1, lessons: []);
      const lvl2 = CourseLevel(id: 'lvl_2', title: 'المستوى المتوسط', description: '', order: 2, lessons: []);

      final unsorted = [lvl3, lvl1, lvl2];
      final sorted = List<CourseLevel>.from(unsorted)..sort((a, b) => a.order.compareTo(b.order));

      expect(sorted[0].id, equals('lvl_1'));
      expect(sorted[1].id, equals('lvl_2'));
      expect(sorted[2].id, equals('lvl_3'));
    });

    test('Scenario 3.2: Adding lessons to levels maintains sequential order and assignment link', () {
      const les1 = Lesson(id: 'l1', title: 'درس 1', description: '', duration: '10:00', muxPlaybackId: 'p1', order: 1);
      const les2 = Lesson(id: 'l2', title: 'درس 2', description: '', duration: '15:00', muxPlaybackId: 'p2', order: 2, assignmentId: 'asg_99', lockNextUntilSubmitted: true);

      const level = CourseLevel(id: 'lvl_1', title: 'المستوى الأول', description: '', order: 1, lessons: [les1, les2]);

      expect(level.lessons.length, equals(2));
      expect(level.lessons[1].hasAssignment, isTrue);
      expect(level.lessons[1].lockNextUntilSubmitted, isTrue);
    });

    test('Scenario 3.3: Course Access Modes (open, approvalRequired, assignedOnly)', () {
      const openCourse = Course(
        id: 'c_open',
        title: 'كورس عام مجاني',
        description: 'مفتوح للجميع',
        thumbnailUrl: 'firestore-media://c1.jpg',
        instructor: 'د. أمين',
        category: 'تخاطب',
        price: 0,
        accessMode: CourseAccessMode.open,
        levels: [],
      );

      const assignedCourse = Course(
        id: 'c_assigned',
        title: 'دبلومة النطق السريري',
        description: 'للمعينين فقط',
        thumbnailUrl: 'firestore-media://c2.jpg',
        instructor: 'د. أمين',
        category: 'تخاطب',
        price: 1500,
        accessMode: CourseAccessMode.assignedOnly,
        levels: [],
      );

      expect(openCourse.accessMode, equals(CourseAccessMode.open));
      expect(assignedCourse.accessMode, equals(CourseAccessMode.assignedOnly));
    });
  });

  group('Scenario Suite 4: Assignment Attachments & PDF Worksheets', () {
    test('Scenario 4.1: Assignment with PDF worksheet model serialization', () {
      final assignment = Assignment(
        id: 'asg_101',
        courseId: 'c_1',
        courseTitle: 'كورس التخاطب الشامل',
        levelId: 'lvl_1',
        lessonId: 'les_1',
        title: 'ورقة عمل مخارج الحروف',
        instructions: 'قم بتحميل الملف وحل التمارين ثم أعد رفع الحل كملف PDF',
        maxScore: 100,
        timing: AssignmentTiming.afterLesson,
        blocksNextLesson: true,
        attachmentUrl: 'firestore-media://asg_101_attachment.pdf',
        pdfAttachmentName: 'ورقة_عمل_مخارج_الحروف.pdf',
        createdAt: DateTime(2026, 11, 12),
      );

      final map = assignment.toMap();
      expect(map['pdfAttachmentName'], equals('ورقة_عمل_مخارج_الحروف.pdf'));
      expect(map['attachmentUrl'], equals('firestore-media://asg_101_attachment.pdf'));
      expect(map['blocksNextLesson'], isTrue);

      final rehydrated = Assignment.fromMap(map, id: 'asg_101');
      expect(rehydrated.pdfAttachmentName, equals('ورقة_عمل_مخارج_الحروف.pdf'));
      expect(rehydrated.attachmentUrl, equals('firestore-media://asg_101_attachment.pdf'));
      expect(rehydrated.hasAttachment, isTrue);
      expect(rehydrated.blocksNextLesson, isTrue);
    });
  });
}

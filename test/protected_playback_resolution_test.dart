import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/models/lesson.dart';
import 'package:secure_screen_app/repositories/student_learning_repository.dart';
import 'package:secure_screen_app/services/firestore_service.dart';
import 'package:secure_screen_app/services/storage_service.dart';

class _FakeFirestoreService implements FirestoreService {
  final Map<String, String> vaultedPlaybackIds;
  int protectedFetchCount = 0;

  _FakeFirestoreService({this.vaultedPlaybackIds = const {}});

  @override
  Future<String?> fetchProtectedLessonPlaybackId({
    required String courseId,
    required String lessonId,
  }) async {
    protectedFetchCount++;
    return vaultedPlaybackIds['$courseId/$lessonId'];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStorageService implements StorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Protected Lesson Playback Resolution', () {
    test('Free preview lesson uses public muxPlaybackId without vault lookup',
        () async {
      final fakeFirestore = _FakeFirestoreService();
      final repo = StudentLearningRepositoryImpl(
        firestoreService: fakeFirestore,
        storageService: _FakeStorageService(),
      );

      final previewLesson = Lesson(
        id: 'les_preview_1',
        title: 'محاضرة تعريفية مجانية',
        description: 'مقدمة الكورس',
        duration: '08:00',
        muxPlaybackId: 'pub_preview_abc123',
        isFreePreview: true,
      );

      final resolved = await repo.resolveLessonPlayback(
        courseId: 'course_speech_1',
        lesson: previewLesson,
      );

      expect(fakeFirestore.protectedFetchCount, 0);
      expect(
        resolved.streamUrl,
        'https://stream.mux.com/pub_preview_abc123.m3u8',
      );
      expect(
        resolved.thumbnailUrl,
        contains('https://image.mux.com/pub_preview_abc123/thumbnail.jpg'),
      );
    });

    test(
        'Paid lesson with stripped muxPlaybackId resolves from protected_lessons vault',
        () async {
      final fakeFirestore = _FakeFirestoreService(
        vaultedPlaybackIds: {
          'course_speech_1/les_paid_2': 'vault_secret_xyz789',
        },
      );
      final repo = StudentLearningRepositoryImpl(
        firestoreService: fakeFirestore,
        storageService: _FakeStorageService(),
      );

      final paidLesson = Lesson(
        id: 'les_paid_2',
        title: 'جلسة تأهيل متقدمة',
        description: 'محتوى خاص بالمشتركين',
        duration: '24:15',
        muxPlaybackId: '',
        isFreePreview: false,
      );

      final resolved = await repo.resolveLessonPlayback(
        courseId: 'course_speech_1',
        lesson: paidLesson,
      );

      expect(fakeFirestore.protectedFetchCount, 1);
      expect(
        resolved.streamUrl,
        'https://stream.mux.com/vault_secret_xyz789.m3u8',
      );
      expect(
        resolved.thumbnailUrl,
        contains('https://image.mux.com/vault_secret_xyz789/thumbnail.jpg'),
      );
    });

    test('Paid lesson without vault entry throws StateError cleanly', () async {
      final fakeFirestore = _FakeFirestoreService();
      final repo = StudentLearningRepositoryImpl(
        firestoreService: fakeFirestore,
        storageService: _FakeStorageService(),
      );

      final unauthorizedLesson = Lesson(
        id: 'les_missing',
        title: 'جلسة غير مصرح بها',
        description: '',
        duration: '12:00',
        muxPlaybackId: '',
        isFreePreview: false,
      );

      await expectLater(
        repo.resolveLessonPlayback(
          courseId: 'course_speech_1',
          lesson: unauthorizedLesson,
        ),
        throwsStateError,
      );
    });
  });
}


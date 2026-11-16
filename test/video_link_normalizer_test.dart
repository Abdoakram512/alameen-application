import 'package:flutter_test/flutter_test.dart';
import 'package:secure_admin_app/core/utils/video_link_normalizer.dart';

void main() {
  group('VideoLinkNormalizer', () {
    test('converts Google Drive /file/d/<id>/view to direct download', () {
      final r = VideoLinkNormalizer.normalize(
        'https://drive.google.com/file/d/1AbC_dEf-123/view?usp=sharing',
      );
      expect(r?.source, VideoLinkSource.googleDrive);
      expect(
        r?.url,
        'https://drive.google.com/uc?export=download&id=1AbC_dEf-123',
      );
    });

    test('converts Google Drive open?id= links', () {
      final r = VideoLinkNormalizer.normalize(
        'https://drive.google.com/open?id=XYZ987',
      );
      expect(r?.url, 'https://drive.google.com/uc?export=download&id=XYZ987');
    });

    test('forces dl=1 on Dropbox links', () {
      final r = VideoLinkNormalizer.normalize(
        'https://www.dropbox.com/s/abc/video.mp4?dl=0',
      );
      expect(r?.source, VideoLinkSource.dropbox);
      expect(r?.url, contains('dl=1'));
      expect(r?.url, isNot(contains('dl=0')));
    });

    test('accepts direct https links as-is', () {
      final r = VideoLinkNormalizer.normalize('https://cdn.example.com/a.mp4');
      expect(r?.source, VideoLinkSource.direct);
      expect(r?.url, 'https://cdn.example.com/a.mp4');
    });

    test('rejects http, empty and malformed links', () {
      expect(VideoLinkNormalizer.normalize('http://example.com/a.mp4'), isNull);
      expect(VideoLinkNormalizer.normalize(''), isNull);
      expect(VideoLinkNormalizer.normalize('not a url'), isNull);
      expect(
        VideoLinkNormalizer.normalize('https://drive.google.com/drive/folders/abc'),
        isNull,
      );
    });
  });
}


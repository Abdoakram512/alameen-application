import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/models/video_quality.dart';

void main() {
  group('VideoQuality Tests', () {
    test('VideoQuality enum has 5 expected options', () {
      expect(VideoQuality.values.length, 5);
      expect(VideoQuality.auto.maxResolution, isNull);
      expect(VideoQuality.fhd.maxResolution, '1080p');
      expect(VideoQuality.hd.maxResolution, '720p');
      expect(VideoQuality.sd.maxResolution, '480p');
      expect(VideoQuality.low.maxResolution, '360p');
    });

    test('buildStreamUri applies max_resolution query parameter correctly', () {
      const base = 'https://stream.mux.com/abcd1234efgh.m3u8';

      final autoUri = VideoQuality.auto.buildStreamUri(base);
      expect(autoUri.toString(), 'https://stream.mux.com/abcd1234efgh.m3u8');
      expect(autoUri.queryParameters.containsKey('max_resolution'), isFalse);

      final fhdUri = VideoQuality.fhd.buildStreamUri(base);
      expect(
        fhdUri.toString(),
        'https://stream.mux.com/abcd1234efgh.m3u8?max_resolution=1080p',
      );
      expect(fhdUri.queryParameters['max_resolution'], '1080p');

      final hdUri = VideoQuality.hd.buildStreamUri(base);
      expect(
        hdUri.toString(),
        'https://stream.mux.com/abcd1234efgh.m3u8?max_resolution=720p',
      );
      expect(hdUri.queryParameters['max_resolution'], '720p');

      final sdUri = VideoQuality.sd.buildStreamUri(base);
      expect(
        sdUri.toString(),
        'https://stream.mux.com/abcd1234efgh.m3u8?max_resolution=480p',
      );
      expect(sdUri.queryParameters['max_resolution'], '480p');

      final lowUri = VideoQuality.low.buildStreamUri(base);
      expect(
        lowUri.toString(),
        'https://stream.mux.com/abcd1234efgh.m3u8?max_resolution=360p',
      );
      expect(lowUri.queryParameters['max_resolution'], '360p');
    });

    test('buildStreamUri preserves other existing query parameters', () {
      const baseWithToken =
          'https://stream.mux.com/abcd1234efgh.m3u8?token=xyz_jwt_token';

      final hdUri = VideoQuality.hd.buildStreamUri(baseWithToken);
      expect(hdUri.queryParameters['token'], 'xyz_jwt_token');
      expect(hdUri.queryParameters['max_resolution'], '720p');

      // Switching from HD to auto removes max_resolution but preserves token
      final autoUri = VideoQuality.auto.buildStreamUri(hdUri.toString());
      expect(autoUri.queryParameters['token'], 'xyz_jwt_token');
      expect(autoUri.queryParameters.containsKey('max_resolution'), isFalse);
    });

    test('buildStreamUri handles empty base URL gracefully', () {
      final uri = VideoQuality.auto.buildStreamUri('');
      expect(uri.toString(), '');
    });
  });
}


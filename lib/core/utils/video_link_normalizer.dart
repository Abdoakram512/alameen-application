/// نتيجة تطبيع رابط الفيديو.
class NormalizedVideoLink {
  final String url;
  final VideoLinkSource source;

  const NormalizedVideoLink(this.url, this.source);
}

enum VideoLinkSource { googleDrive, dropbox, direct }

/// يحوّل روابط المشاركة (Google Drive / Dropbox) إلى روابط تحميل مباشرة
/// يستطيع Mux سحبها، ويرفض أي رابط غير آمن (غير HTTPS).
class VideoLinkNormalizer {
  const VideoLinkNormalizer._();

  static final RegExp _driveFileId = RegExp(r'/file/d/([A-Za-z0-9_-]+)');

  /// يعيد `null` إن كان الرابط غير صالح.
  static NormalizedVideoLink? normalize(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return null;

    final uri = Uri.tryParse(input);
    if (uri == null || uri.scheme.toLowerCase() != 'https' || uri.host.isEmpty) {
      return null;
    }
    final host = uri.host.toLowerCase();

    if (host == 'drive.google.com' || host == 'docs.google.com') {
      final id = _driveFileId.firstMatch(uri.path)?.group(1) ??
          uri.queryParameters['id'];
      if (id == null || id.isEmpty) return null;
      return NormalizedVideoLink(
        'https://drive.google.com/uc?export=download&id=$id',
        VideoLinkSource.googleDrive,
      );
    }

    if (host == 'dropbox.com' || host == 'www.dropbox.com') {
      final params = Map<String, String>.from(uri.queryParameters)
        ..remove('dl')
        ..['dl'] = '1';
      return NormalizedVideoLink(
        uri.replace(queryParameters: params).toString(),
        VideoLinkSource.dropbox,
      );
    }

    return NormalizedVideoLink(uri.toString(), VideoLinkSource.direct);
  }
}


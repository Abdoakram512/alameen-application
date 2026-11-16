/// تمثيل خيارات جودة ودقة الفيديو المدعومة في مشغل المحاضرات.
enum VideoQuality {
  /// الجودة التلقائية المتكيفة مع سرعة اتصال الإنترنت (Auto Adaptive Bitrate)
  auto(
    label: 'تلقائي (Auto)',
    shortLabel: 'Auto',
    maxResolution: null,
  ),

  /// جودة فائقة الدقة 1080p
  fhd(
    label: '1080p (فائق الدقة)',
    shortLabel: '1080p',
    maxResolution: '1080p',
  ),

  /// جودة عالية الدقة 720p
  hd(
    label: '720p (عالي الدقة)',
    shortLabel: '720p',
    maxResolution: '720p',
  ),

  /// جودة قياسية / متوسطة 480p
  sd(
    label: '480p (جودة متوسطة)',
    shortLabel: '480p',
    maxResolution: '480p',
  ),

  /// جودة اقتصادية لتوفير باقة البيانات 360p
  low(
    label: '360p (توفير البيانات)',
    shortLabel: '360p',
    maxResolution: '360p',
  );

  final String label;
  final String shortLabel;
  final String? maxResolution;

  const VideoQuality({
    required this.label,
    required this.shortLabel,
    this.maxResolution,
  });

  /// إنشاء رابط البث النهائي مع تطبيق معامل الدقة [max_resolution] لخدمات Mux HLS.
  Uri buildStreamUri(String baseStreamUrl) {
    if (baseStreamUrl.trim().isEmpty) {
      return Uri();
    }
    final parsed = Uri.parse(baseStreamUrl);
    final params = Map<String, String>.from(parsed.queryParameters);

    if (maxResolution != null) {
      params['max_resolution'] = maxResolution!;
    } else {
      params.remove('max_resolution');
    }

    return parsed.replace(
      queryParameters: params.isEmpty ? null : params,
    );
  }
}


import 'dart:io';
import '../services/mux_service.dart';

abstract class MuxRepository {
  bool get isConfigured;
  String get tokenId;
  String get tokenSecret;
  void updateCredentials(String tokenId, String tokenSecret);
  Future<bool> verifyCredentials();
  Future<MuxUploadResult> processFullUpload(
    File file, {
    void Function(int sentBytes, int totalBytes)? onProgress,
    void Function(String statusMessage)? onStatusUpdate,
  });

  /// يسجل الفيديو فورياً في Mux من رابط سحابي ويعيد Playback ID في 1-2 ثانية دون انتظار.
  Future<MuxUploadResult> registerUrlAsset(String url);

  /// يستعلم عن حالة الـ Asset في Mux (النسبة المئوية، الجاهزية، والمدة).
  Future<MuxAssetStatusInfo> getAssetStatus(String assetId);

  /// يسحب Mux الفيديو من رابط HTTPS مباشر ويعيد Playback ID عند الجاهزية.
  Future<MuxUploadResult> importFromUrl(String url, {void Function(int attempt)? onPoll});
}

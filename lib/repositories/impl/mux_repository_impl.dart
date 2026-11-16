import 'dart:io';
import '../../services/mux_service.dart';
import '../mux_repository.dart';

class MuxRepositoryImpl implements MuxRepository {
  final MuxService _muxService;

  MuxRepositoryImpl({MuxService? muxService})
      : _muxService = muxService ?? MuxService();

  @override
  bool get isConfigured => _muxService.isConfigured;

  @override
  String get tokenId => _muxService.tokenId;

  @override
  String get tokenSecret => _muxService.tokenSecret;

  @override
  void updateCredentials(String tokenId, String tokenSecret) {
    _muxService.saveCredentials(tokenId, tokenSecret);
  }

  @override
  Future<bool> verifyCredentials() {
    return _muxService.verifyCredentials();
  }

  @override
  Future<MuxUploadResult> processFullUpload(
    File file, {
    void Function(int sentBytes, int totalBytes)? onProgress,
    void Function(String statusMessage)? onStatusUpdate,
  }) {
    return _muxService.processFullUpload(
      file,
      onProgress: onProgress,
      onStatusUpdate: onStatusUpdate,
    );
  }

  @override
  Future<MuxUploadResult> registerUrlAsset(String url) {
    return _muxService.registerUrlAsset(url);
  }

  @override
  Future<MuxAssetStatusInfo> getAssetStatus(String assetId) {
    return _muxService.getAssetStatus(assetId);
  }

  @override
  Future<MuxUploadResult> importFromUrl(
    String url, {
    void Function(int attempt)? onPoll,
  }) {
    return _muxService.processUrlImport(url, onPoll: onPoll);
  }
}

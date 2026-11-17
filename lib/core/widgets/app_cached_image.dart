import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_config.dart';
import '../../services/storage_service.dart';

class AppCachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const AppCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = imageUrl.trim();
    if (trimmed.isEmpty) {
      return _buildPlaceholder();
    }

    Widget image;
    if (StorageService.isEmbeddedMediaUri(trimmed)) {
      final syncBytes = StorageService.getCachedBytes(trimmed);
      if (syncBytes != null) {
        image = Image.memory(
          syncBytes,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      } else {
        image = FutureBuilder<Uint8List>(
          future: StorageService.resolveMediaBytes(trimmed),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Image.memory(
                snapshot.data!,
                width: width,
                height: height,
                fit: fit,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
              );
            }
            if (snapshot.hasError) {
              return _buildPlaceholder();
            }
            return _buildLoadingShimmer();
          },
        );
      }
    } else {
      final resolvedUrl = AppConfig.resolveMediaUrl(trimmed);
      image = CachedNetworkImage(
        imageUrl: resolvedUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => _buildLoadingShimmer(),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        color: Colors.white,
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2F8),
        borderRadius: borderRadius,
      ),
      child: const Center(
        child: Icon(
          Icons.school_outlined,
          color: Color(0xFF7B8AB8),
          size: 28,
        ),
      ),
    );
  }
}

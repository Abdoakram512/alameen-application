import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class ReceiptPreviewDialog extends StatelessWidget {
  final String imageUrl;
  final String? title;

  const ReceiptPreviewDialog({
    super.key,
    required this.imageUrl,
    this.title,
  });

  static void show(
    BuildContext context, {
    required String imageUrl,
    String? title,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => ReceiptPreviewDialog(
        imageUrl: imageUrl,
        title: title,
      ),
    );
  }

  Widget _buildErrorWidget() {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 44,
            color: AppColors.error,
          ),
          SizedBox(height: 8),
          Text(
            'تعذر تحميل صورة الإيصال',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Padding(
      padding: EdgeInsets.all(56),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildReceiptContent() {
    final trimmed = imageUrl.trim();
    if (trimmed.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: Text(
            'لا يوجد رابط إيصال مرفوع',
            style: AppTextStyles.bodyMedium,
          ),
        ),
      );
    }

    if (StorageService.isEmbeddedMediaUri(trimmed)) {
      return FutureBuilder<Uint8List>(
        future: StorageService.resolveMediaBytes(trimmed),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
            );
          }
          if (snapshot.hasError) {
            return _buildErrorWidget();
          }
          return _buildLoadingWidget();
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: trimmed,
      fit: BoxFit.contain,
      placeholder: (context, url) => _buildLoadingWidget(),
      errorWidget: (c, url, s) => _buildErrorWidget(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final displayTitle = title ?? (isAr ? 'معاينة إيصال الدفع' : 'Payment Receipt Preview');

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    color: AppColors.royalNavy,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: isAr ? 'إغلاق' : 'Close',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: AppColors.surfaceLevel0,
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.6,
                      maxScale: 4.5,
                      child: _buildReceiptContent(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

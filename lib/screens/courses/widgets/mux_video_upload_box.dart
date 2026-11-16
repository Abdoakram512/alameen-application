import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// مصدر الفيديو للدرس: إما رابط سحابي فائق السرعة أو رفع ملف من الجهاز.
enum VideoSourceMode { link, device }

class MuxVideoUploadBox extends StatelessWidget {
  final bool isUploading;
  final bool isSaving;
  final String uploadStatus;
  final double uploadProgress;
  final String? uploadDetails;
  final String? uploadSpeed;
  final TextEditingController playbackIdController;
  final TextEditingController linkController;
  final VideoSourceMode mode;
  final ValueChanged<VideoSourceMode> onModeChanged;
  final VoidCallback onPickVideo;
  final VoidCallback onImportLink;

  const MuxVideoUploadBox({
    super.key,
    required this.isUploading,
    required this.isSaving,
    required this.uploadStatus,
    this.uploadProgress = 0.0,
    this.uploadDetails,
    this.uploadSpeed,
    required this.playbackIdController,
    required this.linkController,
    required this.mode,
    required this.onModeChanged,
    required this.onPickVideo,
    required this.onImportLink,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = uploadStatus.contains('نجاح');
    final isError = uploadStatus.contains('خطأ');
    final busy = isUploading || isSaving;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLevel0,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'طريقة إضافة الفيديو للمحاضرة:',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<VideoSourceMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: VideoSourceMode.link,
                icon: Icon(Icons.cloud_download_rounded, size: 18),
                label: Text(
                  'رابط سحابي (+10GB)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              ButtonSegment(
                value: VideoSourceMode.device,
                icon: Icon(Icons.phone_android_rounded, size: 16),
                label: Text('ملف من الجهاز', style: TextStyle(fontSize: 12)),
              ),
            ],
            selected: {mode},
            onSelectionChanged: busy ? null : (s) => onModeChanged(s.first),
          ),
          const SizedBox(height: 12),
          if (mode == VideoSourceMode.link) ...[
            TextField(
              controller: linkController,
              enabled: !busy,
              keyboardType: TextInputType.url,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              decoration: InputDecoration(
                labelText: 'رابط الفيديو (Google Drive / Dropbox / مباشر)',
                hintText: 'https://drive.google.com/file/d/.../view',
                filled: true,
                fillColor: Colors.white,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link_rounded),
                suffixIcon: linkController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: busy ? null : linkController.clear,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        color: Color(0xFF1D4ED8),
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'ميزة السحب السحابي الذكي (Cloud-to-Cloud):',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• يدعم الفيديوهات الضخمة حتى أكثر من 10 جيجابايت بدون استهلاك باقتك أو بطارية هاتفك.\n'
                    '• يُسحب الفيديو سحابياً بين الخوادم مباشرة، ولن يتأثر التحميل إذا أغلقت التطبيق!\n'
                    '• طريقة نسخ الرابط: من تطبيق Google Drive -> خيارات الفيديو (⋮) -> نسخ الرابط.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _ActionButton(
              busy: isUploading,
              disabled: busy,
              idleIcon: Icons.bolt_rounded,
              idleLabel: 'سحب وتجهيز الفيديو فورياً (Mux Cloud)',
              busyLabel: 'جاري تسجيل الفيديو في السحابة...',
              onPressed: onImportLink,
            ),
          ] else ...[
            _ActionButton(
              busy: isUploading,
              disabled: busy,
              idleIcon: Icons.cloud_upload_outlined,
              idleLabel: 'اختيار ورفع ملف فيديو من الجهاز',
              busyLabel: 'جاري رفع الفيديو ومعالجته...',
              onPressed: onPickVideo,
            ),
          ],
          if (isUploading) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        uploadProgress > 0
                            ? '${(uploadProgress * 100).toInt()}%'
                            : 'جاري البدء...',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                      ),
                      if (uploadDetails != null && uploadDetails!.isNotEmpty)
                        Text(
                          uploadDetails!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: uploadProgress > 0 ? uploadProgress : null,
                      minHeight: 7,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          uploadStatus.isNotEmpty ? uploadStatus : 'جاري الرفع...',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (uploadSpeed != null && uploadSpeed!.isNotEmpty)
                        Text(
                          uploadSpeed!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ] else if (uploadStatus.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isError
                    ? AppColors.errorLight
                    : (isSuccess ? AppColors.successLight : AppColors.infoLight),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                uploadStatus,
                style: TextStyle(
                  fontSize: 12,
                  color: isError
                      ? AppColors.errorDark
                      : (isSuccess ? AppColors.successDark : AppColors.infoDark),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: playbackIdController,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            decoration: const InputDecoration(
              labelText: 'معرف تشغيل الفيديو (Playback ID) *',
              hintText: 'يُملأ تلقائياً في ثوانٍ أو يُدخل يدوياً',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.play_circle_outline),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final bool busy;
  final bool disabled;
  final IconData idleIcon;
  final String idleLabel;
  final String busyLabel;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.busy,
    required this.disabled,
    required this.idleIcon,
    required this.idleLabel,
    required this.busyLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: disabled ? null : onPressed,
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(idleIcon),
        label: Text(
          busy ? busyLabel : idleLabel,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

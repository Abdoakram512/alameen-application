import 'package:equatable/equatable.dart';

/// تمثيل ملف فيديو مخزن على Google Drive.
class GoogleDriveFile extends Equatable {
  final String id;
  final String name;
  final String mimeType;
  final int sizeBytes;
  final String? thumbnailLink;
  final String? webViewLink;
  final DateTime? modifiedTime;

  const GoogleDriveFile({
    required this.id,
    required this.name,
    required this.mimeType,
    this.sizeBytes = 0,
    this.thumbnailLink,
    this.webViewLink,
    this.modifiedTime,
  });

  /// رابط التصدير والتحميل المباشر المتوافق مع سيرفرات Mux.
  String get directDownloadUrl =>
      'https://drive.google.com/uc?export=download&id=$id';

  /// رابط المشاركة / المعاينة في Google Drive.
  String get shareableUrl =>
      webViewLink ?? 'https://drive.google.com/file/d/$id/view';

  /// حجم الملف بصيغة مقروءة (MB / GB).
  String get sizeFormatted {
    if (sizeBytes <= 0) return 'حجم غير محدد';
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (sizeBytes >= gb) {
      return '${(sizeBytes / gb).toStringAsFixed(1)} GB';
    } else if (sizeBytes >= mb) {
      return '${(sizeBytes / mb).toStringAsFixed(1)} MB';
    } else {
      return '${(sizeBytes / kb).toStringAsFixed(0)} KB';
    }
  }

  /// اسم المحاضرة المقترح من اسم الملف بعد تنظيف الامتداد.
  String get cleanTitle {
    var title = name;
    final dotIndex = title.lastIndexOf('.');
    if (dotIndex > 0) {
      title = title.substring(0, dotIndex);
    }
    return title.replaceAll(RegExp(r'[-_]+'), ' ').trim();
  }

  factory GoogleDriveFile.fromJson(Map<String, dynamic> json) {
    return GoogleDriveFile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'فيديو بدون عنوان',
      mimeType: json['mimeType'] as String? ?? 'video/mp4',
      sizeBytes: int.tryParse(json['size']?.toString() ?? '0') ?? 0,
      thumbnailLink: json['thumbnailLink'] as String?,
      webViewLink: json['webViewLink'] as String?,
      modifiedTime: json['modifiedTime'] != null
          ? DateTime.tryParse(json['modifiedTime'].toString())
          : null,
    );
  }

  @override
  List<Object?> get props => [id, name, mimeType, sizeBytes, modifiedTime];
}


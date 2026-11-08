import 'package:equatable/equatable.dart';

class Lesson extends Equatable {
  final String id;
  final String title;
  final String description;
  final String duration;
  final String muxPlaybackId;
  final String? muxAssetId;
  final int order;
  final bool isFreePreview;
  final bool isCompleted;

  const Lesson({
    required this.id,
    required this.title,
    required this.description,
    required this.duration,
    required this.muxPlaybackId,
    this.muxAssetId,
    this.order = 1,
    this.isFreePreview = false,
    this.isCompleted = false,
  });

  String get videoStreamUrl => 'https://stream.mux.com/$muxPlaybackId.m3u8';
  String get thumbnailUrl => 'https://image.mux.com/$muxPlaybackId/thumbnail.jpg?width=600&height=340&fit_mode=smart';

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'duration': duration,
        'muxPlaybackId': muxPlaybackId,
        'muxAssetId': muxAssetId,
        'order': order,
        'isFreePreview': isFreePreview,
      };

  factory Lesson.fromMap(Map<String, dynamic> map) => Lesson(
        id: map['id'] ?? '',
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        duration: map['duration'] ?? '',
        muxPlaybackId: map['muxPlaybackId'] ?? '',
        muxAssetId: map['muxAssetId'],
        order: map['order'] ?? 1,
        isFreePreview: map['isFreePreview'] ?? false,
      );

  Lesson copyWith({
    String? id,
    String? title,
    String? description,
    String? duration,
    String? muxPlaybackId,
    String? muxAssetId,
    int? order,
    bool? isFreePreview,
    bool? isCompleted,
  }) {
    return Lesson(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      duration: duration ?? this.duration,
      muxPlaybackId: muxPlaybackId ?? this.muxPlaybackId,
      muxAssetId: muxAssetId ?? this.muxAssetId,
      order: order ?? this.order,
      isFreePreview: isFreePreview ?? this.isFreePreview,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  int get durationInSeconds {
    final parts = duration.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = int.tryParse(parts[1]) ?? 0;
      return (m * 60) + s;
    } else if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = int.tryParse(parts[2]) ?? 0;
      return (h * 3600) + (m * 60) + s;
    }
    return 0;
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        duration,
        muxPlaybackId,
        muxAssetId,
        order,
        isFreePreview,
        isCompleted,
      ];
}

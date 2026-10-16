import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'download_item.dart';

enum VideoPlatform {
  youtube,
  tiktok,
}

class StreamOption {
  final StreamInfo? streamInfo;
  final String label;
  final String container;
  final int sizeInBytes;
  final DownloadType type;
  final String resolutionOrBitrate;
  final String? directUrl;
  final bool isNoWatermark;

  StreamOption({
    this.streamInfo,
    required this.label,
    required this.container,
    required this.sizeInBytes,
    required this.type,
    required this.resolutionOrBitrate,
    this.directUrl,
    this.isNoWatermark = false,
  });

  bool get isMp4VideoWithAudio =>
      container.toLowerCase() == 'mp4' && type == DownloadType.videoWithAudio;

  String get formattedSize {
    if (sizeInBytes <= 0) return 'Unknown size';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    int i = 0;
    double size = sizeInBytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(size < 10 && i > 0 ? 1 : 0)} ${suffixes[i]}';
  }
}

class ParsedVideoInfo {
  final String id;
  final String title;
  final String author;
  final String? authorAvatarUrl;
  final Duration? duration;
  final String thumbnailUrl;
  final int viewCount;
  final int likeCount;
  final DateTime? uploadDate;
  final String description;
  final VideoPlatform platform;
  final List<StreamOption> muxedStreams;
  final List<StreamOption> watermarkedStreams;

  ParsedVideoInfo({
    required this.id,
    required this.title,
    required this.author,
    this.authorAvatarUrl,
    required this.duration,
    required this.thumbnailUrl,
    this.viewCount = 0,
    this.likeCount = 0,
    required this.uploadDate,
    required this.description,
    this.platform = VideoPlatform.youtube,
    required this.muxedStreams,
    this.watermarkedStreams = const [],
  });

  String get formattedDuration {
    if (duration == null) return 'Video';
    final hours = duration!.inHours;
    final minutes = duration!.inMinutes.remainder(60);
    final seconds = duration!.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String get formattedViews {
    if (viewCount <= 0) {
      return platform == VideoPlatform.tiktok ? 'TikTok Video' : 'YouTube Video';
    }
    if (viewCount >= 1000000) {
      return '${(viewCount / 1000000).toStringAsFixed(1)}M views';
    } else if (viewCount >= 1000) {
      return '${(viewCount / 1000).toStringAsFixed(1)}K views';
    }
    return '$viewCount views';
  }

  String get formattedLikes {
    if (likeCount <= 0) return '';
    if (likeCount >= 1000000) {
      return '${(likeCount / 1000000).toStringAsFixed(1)}M likes';
    } else if (likeCount >= 1000) {
      return '${(likeCount / 1000).toStringAsFixed(1)}K likes';
    }
    return '$likeCount likes';
  }
}

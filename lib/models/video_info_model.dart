import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'download_item.dart';

class StreamOption {
  final StreamInfo? streamInfo;
  final String label;
  final String container;
  final int sizeInBytes;
  final DownloadType type;
  final String resolutionOrBitrate;
  final String? directUrl;

  StreamOption({
    this.streamInfo,
    required this.label,
    required this.container,
    required this.sizeInBytes,
    required this.type,
    required this.resolutionOrBitrate,
    this.directUrl,
  });

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
  final Duration? duration;
  final String thumbnailUrl;
  final int viewCount;
  final DateTime? uploadDate;
  final String description;
  final List<StreamOption> muxedStreams; // Video + Audio (ready to play)
  final List<StreamOption> audioStreams; // Audio only (mp3/m4a/webm)
  final List<StreamOption> videoOnlyStreams; // High-res video only (1080p, 4k)

  ParsedVideoInfo({
    required this.id,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnailUrl,
    required this.viewCount,
    required this.uploadDate,
    required this.description,
    required this.muxedStreams,
    required this.audioStreams,
    required this.videoOnlyStreams,
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
    if (viewCount <= 0) return 'YouTube Video';
    if (viewCount >= 1000000) {
      return '${(viewCount / 1000000).toStringAsFixed(1)}M views';
    } else if (viewCount >= 1000) {
      return '${(viewCount / 1000).toStringAsFixed(1)}K views';
    }
    return '$viewCount views';
  }
}

enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

enum DownloadType {
  videoWithAudio,
  audioOnly,
  videoOnly,
}

class DownloadItem {
  final String id;
  final String videoId;
  final String title;
  final String author;
  final String thumbnailUrl;
  final String qualityLabel;
  final String fileExtension;
  final DownloadType type;
  final int totalBytes;
  int downloadedBytes;
  double speedBytesPerSec;
  DownloadStatus status;
  String? filePath;
  String? errorMessage;
  final DateTime createdAt;
  DateTime? completedAt;

  DownloadItem({
    required this.id,
    required this.videoId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.qualityLabel,
    required this.fileExtension,
    required this.type,
    required this.totalBytes,
    this.downloadedBytes = 0,
    this.speedBytesPerSec = 0.0,
    this.status = DownloadStatus.queued,
    this.filePath,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
  });

  double get progress {
    if (totalBytes <= 0) return 0.0;
    final p = downloadedBytes / totalBytes;
    return p.clamp(0.0, 1.0);
  }

  String get formattedProgressPercentage {
    return '${(progress * 100).toStringAsFixed(1)}%';
  }

  String get formattedDownloadedSize {
    return _formatBytes(downloadedBytes);
  }

  String get formattedTotalSize {
    return _formatBytes(totalBytes);
  }

  String get formattedSpeed {
    if (status != DownloadStatus.downloading || speedBytesPerSec <= 0) {
      return '--';
    }
    return '${_formatBytes(speedBytesPerSec.toInt())}/s';
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(size < 10 && i > 0 ? 1 : 0)} ${suffixes[i]}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'videoId': videoId,
      'title': title,
      'author': author,
      'thumbnailUrl': thumbnailUrl,
      'qualityLabel': qualityLabel,
      'fileExtension': fileExtension,
      'type': type.name,
      'totalBytes': totalBytes,
      'downloadedBytes': downloadedBytes,
      'status': status.name,
      'filePath': filePath,
      'errorMessage': errorMessage,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'] as String,
      videoId: json['videoId'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      qualityLabel: json['qualityLabel'] as String,
      fileExtension: json['fileExtension'] as String,
      type: DownloadType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => DownloadType.videoWithAudio,
      ),
      totalBytes: json['totalBytes'] as int? ?? 0,
      downloadedBytes: json['downloadedBytes'] as int? ?? 0,
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadStatus.completed,
      ),
      filePath: json['filePath'] as String?,
      errorMessage: json['errorMessage'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'])
          : null,
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/download_item.dart';
import '../models/video_info_model.dart';
import '../services/storage_service.dart';
import '../services/tiktok_service.dart';
import '../services/youtube_service.dart';
import '../services/facebook_service.dart';
import '../services/pinterest_service.dart';
import '../services/twitter_service.dart';

class DownloadProvider extends ChangeNotifier {
  final YoutubeService _youtubeService = YoutubeService();
  final TiktokService _tiktokService = TiktokService();
  final FacebookService _facebookService = FacebookService();
  final PinterestService _pinterestService = PinterestService();
  final TwitterService _twitterService = TwitterService();
  final StorageService _storageService = StorageService();
  final Uuid _uuid = const Uuid();

  // Search / Preview State
  bool _isLoadingVideo = false;
  ParsedVideoInfo? _currentVideo;
  String? _videoFetchError;

  // Active Downloads & History
  final Map<String, DownloadItem> _activeDownloads = {};
  final Map<String, DownloadCancelToken> _cancelTokens = {};
  List<DownloadItem> _completedDownloads = [];
  String _downloadDirectoryPath = '';

  // Getters
  bool get isLoadingVideo => _isLoadingVideo;
  ParsedVideoInfo? get currentVideo => _currentVideo;
  String? get videoFetchError => _videoFetchError;
  List<DownloadItem> get activeDownloads => _activeDownloads.values.toList();
  List<DownloadItem> get completedDownloads => _completedDownloads;
  String get downloadDirectoryPath => _downloadDirectoryPath;
  int get activeDownloadCount => _activeDownloads.length;

  DownloadProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    _downloadDirectoryPath = await _storageService.getDownloadsDirectoryPath();
    _completedDownloads = await _storageService.loadHistory();
    notifyListeners();
  }

  /// Auto-detect platform and fetch video info
  Future<bool> fetchVideoInfo(String urlOrId) async {
    final cleaned = YoutubeService.cleanInput(urlOrId);
    if (cleaned.isEmpty) {
      _videoFetchError =
          'Please enter a valid YouTube, TikTok, Facebook, Pinterest, or X link.';
      notifyListeners();
      return false;
    }

    _isLoadingVideo = true;
    _videoFetchError = null;
    _currentVideo = null;
    notifyListeners();

    try {
      ParsedVideoInfo info;

      if (FacebookService.isValidUrl(cleaned)) {
        info = await _facebookService.fetchVideoDetails(cleaned);
      } else if (PinterestService.isValidUrl(cleaned)) {
        info = await _pinterestService.fetchVideoDetails(cleaned);
      } else if (TwitterService.isValidUrl(cleaned)) {
        info = await _twitterService.fetchVideoDetails(cleaned);
      } else if (TiktokService.isValidUrl(cleaned)) {
        info = await _tiktokService.fetchVideoDetails(cleaned);
      } else {
        // Default: YouTube
        info = await _youtubeService.fetchVideoDetails(cleaned);
      }

      _currentVideo = info;
      _isLoadingVideo = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoadingVideo = false;
      _videoFetchError = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Clear the currently previewed video
  void clearCurrentVideo() {
    _currentVideo = null;
    _videoFetchError = null;
    notifyListeners();
  }

  /// Start downloading a selected stream
  Future<String> startDownload({
    required ParsedVideoInfo video,
    required StreamOption option,
  }) async {
    // Allow any container/type — no longer restricted to MP4-with-audio only
    try {
      await _storageService.requestStoragePermission();
    } catch (e) {
      debugPrint('Storage permission request: $e');
    }

    final downloadId = _uuid.v4();
    final ext = option.container.toLowerCase();
    final targetPath = await _storageService.getUniqueDestinationPath(
      video.title,
      ext,
    );

    final downloadItem = DownloadItem(
      id: downloadId,
      videoId: video.id,
      title: video.title,
      author: video.author,
      thumbnailUrl: video.thumbnailUrl,
      qualityLabel: option.label,
      fileExtension: ext,
      type: option.type,
      totalBytes: option.sizeInBytes,
      status: DownloadStatus.downloading,
      filePath: targetPath,
      createdAt: DateTime.now(),
    );

    final cancelToken = DownloadCancelToken();
    _activeDownloads[downloadId] = downloadItem;
    _cancelTokens[downloadId] = cancelToken;
    notifyListeners();

    _runDownloadTask(
      video: video,
      downloadItem: downloadItem,
      option: option,
      targetPath: targetPath,
      cancelToken: cancelToken,
    );

    return downloadId;
  }

  Future<void> _runDownloadTask({
    required ParsedVideoInfo video,
    required DownloadItem downloadItem,
    required StreamOption option,
    required String targetPath,
    required DownloadCancelToken cancelToken,
  }) async {
    try {
      void onProgress(int downloaded, int total, double speed) {
        downloadItem.downloadedBytes = downloaded;
        downloadItem.speedBytesPerSec = speed;
        notifyListeners();
      }

      switch (video.platform) {
        case VideoPlatform.tiktok:
          await _tiktokService.downloadStream(
            option: option,
            destinationPath: targetPath,
            cancelToken: cancelToken,
            onProgress: onProgress,
          );
        case VideoPlatform.facebook:
          await _facebookService.downloadStream(
            option: option,
            destinationPath: targetPath,
            cancelToken: cancelToken,
            onProgress: onProgress,
          );
        case VideoPlatform.pinterest:
          await _pinterestService.downloadStream(
            option: option,
            destinationPath: targetPath,
            cancelToken: cancelToken,
            onProgress: onProgress,
          );
        case VideoPlatform.x:
          await _twitterService.downloadStream(
            option: option,
            destinationPath: targetPath,
            cancelToken: cancelToken,
            onProgress: onProgress,
          );
        case VideoPlatform.youtube:
          await _youtubeService.downloadStream(
            option: option,
            destinationPath: targetPath,
            cancelToken: cancelToken,
            onProgress: onProgress,
          );
      }

      // Successfully finished
      downloadItem.status = DownloadStatus.completed;
      downloadItem.downloadedBytes = downloadItem.totalBytes > 0
          ? downloadItem.totalBytes
          : downloadItem.downloadedBytes;
      downloadItem.completedAt = DateTime.now();

      // Auto-save to device gallery
      if (targetPath.isNotEmpty) {
        try {
          final isVideo =
              downloadItem.fileExtension.toLowerCase() != 'mp3' &&
              downloadItem.fileExtension.toLowerCase() != 'm4a';
          await _storageService.saveToGallery(targetPath, isVideo: isVideo);
        } catch (e) {
          debugPrint('Automatic gallery save error: $e');
        }
      }

      _activeDownloads.remove(downloadItem.id);
      _cancelTokens.remove(downloadItem.id);
      _completedDownloads.insert(0, downloadItem);
      await _storageService.saveHistory(_completedDownloads);
      notifyListeners();
    } catch (e) {
      if (cancelToken.isCancelled) {
        downloadItem.status = DownloadStatus.cancelled;
        downloadItem.errorMessage = 'Download cancelled';
      } else {
        downloadItem.status = DownloadStatus.failed;
        downloadItem.errorMessage =
            e.toString().replaceFirst('Exception: ', '');
      }
      _activeDownloads.remove(downloadItem.id);
      _cancelTokens.remove(downloadItem.id);
      notifyListeners();
    }
  }

  /// Cancel an ongoing download
  void cancelDownload(String id) {
    if (_cancelTokens.containsKey(id)) {
      _cancelTokens[id]?.cancel();
      final item = _activeDownloads[id];
      if (item != null) {
        item.status = DownloadStatus.cancelled;
      }
      _activeDownloads.remove(id);
      _cancelTokens.remove(id);
      notifyListeners();
    }
  }

  /// Open/Play the downloaded video or audio file
  Future<void> openFile(DownloadItem item) async {
    if (item.filePath != null) {
      await _storageService.openFile(item.filePath!);
    }
  }

  /// Open device Gallery
  Future<void> openGallery() async {
    await _storageService.openGallery();
  }

  /// Manually save/export item to Gallery
  Future<bool> saveItemToGallery(DownloadItem item) async {
    if (item.filePath != null) {
      final isVideo = item.type != DownloadType.audioOnly;
      return await _storageService.saveToGallery(
        item.filePath!,
        isVideo: isVideo,
      );
    }
    return false;
  }

  /// Share the downloaded media file
  Future<void> shareFile(DownloadItem item) async {
    if (item.filePath != null) {
      await _storageService.shareFile(item.filePath!, item.title);
    }
  }

  /// Delete a record from history and optionally remove its file from disk
  Future<void> deleteHistoryItem(
    DownloadItem item, {
    bool deleteFileFromDisk = true,
  }) async {
    if (deleteFileFromDisk && item.filePath != null) {
      await _storageService.deleteFile(item.filePath!);
    }
    _completedDownloads.removeWhere((element) => element.id == item.id);
    await _storageService.saveHistory(_completedDownloads);
    notifyListeners();
  }

  /// Clear all completed history
  Future<void> clearAllHistory({bool deleteFilesFromDisk = false}) async {
    if (deleteFilesFromDisk) {
      for (final item in _completedDownloads) {
        if (item.filePath != null) {
          await _storageService.deleteFile(item.filePath!);
        }
      }
    }
    _completedDownloads.clear();
    await _storageService.saveHistory(_completedDownloads);
    notifyListeners();
  }

  @override
  void dispose() {
    _youtubeService.dispose();
    super.dispose();
  }
}

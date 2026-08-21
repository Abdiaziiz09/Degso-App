import 'dart:async';
import '../../models/download_item.dart';

class PlatformFileHelper {
  static final List<DownloadItem> _inMemoryWebHistory = [];

  static Future<bool> requestStoragePermission() async {
    return true;
  }

  static Future<String> getDownloadsDirectoryPath() async {
    return 'Browser Downloads Folder';
  }

  static Future<String> getUniqueDestinationPath(
      String dirPath, String cleanTitle, String extension) async {
    return '$cleanTitle.$extension';
  }

  static Future<bool> saveToGallery(String filePath, {bool isVideo = true}) async {
    return false;
  }

  static Future<void> openGallery() async {}

  static Future<void> saveHistoryToFile(
      String fileName, List<DownloadItem> history) async {
    _inMemoryWebHistory.clear();
    _inMemoryWebHistory.addAll(history);
  }

  static Future<List<DownloadItem>> loadHistoryFromFile(String fileName) async {
    return _inMemoryWebHistory;
  }

  static Future<bool> fileExists(String filePath) async {
    return false;
  }

  static Future<bool> deleteFile(String filePath) async {
    return true;
  }

  static Future<void> writeStreamToFile({
    required Stream<List<int>> byteStream,
    required String destinationPath,
    required int totalBytes,
    required void Function(int downloadedBytes, int totalBytes, double speedBytesPerSec) onProgress,
    required bool Function() isCancelled,
  }) async {
    onProgress(100, 100, 0);
  }
}

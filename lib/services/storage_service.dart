import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/download_item.dart';
import 'platform/file_saver.dart';

class StorageService {
  static const String _historyFileName = 'degso_download_history.json';

  /// Request required platform storage permissions
  Future<bool> requestStoragePermission() async {
    return await PlatformFileHelper.requestStoragePermission();
  }

  /// Get the standard target directory path for downloads
  Future<String> getDownloadsDirectoryPath() async {
    return await PlatformFileHelper.getDownloadsDirectoryPath();
  }

  /// Clean filename to remove prohibited characters across operating systems
  String sanitizeFileName(String name) {
    final invalidChars = RegExp(r'[\\/:*?"<>|\x00-\x1F]');
    var clean = name.replaceAll(invalidChars, '_').trim();
    if (clean.length > 100) {
      clean = clean.substring(0, 100).trim();
    }
    if (clean.isEmpty) {
      clean = 'download_${DateTime.now().millisecondsSinceEpoch}';
    }
    return clean;
  }

  /// Construct a unique destination file path
  Future<String> getUniqueDestinationPath(
      String title, String extension) async {
    final dirPath = await getDownloadsDirectoryPath();
    final cleanTitle = sanitizeFileName(title);
    return await PlatformFileHelper.getUniqueDestinationPath(
        dirPath, cleanTitle, extension);
  }

  /// Save video file directly to device's native Gallery
  Future<bool> saveToGallery(String filePath, {bool isVideo = true}) async {
    return await PlatformFileHelper.saveToGallery(filePath, isVideo: isVideo);
  }

  /// Open device's native Gallery app
  Future<void> openGallery() async {
    await PlatformFileHelper.openGallery();
  }

  /// Save download history list
  Future<void> saveHistory(List<DownloadItem> history) async {
    await PlatformFileHelper.saveHistoryToFile(_historyFileName, history);
  }

  /// Load download history list
  Future<List<DownloadItem>> loadHistory() async {
    return await PlatformFileHelper.loadHistoryFromFile(_historyFileName);
  }

  /// Open/Play the downloaded file in the platform's default player
  Future<OpenResult> openFile(String filePath) async {
    if (kIsWeb) {
      final uri = Uri.parse(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
      return OpenResult(type: ResultType.done);
    }
    return await OpenFilex.open(filePath);
  }

  /// Share file via platform share sheet
  Future<void> shareFile(String filePath, String title) async {
    if (kIsWeb) {
      // ignore: deprecated_member_use
      await Share.share('$title: $filePath');
      return;
    }

    if (await PlatformFileHelper.fileExists(filePath)) {
      final xFile = XFile(filePath);
      // ignore: deprecated_member_use
      await Share.shareXFiles([xFile], text: title);
    }
  }

  /// Delete a file from disk
  Future<bool> deleteFile(String filePath) async {
    return await PlatformFileHelper.deleteFile(filePath);
  }
}

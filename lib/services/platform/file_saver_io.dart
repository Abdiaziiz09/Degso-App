import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/download_item.dart';

class PlatformFileHelper {
  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final videoStatus = await Permission.videos.status;
      final audioStatus = await Permission.audio.status;

      if (!videoStatus.isGranted || !audioStatus.isGranted) {
        final statuses = await [
          Permission.videos,
          Permission.audio,
          Permission.storage,
        ].request();

        if (statuses[Permission.videos]?.isGranted == true ||
            statuses[Permission.storage]?.isGranted == true) {
          return true;
        }
      }

      final storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        final res = await Permission.storage.request();
        return res.isGranted;
      }
    }
    return true;
  }

  static Future<String> getDownloadsDirectoryPath() async {
    if (Platform.isAndroid) {
      final publicDownloads = Directory('/storage/emulated/0/Download');
      if (await publicDownloads.exists()) {
        final degsoDir = Directory(p.join(publicDownloads.path, 'Degso'));
        if (!await degsoDir.exists()) {
          await degsoDir.create(recursive: true);
        }
        return degsoDir.path;
      }

      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        return extDir.path;
      }
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        final degsoDir = Directory(p.join(downloads.path, 'Degso'));
        if (!await degsoDir.exists()) {
          await degsoDir.create(recursive: true);
        }
        return degsoDir.path;
      }
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final degsoDir = Directory(p.join(appDocDir.path, 'Degso'));
    if (!await degsoDir.exists()) {
      await degsoDir.create(recursive: true);
    }
    return degsoDir.path;
  }

  static Future<String> getUniqueDestinationPath(
      String dirPath, String cleanTitle, String extension) async {
    var targetPath = p.join(dirPath, '$cleanTitle.$extension');
    int count = 1;
    while (await File(targetPath).exists()) {
      targetPath = p.join(dirPath, '${cleanTitle}_$count.$extension');
      count++;
    }
    return targetPath;
  }

  static Future<void> saveHistoryToFile(
      String fileName, List<DownloadItem> history) async {
    final appDir = await getApplicationDocumentsDirectory();
    final historyFile = File(p.join(appDir.path, fileName));
    final jsonList = history.map((e) => e.toJson()).toList();
    await historyFile.writeAsString(jsonEncode(jsonList));
  }

  static Future<List<DownloadItem>> loadHistoryFromFile(String fileName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final historyFile = File(p.join(appDir.path, fileName));
    if (!await historyFile.exists()) {
      return [];
    }
    final contents = await historyFile.readAsString();
    final dynamic decoded = jsonDecode(contents);
    if (decoded is List) {
      return decoded
          .map((item) => DownloadItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  static Future<bool> fileExists(String filePath) async {
    return await File(filePath).exists();
  }

  static Future<bool> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }

  static Future<void> writeStreamToFile({
    required Stream<List<int>> byteStream,
    required String destinationPath,
    required int totalBytes,
    required void Function(int downloadedBytes, int totalBytes, double speedBytesPerSec) onProgress,
    required bool Function() isCancelled,
  }) async {
    final file = File(destinationPath);
    if (await file.exists()) {
      await file.delete();
    }

    final output = file.openWrite(mode: FileMode.writeOnly);
    int downloadedBytes = 0;
    int lastDownloadedBytes = 0;
    DateTime lastTime = DateTime.now();
    double currentSpeed = 0.0;

    final completer = Completer<void>();
    late StreamSubscription<List<int>> subscription;

    subscription = byteStream.listen(
      (data) {
        if (isCancelled()) {
          subscription.cancel();
          output.close().then((_) async {
            if (await file.exists()) {
              await file.delete();
            }
            if (!completer.isCompleted) {
              completer.completeError(Exception('Download was cancelled by user'));
            }
          });
          return;
        }

        output.add(data);
        downloadedBytes += data.length;

        final now = DateTime.now();
        final elapsed = now.difference(lastTime).inMilliseconds;
        if (elapsed >= 300) {
          final bytesDiff = downloadedBytes - lastDownloadedBytes;
          currentSpeed = (bytesDiff / (elapsed / 1000.0));
          lastDownloadedBytes = downloadedBytes;
          lastTime = now;
        }

        onProgress(downloadedBytes, totalBytes, currentSpeed);
      },
      onDone: () async {
        try {
          await output.flush();
          await output.close();
          if (!completer.isCompleted) {
            completer.complete();
          }
        } catch (e) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        }
      },
      onError: (error) async {
        await output.close();
        if (await file.exists()) {
          await file.delete();
        }
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      cancelOnError: true,
    );

    return completer.future;
  }
}

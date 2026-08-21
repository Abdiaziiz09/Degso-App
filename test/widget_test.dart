import 'package:flutter_test/flutter_test.dart';
import 'package:degso_app/models/download_item.dart';
import 'package:degso_app/services/storage_service.dart';
import 'package:degso_app/services/youtube_service.dart';

void main() {
  group('YouTube URL Parsing & Cleaning Tests', () {
    test('Validates and cleans standard watch URL', () {
      expect(
        YoutubeService.isValidUrl('https://www.youtube.com/watch?v=aqz-KE-bpKQ'),
        isTrue,
      );
      expect(
        YoutubeService.extractVideoId('https://www.youtube.com/watch?v=aqz-KE-bpKQ'),
        equals('aqz-KE-bpKQ'),
      );
    });

    test('Validates and cleans URL with quotes and spaces (from user screenshot)', () {
      expect(
        YoutubeService.isValidUrl("'www.youtube.com/watch?v=euWrpt7mvwY"),
        isTrue,
      );
      expect(
        YoutubeService.extractVideoId("'www.youtube.com/watch?v=euWrpt7mvwY"),
        equals('euWrpt7mvwY'),
      );
      expect(
        YoutubeService.extractVideoId('"https://youtu.be/euWrpt7mvwY"'),
        equals('euWrpt7mvwY'),
      );
    });

    test('Validates short URL (youtu.be)', () {
      expect(
        YoutubeService.isValidUrl('https://youtu.be/aqz-KE-bpKQ'),
        isTrue,
      );
      expect(
        YoutubeService.extractVideoId('https://youtu.be/aqz-KE-bpKQ'),
        equals('aqz-KE-bpKQ'),
      );
    });

    test('Validates shorts URL', () {
      expect(
        YoutubeService.isValidUrl('https://youtube.com/shorts/aqz-KE-bpKQ'),
        isTrue,
      );
      expect(
        YoutubeService.extractVideoId('https://youtube.com/shorts/aqz-KE-bpKQ'),
        equals('aqz-KE-bpKQ'),
      );
    });

    test('Validates raw 11-char video ID', () {
      expect(
        YoutubeService.isValidUrl('aqz-KE-bpKQ'),
        isTrue,
      );
      expect(
        YoutubeService.extractVideoId('aqz-KE-bpKQ'),
        equals('aqz-KE-bpKQ'),
      );
    });

    test('Rejects invalid URLs', () {
      expect(YoutubeService.isValidUrl('https://example.com/notyoutube'), isFalse);
      expect(YoutubeService.isValidUrl(''), isFalse);
      expect(YoutubeService.isValidUrl('123'), isFalse);
    });
  });

  group('StorageService Tests', () {
    test('Sanitizes illegal filename characters', () {
      final storage = StorageService();
      final sanitized = storage.sanitizeFileName('Video: Title / with * illegal? <chars>');
      expect(sanitized.contains(':'), isFalse);
      expect(sanitized.contains('/'), isFalse);
      expect(sanitized.contains('*'), isFalse);
      expect(sanitized.contains('?'), isFalse);
      expect(sanitized.contains('<'), isFalse);
      expect(sanitized.contains('>'), isFalse);
    });
  });

  group('DownloadItem Model Tests', () {
    test('JSON serialization & deserialization', () {
      final item = DownloadItem(
        id: 'test-123',
        videoId: 'aqz-KE-bpKQ',
        title: 'Test Video',
        author: 'Tester',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        qualityLabel: '720p',
        fileExtension: 'mp4',
        type: DownloadType.videoWithAudio,
        totalBytes: 10485760, // 10 MB
        downloadedBytes: 5242880, // 5 MB
        createdAt: DateTime.now(),
      );

      expect(item.progress, closeTo(0.5, 0.01));
      expect(item.formattedProgressPercentage, equals('50.0%'));
      expect(item.formattedTotalSize, equals('10 MB'));
      expect(item.formattedDownloadedSize, equals('5.0 MB'));

      final json = item.toJson();
      final fromJson = DownloadItem.fromJson(json);

      expect(fromJson.id, equals(item.id));
      expect(fromJson.videoId, equals(item.videoId));
      expect(fromJson.title, equals(item.title));
      expect(fromJson.totalBytes, equals(item.totalBytes));
      expect(fromJson.downloadedBytes, equals(item.downloadedBytes));
    });
  });
}

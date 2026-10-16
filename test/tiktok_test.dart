import 'package:degso_app/models/download_item.dart';
import 'package:degso_app/models/video_info_model.dart';
import 'package:degso_app/services/tiktok_service.dart';
import 'package:degso_app/services/youtube_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TikTok URL Parsing & Cleaning Tests', () {
    test('Validates standard web TikTok URL', () {
      const url = 'https://www.tiktok.com/@tiktok/video/7106594312292453678';
      expect(TiktokService.isValidUrl(url), isTrue);
      expect(YoutubeService.isValidUrl(url), isFalse);
    });

    test('Validates short mobile TikTok URLs (vm, vt, t)', () {
      expect(TiktokService.isValidUrl('https://vm.tiktok.com/ZMxxxxxx/'), isTrue);
      expect(TiktokService.isValidUrl('https://vt.tiktok.com/ZSxxxxxx/'), isTrue);
      expect(TiktokService.isValidUrl('https://www.tiktok.com/t/ZTxxxxxx/'), isTrue);
      expect(TiktokService.isValidUrl('https://m.tiktok.com/v/7106594312292453678.html'), isTrue);
    });

    test('Validates and cleans TikTok URL with quotes and whitespace', () {
      const quoted = " 'https://www.tiktok.com/@khaby.lame/video/6987654321' ";
      final cleaned = TiktokService.cleanInput(quoted);
      expect(cleaned, 'https://www.tiktok.com/@khaby.lame/video/6987654321');
      expect(TiktokService.isValidUrl(cleaned), isTrue);
    });

    test('Rejects non-TikTok URLs', () {
      expect(TiktokService.isValidUrl('https://www.google.com'), isFalse);
      expect(TiktokService.isValidUrl('https://www.youtube.com/watch?v=aqz-KE-bpKQ'), isFalse);
      expect(TiktokService.isValidUrl(''), isFalse);
    });
  });

  group('TikTok StreamOption & ParsedVideoInfo Model Tests', () {
    test('Creates No-Watermark StreamOption correctly', () {
      final option = StreamOption(
        label: 'No Watermark HD (MP4)',
        container: 'mp4',
        sizeInBytes: 15728640, // 15MB
        type: DownloadType.videoWithAudio,
        resolutionOrBitrate: 'HD 1080p',
        directUrl: 'https://tikwm.com/video/media.mp4',
        isNoWatermark: true,
      );

      expect(option.isNoWatermark, isTrue);
      expect(option.formattedSize, '15 MB');
      expect(option.container, 'mp4');
      expect(option.isMp4VideoWithAudio, isTrue);
    });

    test('Rejects audio-only and video-only download options', () {
      final audioOption = StreamOption(
        label: 'Audio only',
        container: 'mp3',
        sizeInBytes: 0,
        type: DownloadType.audioOnly,
        resolutionOrBitrate: '320 kbps',
      );
      final videoOnlyOption = StreamOption(
        label: 'Video only',
        container: 'mp4',
        sizeInBytes: 0,
        type: DownloadType.videoOnly,
        resolutionOrBitrate: '1080p',
      );
      final nonMp4VideoOption = StreamOption(
        label: 'WebM video with audio',
        container: 'webm',
        sizeInBytes: 0,
        type: DownloadType.videoWithAudio,
        resolutionOrBitrate: '720p',
      );

      expect(audioOption.isMp4VideoWithAudio, isFalse);
      expect(videoOnlyOption.isMp4VideoWithAudio, isFalse);
      expect(nonMp4VideoOption.isMp4VideoWithAudio, isFalse);
    });

    test('Creates TikTok ParsedVideoInfo with metrics correctly', () {
      final info = ParsedVideoInfo(
        id: '7106594312292453678',
        title: 'Hilarious comedy skit',
        author: 'Khaby Lame (@khaby.lame)',
        duration: const Duration(seconds: 45),
        thumbnailUrl: 'https://tikwm.com/cover.jpg',
        viewCount: 1500000,
        likeCount: 450000,
        uploadDate: null,
        description: 'Hilarious comedy skit',
        platform: VideoPlatform.tiktok,
        muxedStreams: [],
        watermarkedStreams: [],
      );

      expect(info.platform, VideoPlatform.tiktok);
      expect(info.formattedDuration, '0:45');
      expect(info.formattedViews, '1.5M views');
      expect(info.formattedLikes, '450.0K likes');
    });
  });
}

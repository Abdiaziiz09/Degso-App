import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/download_item.dart';
import '../models/video_info_model.dart';
import 'platform/file_saver.dart';

class DownloadCancelToken {
  bool isCancelled = false;
  void cancel() {
    isCancelled = true;
  }
}

class YoutubeService {
  final YoutubeExplode _yt = YoutubeExplode();

  /// Clean input by stripping quotes, whitespace, and brackets
  static String cleanInput(String input) {
    var text = input.trim();
    const stripChars = {"'", '"', '`', '<', '>', ' ', '\t', '\n', '\r'};
    while (text.isNotEmpty && stripChars.contains(text[0])) {
      text = text.substring(1).trim();
    }
    while (text.isNotEmpty && stripChars.contains(text[text.length - 1])) {
      text = text.substring(0, text.length - 1).trim();
    }
    return text;
  }

  /// Check if a string is a valid YouTube URL or Video ID
  static bool isValidUrl(String input) {
    final cleaned = cleanInput(input);
    if (cleaned.isEmpty) return false;

    // Direct 11-character video ID
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(cleaned)) {
      return true;
    }

    // Standard YouTube URL formats
    final ytRegex = RegExp(
      r'^(https?:\/\/)?(www\.|m\.)?(youtube\.com\/(watch\?v=|shorts\/|embed\/|v\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    );
    return ytRegex.hasMatch(cleaned);
  }

  /// Clean & extract video ID from input string
  static String? extractVideoId(String input) {
    final cleaned = cleanInput(input);
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(cleaned)) {
      return cleaned;
    }

    final ytRegex = RegExp(
      r'(?:https?:\/\/)?(?:www\.|m\.)?(?:youtube\.com\/(?:watch\?v=|shorts\/|embed\/|v\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    );
    final match = ytRegex.firstMatch(cleaned);
    return match?.group(1);
  }

  /// Fetch video metadata with automatic CORS-friendly web fallback
  Future<ParsedVideoInfo> fetchVideoDetails(String urlOrId) async {
    final videoIdStr = extractVideoId(urlOrId);
    if (videoIdStr == null) {
      throw Exception('Invalid YouTube URL or Video ID. Please check the link and try again.');
    }

    // On native desktop/mobile, try YoutubeExplode first for full stream manifest
    if (!kIsWeb) {
      try {
        final videoId = VideoId(videoIdStr);
        final video = await _yt.videos.get(videoId);
        final manifest = await _yt.videos.streamsClient.getManifest(videoId);

        final muxedOptions = <StreamOption>[];
        for (final stream in manifest.muxed
            .where((stream) => stream.container.name.toLowerCase() == 'mp4')
            .sortByVideoQuality()) {
          muxedOptions.add(StreamOption(
            streamInfo: stream,
            label: '${stream.qualityLabel} (MP4 • Video + Audio)',
            container: stream.container.name,
            sizeInBytes: stream.size.totalBytes,
            type: DownloadType.videoWithAudio,
            resolutionOrBitrate: stream.qualityLabel,
          ));
        }

        return ParsedVideoInfo(
          id: video.id.value,
          title: video.title,
          author: video.author,
          duration: video.duration,
          thumbnailUrl: video.thumbnails.highResUrl.isNotEmpty
              ? video.thumbnails.highResUrl
              : video.thumbnails.mediumResUrl,
          viewCount: video.engagement.viewCount,
          uploadDate: video.uploadDate,
          description: video.description,
          muxedStreams: muxedOptions,
        );
      } catch (e) {
        debugPrint('YoutubeExplode native resolution failed, falling back to oEmbed: $e');
      }
    }

    // Web-compatible resolution via official YouTube oEmbed API (CORS-enabled)
    return await _fetchViaOembed(videoIdStr);
  }

  /// Official CORS-friendly YouTube oEmbed resolver for Web and fallback
  Future<ParsedVideoInfo> _fetchViaOembed(String videoId) async {
    final oembedUrl =
        'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$videoId&format=json';

    final response = await http.get(Uri.parse(oembedUrl));
    if (response.statusCode != 200) {
      throw Exception(
        'Could not fetch video details from YouTube (HTTP ${response.statusCode}). The video may be private or unavailable.',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final title = data['title'] as String? ?? 'YouTube Video';
    final author = data['author_name'] as String? ?? 'YouTube Channel';
    final thumbnailUrl = (data['thumbnail_url'] as String?) ??
        'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

    // Generate stream presets with direct downloader services
    final muxedStreams = [
      StreamOption(
        label: '720p HD (MP4 Video with Audio)',
        container: 'mp4',
        sizeInBytes: 0,
        type: DownloadType.videoWithAudio,
        resolutionOrBitrate: '720p',
        directUrl: 'https://loader.to/api/button/?url=https://www.youtube.com/watch?v=$videoId&f=720',
      ),
      StreamOption(
        label: '360p Medium (MP4 Video with Audio)',
        container: 'mp4',
        sizeInBytes: 0,
        type: DownloadType.videoWithAudio,
        resolutionOrBitrate: '360p',
        directUrl: 'https://loader.to/api/button/?url=https://www.youtube.com/watch?v=$videoId&f=360',
      ),
    ];

    return ParsedVideoInfo(
      id: videoId,
      title: title,
      author: author,
      duration: null,
      thumbnailUrl: thumbnailUrl,
      viewCount: 0,
      uploadDate: null,
      description: '',
      muxedStreams: muxedStreams,
    );
  }

  /// Download a stream (handles both Native file stream and Web browser download)
  Future<void> downloadStream({
    required StreamOption option,
    required String destinationPath,
    required void Function(int downloadedBytes, int totalBytes, double speedBytesPerSec) onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    // If on Web or if streamInfo is null, trigger direct browser download via URL launcher
    if (kIsWeb || option.streamInfo == null) {
      final downloadUrl = option.directUrl ??
          'https://loader.to/api/button/?url=https://www.youtube.com/watch?v=${option.streamInfo?.tag ?? ""}&f=720';

      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      onProgress(100, 100, 0);
      return;
    }

    // Native file downloading via PlatformFileHelper
    final streamInfo = option.streamInfo!;
    final stream = _yt.videos.streamsClient.get(streamInfo);

    await PlatformFileHelper.writeStreamToFile(
      byteStream: stream,
      destinationPath: destinationPath,
      totalBytes: streamInfo.size.totalBytes,
      onProgress: onProgress,
      isCancelled: () => cancelToken?.isCancelled ?? false,
    );
  }

  void dispose() {
    _yt.close();
  }
}

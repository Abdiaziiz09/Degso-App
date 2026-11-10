import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/download_item.dart';
import '../models/video_info_model.dart';
import 'platform/file_saver.dart';
import 'youtube_service.dart' show DownloadCancelToken;

class TwitterService {
  static const _fxBase = 'https://api.fxtwitter.com';

  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'application/json,*/*',
  };

  /// Returns true if URL is from x.com or twitter.com
  static bool isValidUrl(String url) {
    return url.contains('x.com') || url.contains('twitter.com');
  }

  /// Fetch tweet metadata and video URL via FxTwitter API
  Future<ParsedVideoInfo> fetchVideoDetails(String url) async {
    if (!isValidUrl(url)) {
      throw Exception('Invalid X (Twitter) URL.');
    }

    // Parse: https://x.com/{user}/status/{id}
    final parts = _parseTweetUrl(url);
    if (parts == null) {
      throw Exception(
        'Could not parse tweet URL. '
        'Please paste a direct tweet link (e.g. https://x.com/user/status/12345).',
      );
    }

    final username = parts['user']!;
    final tweetId = parts['id']!;

    // Try FxTwitter
    Map<String, dynamic>? tweet;
    try {
      tweet = await _fetchFxTwitter(username, tweetId);
    } catch (e) {
      debugPrint('FxTwitter error: $e');
    }

    if (tweet == null) {
      throw Exception(
        'Could not load this tweet. It may be from a private account, '
        'deleted, or the API is temporarily unavailable.',
      );
    }

    // Extract fields
    final title = (tweet['text'] as String? ?? 'X Video').replaceAll('\n', ' ');
    final author = tweet['author']?['name'] as String? ??
        tweet['author']?['screen_name'] as String? ??
        username;
    final thumbnail = tweet['thumbnail_url'] as String? ??
        (tweet['media_extended'] as List?)
            ?.whereType<Map>()
            .firstWhere((m) => m['type'] == 'video', orElse: () => {})['thumbnail_url'] as String? ??
        '';

    // Video streams from media_extended
    final mediaList = (tweet['media_extended'] as List?)?.whereType<Map>() ?? [];
    final streams = <StreamOption>[];

    for (final media in mediaList) {
      if (media['type'] != 'video') continue;

      final mediaUrl = media['url'] as String? ?? media['media_url'] as String?;
      if (mediaUrl == null) continue;

      // Collect quality variants if available
      final variants = (media['variants'] as List?)?.whereType<Map>() ?? [];
      if (variants.isNotEmpty) {
        // Sort by bitrate descending
        final sorted = variants
            .where((v) => v['content_type'] == 'video/mp4' || (v['url'] as String? ?? '').contains('.mp4'))
            .toList()
          ..sort((a, b) =>
              ((b['bitrate'] as int?) ?? 0).compareTo((a['bitrate'] as int?) ?? 0));

        for (final v in sorted) {
          final vUrl = v['url'] as String?;
          if (vUrl == null) continue;
          final bitrate = (v['bitrate'] as int?) ?? 0;
          final kbps = bitrate > 0 ? '${(bitrate / 1000).round()} kbps' : 'Video';
          streams.add(StreamOption(
            label: '$kbps (MP4 · Video + Audio)',
            container: 'mp4',
            sizeInBytes: 0,
            type: DownloadType.videoWithAudio,
            resolutionOrBitrate: kbps,
            directUrl: vUrl,
          ));
        }
      } else {
        // Single URL
        streams.add(StreamOption(
          label: 'Video (MP4 · Video + Audio)',
          container: 'mp4',
          sizeInBytes: 0,
          type: DownloadType.videoWithAudio,
          resolutionOrBitrate: 'HD',
          directUrl: mediaUrl,
        ));
      }
      break; // only first video for now
    }

    // If media_extended had no usable streams, try top-level url
    if (streams.isEmpty) {
      final topUrl = tweet['media_url'] as String? ?? tweet['url'] as String?;
      if (topUrl != null && topUrl.contains('.mp4')) {
        streams.add(StreamOption(
          label: 'Video (MP4 · Video + Audio)',
          container: 'mp4',
          sizeInBytes: 0,
          type: DownloadType.videoWithAudio,
          resolutionOrBitrate: 'HD',
          directUrl: topUrl,
        ));
      }
    }

    if (streams.isEmpty) {
      throw Exception(
        'No video found in this tweet. Only tweets with video content can be downloaded.',
      );
    }

    return ParsedVideoInfo(
      id: tweetId,
      title: title,
      author: author,
      duration: null,
      thumbnailUrl: thumbnail,
      viewCount: 0,
      uploadDate: null,
      description: '',
      platform: VideoPlatform.x,
      muxedStreams: streams,
    );
  }

  /// Stream download for X/Twitter videos
  Future<void> downloadStream({
    required StreamOption option,
    required String destinationPath,
    required void Function(int downloaded, int total, double speed) onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    final url = option.directUrl;
    if (url == null || url.isEmpty) {
      throw Exception('No download URL available for this X video.');
    }

    final request = http.Request('GET', Uri.parse(url));
    request.headers.addAll(_headers);
    final streamedResponse = await request.send();

    if (streamedResponse.statusCode != 200) {
      throw Exception(
        'Failed to download X video (HTTP ${streamedResponse.statusCode}).',
      );
    }

    final totalBytes = streamedResponse.contentLength ?? 0;

    await PlatformFileHelper.writeStreamToFile(
      byteStream: streamedResponse.stream,
      destinationPath: destinationPath,
      totalBytes: totalBytes,
      onProgress: onProgress,
      isCancelled: () => cancelToken?.isCancelled ?? false,
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Call FxTwitter API: GET /user/status/id
  Future<Map<String, dynamic>?> _fetchFxTwitter(String user, String id) async {
    final uri = Uri.parse('$_fxBase/$user/status/$id');
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode != 200) {
      debugPrint('FxTwitter HTTP ${resp.statusCode}: ${resp.body}');
      return null;
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return body['tweet'] as Map<String, dynamic>?;
  }

  /// Parse https://x.com/{user}/status/{id} or https://twitter.com/{user}/status/{id}
  Map<String, String>? _parseTweetUrl(String url) {
    final re = RegExp(
      r'(?:twitter\.com|x\.com)/([^/?#]+)/status/(\d+)',
      caseSensitive: false,
    );
    final m = re.firstMatch(url);
    if (m == null) return null;
    return {'user': m.group(1)!, 'id': m.group(2)!};
  }
}

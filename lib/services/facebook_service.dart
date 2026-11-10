import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/download_item.dart';
import '../models/video_info_model.dart';
import 'platform/file_saver.dart';
import 'youtube_service.dart' show DownloadCancelToken;

class FacebookService {
  static const _headers = {
    // Facebook's own scraper UA bypasses the login wall for public content
    'User-Agent':
        'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  };

  /// Returns true if URL looks like a Facebook video URL
  static bool isValidUrl(String url) {
    return url.contains('facebook.com') ||
        url.contains('fb.watch') ||
        url.contains('fb.com');
  }

  /// Fetch video metadata and download options from a Facebook video URL
  Future<ParsedVideoInfo> fetchVideoDetails(String url) async {
    if (!isValidUrl(url)) {
      throw Exception('Invalid Facebook URL.');
    }

    // Resolve fb.watch short links to full URL
    String resolvedUrl = url;
    if (url.contains('fb.watch') || url.contains('fb.com/')) {
      try {
        final headResp = await http.get(Uri.parse(url), headers: _headers);
        if (headResp.request?.url != null) {
          resolvedUrl = headResp.request!.url.toString();
        }
      } catch (_) {}
    }

    final response = await http.get(Uri.parse(resolvedUrl), headers: _headers);
    if (response.statusCode != 200) {
      throw Exception(
        'Could not load Facebook page (HTTP ${response.statusCode}). '
        'Make sure the video is publicly visible.',
      );
    }

    final body = response.body;

    // Extract title from og:title or <title>
    String title = _extractMeta(body, 'og:title') ??
        _extractTagContent(body, 'title') ??
        'Facebook Video';

    // Extract thumbnail from og:image
    final thumbnail = _extractMeta(body, 'og:image') ?? '';

    // Extract HD URL candidates
    final hdUrl = _extractVideoUrl(body, [
      'browser_native_hd_url',
      'hd_src',
      '"hd_src_no_ratelimit"',
    ]);

    // Extract SD URL candidates
    final sdUrl = _extractVideoUrl(body, [
      'browser_native_sd_url',
      'sd_src',
      '"sd_src_no_ratelimit"',
    ]);

    if (hdUrl == null && sdUrl == null) {
      throw Exception(
        'Could not find download links for this Facebook video. '
        'Make sure the video is public and try again.',
      );
    }

    final streams = <StreamOption>[];
    if (hdUrl != null) {
      streams.add(StreamOption(
        label: 'HD Video (MP4 · Video + Audio)',
        container: 'mp4',
        sizeInBytes: 0,
        type: DownloadType.videoWithAudio,
        resolutionOrBitrate: 'HD',
        directUrl: hdUrl,
      ));
    }
    if (sdUrl != null) {
      streams.add(StreamOption(
        label: 'SD Video (MP4 · Video + Audio)',
        container: 'mp4',
        sizeInBytes: 0,
        type: DownloadType.videoWithAudio,
        resolutionOrBitrate: 'SD',
        directUrl: sdUrl,
      ));
    }

    // Try to get video ID from URL
    final videoId = _extractVideoId(resolvedUrl) ?? resolvedUrl.hashCode.toString();

    return ParsedVideoInfo(
      id: videoId,
      title: title,
      author: 'Facebook',
      duration: null,
      thumbnailUrl: thumbnail,
      viewCount: 0,
      uploadDate: null,
      description: '',
      platform: VideoPlatform.facebook,
      muxedStreams: streams,
    );
  }

  /// Stream download for Facebook videos (direct MP4 URL)
  Future<void> downloadStream({
    required StreamOption option,
    required String destinationPath,
    required void Function(int downloaded, int total, double speed) onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    final url = option.directUrl;
    if (url == null || url.isEmpty) {
      throw Exception('No download URL available for this Facebook video.');
    }

    final request = http.Request('GET', Uri.parse(url));
    request.headers.addAll(_headers);
    final streamedResponse = await request.send();

    if (streamedResponse.statusCode != 200) {
      throw Exception(
        'Failed to download Facebook video (HTTP ${streamedResponse.statusCode}).',
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

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Extract content="" from a <meta property="…"> or <meta name="…"> tag
  String? _extractMeta(String html, String property) {
    final patterns = [
      RegExp('property=["\']${RegExp.escape(property)}["\'][^>]*content=["\'](.*?)["\']',
          dotAll: true),
      RegExp('content=["\'](.*?)["\'][^>]*property=["\']${RegExp.escape(property)}["\']',
          dotAll: true),
      RegExp('name=["\']${RegExp.escape(property)}["\'][^>]*content=["\'](.*?)["\']',
          dotAll: true),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(html);
      if (m != null) return _unescape(m.group(1)!);
    }
    return null;
  }

  /// Extract text between a tag and its closing tag.
  String? _extractTagContent(String html, String tag) {
    final re = RegExp('<$tag[^>]*>(.*?)</$tag>', dotAll: true, caseSensitive: false);
    final m = re.firstMatch(html);
    return m != null ? _unescape(m.group(1)!.trim()) : null;
  }

  /// Try to find a video download URL from a list of JSON key names
  String? _extractVideoUrl(String html, List<String> keys) {
    for (final key in keys) {
      // Match: "key":"url" or "key": "url"
      final re = RegExp(
        '"${RegExp.escape(key.replaceAll('"', ''))}"\\s*:\\s*"(https?[^"]+)"',
      );
      final m = re.firstMatch(html);
      if (m != null) {
        final raw = m.group(1)!;
        if (raw.isNotEmpty && raw.contains('.mp4')) {
          return _unescape(raw);
        }
      }
    }
    return null;
  }

  /// Extract numeric Facebook video ID from URL
  String? _extractVideoId(String url) {
    final re = RegExp(r'(?:videos?|reel|v)[\\/](\d{10,})');
    return re.firstMatch(url)?.group(1);
  }

  /// Unescape JSON-encoded characters (\/, \u0026, etc.)
  String _unescape(String s) {
    try {
      // JSON-decode surrounds with quotes so we can reuse dart:convert
      return jsonDecode('"${s.replaceAll('"', '\\"')}"') as String;
    } catch (_) {
      return s
          .replaceAll(r'\/', '/')
          .replaceAll(r'\u0026', '&')
          .replaceAll(r'\u003d', '=')
          .replaceAll(r'\u003c', '<')
          .replaceAll(r'\u003e', '>');
    }
  }
}

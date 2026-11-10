import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/download_item.dart';
import '../models/video_info_model.dart';
import 'platform/file_saver.dart';
import 'youtube_service.dart' show DownloadCancelToken;

class PinterestService {
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  };

  static bool isValidUrl(String url) {
    return url.contains('pinterest.com') ||
        url.contains('pinterest.co') ||
        url.contains('pin.it');
  }

  /// Fetch Pinterest pin metadata and direct MP4 URL
  Future<ParsedVideoInfo> fetchVideoDetails(String url) async {
    if (!isValidUrl(url)) {
      throw Exception('Invalid Pinterest URL.');
    }

    // Resolve pin.it short links via Location header
    String resolvedUrl = url;
    if (url.contains('pin.it')) {
      try {
        // Follow redirect manually to capture final URL
        final client = http.Client();
        var currentUrl = url;
        for (int i = 0; i < 8; i++) {
          final req = http.Request('GET', Uri.parse(currentUrl))
            ..followRedirects = false
            ..headers.addAll(_headers);
          final resp = await client.send(req);
          if (resp.isRedirect) {
            final location = resp.headers['location'];
            if (location == null) break;
            currentUrl = location.startsWith('http')
                ? location
                : Uri.parse(currentUrl).resolve(location).toString();
          } else {
            resolvedUrl = currentUrl;
            break;
          }
        }
        client.close();
      } catch (e) {
        debugPrint('Pinterest redirect resolve error: $e');
      }
    }

    final response = await http.get(Uri.parse(resolvedUrl), headers: _headers);
    if (response.statusCode != 200) {
      throw Exception(
        'Could not load Pinterest page (HTTP ${response.statusCode}).',
      );
    }

    final body = response.body;

    // Extract title — Pinterest is a React SPA, title is inside <title> at
    // the end of <head>, but NOT in og:title (og:title has the author URL).
    // We read the LAST <title> match and clean it.
    final title = _extractTitle(body) ?? 'Pinterest Video';

    // Thumbnail from og:image
    final thumbnail = _extractPinimgThumbnail(body) ??
        _extractMeta(body, 'og:image') ??
        '';

    // Extract all direct MP4 URLs (expMp4 paths — highest quality first)
    final streams = _extractMp4Streams(body);

    if (streams.isEmpty) {
      throw Exception(
        'Could not find a video on this Pinterest pin. '
        'Make sure the pin contains a video and is publicly accessible.',
      );
    }

    final pinId = _extractPinId(resolvedUrl) ?? resolvedUrl.hashCode.toString();

    return ParsedVideoInfo(
      id: pinId,
      title: title,
      author: 'Pinterest',
      duration: null,
      thumbnailUrl: thumbnail,
      viewCount: 0,
      uploadDate: null,
      description: '',
      platform: VideoPlatform.pinterest,
      muxedStreams: streams,
    );
  }

  /// Stream download for Pinterest videos (direct MP4 URL)
  Future<void> downloadStream({
    required StreamOption option,
    required String destinationPath,
    required void Function(int downloaded, int total, double speed) onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    final url = option.directUrl;
    if (url == null || url.isEmpty) {
      throw Exception('No download URL available for this Pinterest video.');
    }

    final request = http.Request('GET', Uri.parse(url));
    request.headers.addAll(_headers);
    final streamedResponse = await request.send();

    if (streamedResponse.statusCode != 200) {
      throw Exception(
        'Failed to download Pinterest video (HTTP ${streamedResponse.statusCode}).',
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

  /// Extract all direct MP4 stream options from Pinterest's embedded JSON.
  /// Pinterest stores videos under "video_list" with keys like V_720p, V_480p.
  /// They also expose expMp4 paths: .../expMp4/xx/xx/xx/HASH_720w.mp4
  List<StreamOption> _extractMp4Streams(String html) {
    final streams = <StreamOption>[];
    final seen = <String>{};

    // Pattern: https://v1.pinimg.com/.../expMp4/.../HASH_NNNw.mp4
    // Avoid \s inside regex — use explicit character class instead
    final expMp4Re = RegExp(
      'https://v[0-9]+\\.pinimg\\.com/[^"\'\\t\\n\\r ]+expMp4[^"\'\\t\\n\\r ]+\\.mp4',
    );
    for (final m in expMp4Re.allMatches(html)) {
      final rawUrl = m.group(0)!;
      final cleanedUrl = _cleanUrl(rawUrl);
      if (seen.contains(cleanedUrl)) continue;
      seen.add(cleanedUrl);

      // Try to get resolution from filename like _720w.mp4
      final resMatch = RegExp(r'_(\d+)w\.mp4').firstMatch(cleanedUrl);
      final res = resMatch != null ? '${resMatch.group(1)}p' : 'Video';

      streams.add(StreamOption(
        label: '$res (MP4 · Video + Audio)',
        container: 'mp4',
        sizeInBytes: 0,
        type: DownloadType.videoWithAudio,
        resolutionOrBitrate: res,
        directUrl: cleanedUrl,
      ));
    }

    // Sort highest resolution first
    streams.sort((a, b) {
      final aRes = int.tryParse(a.resolutionOrBitrate.replaceAll('p', '')) ?? 0;
      final bRes = int.tryParse(b.resolutionOrBitrate.replaceAll('p', '')) ?? 0;
      return bRes.compareTo(aRes);
    });

    return streams;
  }

  /// Extract clean title — Pinterest SPA puts a good title in the title tag.
  /// We take the LAST non-empty title content found (after the head).
  String? _extractTitle(String html) {
    final re = RegExp('<title[^>]*>([^<]{5,})</title>', caseSensitive: false);
    final matches = re.allMatches(html).toList();
    if (matches.isEmpty) return null;
    // Last match is usually the meaningful pin title
    for (final m in matches.reversed) {
      final t = m.group(1)!.trim();
      if (t.isNotEmpty && !t.contains('width=') && !t.contains('viewport')) {
        return t.length > 120 ? '${t.substring(0, 117)}...' : t;
      }
    }
    return null;
  }

  /// Extract thumbnail from pinimg.com (prefer high-res originals)
  String? _extractPinimgThumbnail(String html) {
    // originals thumbnail is best quality
    final re = RegExp(
      'https://i\\.pinimg\\.com/originals/[^"\'\\t\\n\\r ]+\\.(jpg|jpeg|png|webp)',
      caseSensitive: false,
    );
    return re.firstMatch(html)?.group(0);
  }

  String? _extractMeta(String html, String property) {
    final patterns = [
      RegExp(
          'property=["\']${RegExp.escape(property)}["\'][^>]*content=["\']([^"\']+)["\']'),
      RegExp(
          'content=["\']([^"\']+)["\'][^>]*property=["\']${RegExp.escape(property)}["\']'),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(html);
      if (m != null) return m.group(1)!.trim();
    }
    return null;
  }

  String? _extractPinId(String url) {
    final re = RegExp(r'/pin/(\d+)');
    return re.firstMatch(url)?.group(1);
  }

  String _cleanUrl(String url) =>
      url.replaceAll('&amp;', '&').replaceAll(r'\/', '/').trim();
}

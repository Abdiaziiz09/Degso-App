import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/download_item.dart';
import '../models/video_info_model.dart';
import 'platform/file_saver.dart';
import 'youtube_service.dart';

class TiktokService {
  static const String _tikwmEndpoint = 'https://www.tikwm.com/api/';
  static const String _tiklydownEndpoint = 'https://api.tiklydown.eu.org/api/download';

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

  /// Check if a string is a valid TikTok URL
  static bool isValidUrl(String input) {
    final cleaned = cleanInput(input);
    if (cleaned.isEmpty) return false;

    final tiktokRegex = RegExp(
      r'^(https?:\/\/)?((www|m|vm|vt|t)\.)?tiktok\.com\/',
      caseSensitive: false,
    );
    return tiktokRegex.hasMatch(cleaned) || cleaned.contains('tiktok.com');
  }

  /// Fetch full video metadata and download options for TikTok
  Future<ParsedVideoInfo> fetchVideoDetails(String url) async {
    final cleanedUrl = cleanInput(url);
    if (!isValidUrl(cleanedUrl)) {
      throw Exception('Invalid TikTok URL. Please provide a valid link from TikTok.');
    }

    // Try primary resolver (TikWM)
    try {
      final info = await _fetchViaTikwm(cleanedUrl);
      if (info != null) return info;
    } catch (e) {
      debugPrint('TikWM fetch error: $e');
    }

    // Try secondary resolver (Tiklydown)
    try {
      final info = await _fetchViaTiklydown(cleanedUrl);
      if (info != null) return info;
    } catch (e) {
      debugPrint('Tiklydown fetch error: $e');
    }

    throw Exception('Could not fetch TikTok video details. Please ensure the video is public and try again.');
  }

  Future<ParsedVideoInfo?> _fetchViaTikwm(String url) async {
    final uri = Uri.parse('$_tikwmEndpoint?url=${Uri.encodeComponent(url)}&hd=1');
    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['code'] != 0 || json['data'] == null) {
      return null;
    }

    final data = json['data'] as Map<String, dynamic>;
    final id = data['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    final title = (data['title'] as String?)?.trim();
    final cleanTitle = (title != null && title.isNotEmpty) ? title : 'TikTok Video ($id)';

    final authorData = data['author'] as Map<String, dynamic>?;
    final authorNickname = authorData?['nickname'] as String? ?? 'TikTok Creator';
    final authorUsername = authorData?['unique_id'] as String? ?? '';
    final authorFull = authorUsername.isNotEmpty
        ? '$authorNickname (@$authorUsername)'
        : authorNickname;
    final authorAvatar = authorData?['avatar'] as String?;

    final cover = (data['cover'] as String?) ?? (data['origin_cover'] as String?) ?? '';
    final durationSec = data['duration'] as int? ?? 0;
    final playCount = data['play_count'] as int? ?? 0;
    final diggCount = data['digg_count'] as int? ?? 0;

    final noWatermarkPlay = data['play'] as String?;
    final hdPlay = data['hdplay'] as String?;
    final wmPlay = data['wmplay'] as String?;
    final musicUrl = data['music'] as String?;
    final musicInfo = data['music_info'] as Map<String, dynamic>?;
    final musicTitle = musicInfo?['title'] as String? ?? 'Original Sound';

    final size = data['size'] as int? ?? 0;
    final hdSize = data['hd_size'] as int? ?? 0;

    final muxedStreams = <StreamOption>[];
    if (hdPlay != null && hdPlay.isNotEmpty) {
      muxedStreams.add(StreamOption(
        label: 'No Watermark HD (MP4)',
        container: 'mp4',
        sizeInBytes: hdSize > 0 ? hdSize : size,
        type: DownloadType.videoWithAudio,
        resolutionOrBitrate: 'HD 1080p',
        directUrl: hdPlay.startsWith('http') ? hdPlay : 'https://www.tikwm.com$hdPlay',
        isNoWatermark: true,
      ));
    }

    if (noWatermarkPlay != null && noWatermarkPlay.isNotEmpty) {
      muxedStreams.add(StreamOption(
        label: 'No Watermark Standard (MP4)',
        container: 'mp4',
        sizeInBytes: size,
        type: DownloadType.videoWithAudio,
        resolutionOrBitrate: '720p',
        directUrl: noWatermarkPlay.startsWith('http')
            ? noWatermarkPlay
            : 'https://www.tikwm.com$noWatermarkPlay',
        isNoWatermark: true,
      ));
    }

    final audioStreams = <StreamOption>[];
    if (musicUrl != null && musicUrl.isNotEmpty) {
      audioStreams.add(StreamOption(
        label: '$musicTitle (MP3 Audio)',
        container: 'mp3',
        sizeInBytes: 0,
        type: DownloadType.audioOnly,
        resolutionOrBitrate: '320 kbps',
        directUrl: musicUrl.startsWith('http') ? musicUrl : 'https://www.tikwm.com$musicUrl',
      ));
    }

    final videoOnlyStreams = <StreamOption>[];
    if (wmPlay != null && wmPlay.isNotEmpty) {
      videoOnlyStreams.add(StreamOption(
        label: 'Original with Watermark (MP4)',
        container: 'mp4',
        sizeInBytes: size,
        type: DownloadType.videoWithAudio,
        resolutionOrBitrate: 'Watermark',
        directUrl: wmPlay.startsWith('http') ? wmPlay : 'https://www.tikwm.com$wmPlay',
        isNoWatermark: false,
      ));
    }

    return ParsedVideoInfo(
      id: id,
      title: cleanTitle,
      author: authorFull,
      authorAvatarUrl: authorAvatar,
      duration: Duration(seconds: durationSec),
      thumbnailUrl: cover.startsWith('http') ? cover : 'https://www.tikwm.com$cover',
      viewCount: playCount,
      likeCount: diggCount,
      uploadDate: null,
      description: cleanTitle,
      platform: VideoPlatform.tiktok,
      muxedStreams: muxedStreams,
      audioStreams: audioStreams,
      videoOnlyStreams: videoOnlyStreams,
    );
  }

  Future<ParsedVideoInfo?> _fetchViaTiklydown(String url) async {
    final uri = Uri.parse('$_tiklydownEndpoint?url=${Uri.encodeComponent(url)}');
    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final id = json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    final title = (json['title'] as String?)?.trim() ?? 'TikTok Video ($id)';

    final authorData = json['author'] as Map<String, dynamic>?;
    final authorNickname = authorData?['name'] as String? ?? 'TikTok Creator';
    final authorUsername = authorData?['unique_id'] as String? ?? '';
    final authorFull = authorUsername.isNotEmpty
        ? '$authorNickname (@$authorUsername)'
        : authorNickname;
    final authorAvatar = authorData?['avatar'] as String?;

    final cover = (json['cover'] as String?) ?? '';
    final videoData = json['video'] as Map<String, dynamic>?;
    final noWatermark = videoData?['noWatermark'] as String?;
    final watermark = videoData?['watermark'] as String?;

    final musicData = json['music'] as Map<String, dynamic>?;
    final musicPlayUrl = musicData?['play_url'] as String?;
    final musicTitle = musicData?['title'] as String? ?? 'Original Sound';

    final muxedStreams = <StreamOption>[];
    if (noWatermark != null && noWatermark.isNotEmpty) {
      muxedStreams.add(StreamOption(
        label: 'No Watermark HD (MP4)',
        container: 'mp4',
        sizeInBytes: 0,
        type: DownloadType.videoWithAudio,
        resolutionOrBitrate: 'No Watermark',
        directUrl: noWatermark,
        isNoWatermark: true,
      ));
    }

    final audioStreams = <StreamOption>[];
    if (musicPlayUrl != null && musicPlayUrl.isNotEmpty) {
      audioStreams.add(StreamOption(
        label: '$musicTitle (MP3 Audio)',
        container: 'mp3',
        sizeInBytes: 0,
        type: DownloadType.audioOnly,
        resolutionOrBitrate: '320 kbps',
        directUrl: musicPlayUrl,
      ));
    }

    final videoOnlyStreams = <StreamOption>[];
    if (watermark != null && watermark.isNotEmpty) {
      videoOnlyStreams.add(StreamOption(
        label: 'With Watermark (MP4)',
        container: 'mp4',
        sizeInBytes: 0,
        type: DownloadType.videoWithAudio,
        resolutionOrBitrate: 'Watermark',
        directUrl: watermark,
      ));
    }

    return ParsedVideoInfo(
      id: id,
      title: title,
      author: authorFull,
      authorAvatarUrl: authorAvatar,
      duration: null,
      thumbnailUrl: cover,
      viewCount: 0,
      likeCount: 0,
      uploadDate: null,
      description: title,
      platform: VideoPlatform.tiktok,
      muxedStreams: muxedStreams,
      audioStreams: audioStreams,
      videoOnlyStreams: videoOnlyStreams,
    );
  }

  /// Download a TikTok stream to disk with live progress and cancel support
  Future<void> downloadStream({
    required StreamOption option,
    required String destinationPath,
    required void Function(int downloadedBytes, int totalBytes, double speedBytesPerSec) onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    final directUrl = option.directUrl;
    if (directUrl == null || directUrl.isEmpty) {
      throw Exception('Download stream URL not found for this option.');
    }

    final request = http.Request('GET', Uri.parse(directUrl));
    request.headers.addAll({
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': 'https://www.tiktok.com/',
    });

    final client = http.Client();
    final response = await client.send(request);

    if (response.statusCode != 200 && response.statusCode != 206) {
      client.close();
      throw Exception('TikTok server returned HTTP ${response.statusCode}');
    }

    final totalBytes = response.contentLength ?? option.sizeInBytes;

    await PlatformFileHelper.writeStreamToFile(
      byteStream: response.stream,
      destinationPath: destinationPath,
      totalBytes: totalBytes,
      onProgress: onProgress,
      isCancelled: () {
        if (cancelToken?.isCancelled == true) {
          client.close();
          return true;
        }
        return false;
      },
    );

    client.close();
  }
}

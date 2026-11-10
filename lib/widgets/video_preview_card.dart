import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/video_info_model.dart';
import '../theme/app_theme.dart';

class VideoPreviewCard extends StatelessWidget {
  final ParsedVideoInfo video;
  final VoidCallback onDownloadPressed;

  const VideoPreviewCard({
    super.key,
    required this.video,
    required this.onDownloadPressed,
  });

  /// Returns the brand colour for each platform
  Color _platformColor() {
    switch (video.platform) {
      case VideoPlatform.tiktok:
        return const Color(0xFFFE2C55);
      case VideoPlatform.facebook:
        return const Color(0xFF1877F2);
      case VideoPlatform.pinterest:
        return const Color(0xFFE60023);
      case VideoPlatform.x:
        return Colors.black87;
      case VideoPlatform.youtube:
        return AppTheme.primaryRed;
    }
  }

  /// Returns the icon for each platform
  IconData _platformIcon() {
    switch (video.platform) {
      case VideoPlatform.tiktok:
        return Icons.music_note_rounded;
      case VideoPlatform.facebook:
        return Icons.facebook_rounded;
      case VideoPlatform.pinterest:
        return Icons.push_pin_rounded;
      case VideoPlatform.x:
        return Icons.alternate_email_rounded;
      case VideoPlatform.youtube:
        return Icons.play_arrow_rounded;
    }
  }

  /// Badge label — TikTok shows "No-Watermark" extra text
  String _platformBadgeLabel() {
    if (video.platform == VideoPlatform.tiktok) return 'TikTok (No-Watermark)';
    return video.platformLabel;
  }

  /// Download button label
  String _downloadButtonLabel() {
    switch (video.platform) {
      case VideoPlatform.tiktok:
        return 'Download No-Watermark MP4';
      case VideoPlatform.youtube:
        return 'Select MP4 Quality';
      default:
        return 'Select Download Quality';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _platformColor();
    final isTiktok = video.platform == VideoPlatform.tiktok;
    final dateStr = video.uploadDate != null
        ? DateFormat.yMMMd().format(video.uploadDate!)
        : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Thumbnail with badges overlay ──────────────────────────────
          Stack(
            children: [
              AspectRatio(
                aspectRatio: isTiktok ? (4 / 3) : (16 / 9),
                child: video.thumbnailUrl.isNotEmpty
                    ? Image.network(
                        video.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, e, __) => _thumbFallback(),
                        loadingBuilder: (_, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _thumbLoading();
                        },
                      )
                    : _thumbFallback(),
              ),

              // Platform badge — top-left
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_platformIcon(), color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _platformBadgeLabel(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Duration badge — bottom-right
              if (video.duration != null && video.duration!.inSeconds > 0)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      video.formattedDuration,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // ── Info section ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title / Caption
                Text(
                  video.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Author row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: accent,
                      backgroundImage: video.authorAvatarUrl != null &&
                              video.authorAvatarUrl!.isNotEmpty
                          ? NetworkImage(video.authorAvatarUrl!)
                          : null,
                      child: (video.authorAvatarUrl == null ||
                              video.authorAvatarUrl!.isEmpty)
                          ? Icon(_platformIcon(), size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        video.author,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Views & date row
                Row(
                  children: [
                    Text(
                      video.formattedViews,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.7),
                      ),
                    ),
                    if (video.formattedLikes.isNotEmpty) ...[
                      const Text(' • '),
                      Text(
                        video.formattedLikes,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (dateStr != null) ...[
                      const Text(' • '),
                      Text(
                        dateStr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                // Download button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onDownloadPressed,
                    icon: const Icon(Icons.download_rounded),
                    label: Text(_downloadButtonLabel()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbFallback() => Container(
        color: Colors.grey.shade900,
        child: const Center(
          child: Icon(Icons.broken_image, size: 48, color: Colors.white54),
        ),
      );

  Widget _thumbLoading() => Container(
        color: Colors.grey.shade900,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
}

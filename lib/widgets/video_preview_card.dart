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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
          // Thumbnail with duration & platform overlay
          Stack(
            children: [
              AspectRatio(
                aspectRatio: isTiktok ? (4 / 3) : (16 / 9),
                child: Image.network(
                  video.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey.shade900,
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 48, color: Colors.white54),
                    ),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey.shade900,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                ),
              ),

              // Platform Badge (YouTube vs TikTok No-Watermark)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isTiktok ? Colors.black87 : AppTheme.primaryRed,
                    borderRadius: BorderRadius.circular(8),
                    border: isTiktok
                        ? Border.all(color: Colors.cyanAccent.withValues(alpha: 0.8), width: 1.2)
                        : null,
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
                      Icon(
                        isTiktok ? Icons.music_note_rounded : Icons.play_arrow_rounded,
                        color: isTiktok ? Colors.cyanAccent : Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isTiktok ? 'TikTok (No-Watermark)' : 'YouTube',
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

              // Duration Badge
              if (video.duration != null && video.duration!.inSeconds > 0)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

                // Channel / Author row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: isTiktok ? Colors.black : AppTheme.primaryRed,
                      backgroundImage: video.authorAvatarUrl != null &&
                              video.authorAvatarUrl!.isNotEmpty
                          ? NetworkImage(video.authorAvatarUrl!)
                          : null,
                      child: (video.authorAvatarUrl == null || video.authorAvatarUrl!.isEmpty)
                          ? Icon(
                              isTiktok ? Icons.person : Icons.play_arrow,
                              size: 14,
                              color: Colors.white,
                            )
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

                // Views & Likes row
                Row(
                  children: [
                    Text(
                      video.formattedViews,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                    if (video.formattedLikes.isNotEmpty) ...[
                      const Text(' • '),
                      Text(
                        video.formattedLikes,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isTiktok ? Colors.pinkAccent : null,
                          fontWeight: isTiktok ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                    if (dateStr != null) ...[
                      const Text(' • '),
                      Text(
                        dateStr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                // Download Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onDownloadPressed,
                    icon: const Icon(Icons.download_rounded),
                    label: Text(
                      isTiktok
                          ? 'Download No-Watermark Video / Audio'
                          : 'Select Format & Download',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isTiktok ? const Color(0xFFFE2C55) : AppTheme.primaryRed,
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
}

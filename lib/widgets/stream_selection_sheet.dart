import 'package:flutter/material.dart';
import '../models/video_info_model.dart';
import '../theme/app_theme.dart';

class StreamSelectionSheet extends StatelessWidget {
  final ParsedVideoInfo video;
  final void Function(StreamOption option) onOptionSelected;

  const StreamSelectionSheet({
    super.key,
    required this.video,
    required this.onOptionSelected,
  });

  static void show(
    BuildContext context, {
    required ParsedVideoInfo video,
    required void Function(StreamOption option) onOptionSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StreamSelectionSheet(
        video: video,
        onOptionSelected: onOptionSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top Drag Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade500.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Header with short title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      video.thumbnailUrl,
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 54,
                        height: 54,
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.movie, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Choose format & quality',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: AppTheme.primaryRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.videocam_rounded, size: 18),
                    text: 'Video (Audio)',
                  ),
                  Tab(
                    icon: Icon(Icons.music_note_rounded, size: 18),
                    text: 'Audio Only',
                  ),
                  Tab(
                    icon: Icon(Icons.hd_rounded, size: 18),
                    text: 'HD Video',
                  ),
                ],
              ),
            ),

            // Tab contents
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Video + Audio Muxed
                  _buildStreamList(
                    context,
                    options: video.muxedStreams,
                    emptyMessage: 'No standard video+audio streams found.',
                    bannerMessage: 'Plays immediately in any media player with full sound.',
                  ),

                  // Tab 2: Audio Only
                  _buildStreamList(
                    context,
                    options: video.audioStreams,
                    emptyMessage: 'No audio streams found.',
                    bannerMessage: 'High bitrate audio for music or podcasts.',
                  ),

                  // Tab 3: Video Only (1080p, 4K)
                  _buildStreamList(
                    context,
                    options: video.videoOnlyStreams,
                    emptyMessage: 'No high-definition video streams found.',
                    bannerMessage: 'Note: High-res streams from YouTube are video-only streams.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamList(
    BuildContext context, {
    required List<StreamOption> options,
    required String emptyMessage,
    String? bannerMessage,
  }) {
    if (options.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyMessage,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        if (bannerMessage != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppTheme.primaryRed),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bannerMessage,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ...options.map((option) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    option.container.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.primaryRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              title: Text(
                option.label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                'Approx size: ${option.formattedSize}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onOptionSelected(option);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: const Size(0, 36),
                ),
                child: const Text('Download'),
              ),
            ),
          );
        }),
      ],
    );
  }
}

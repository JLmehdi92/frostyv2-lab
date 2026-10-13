import 'package:flutter/material.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/vod/vod_screen.dart';
import 'package:frosty/screens/vod/vod_time.dart';
import 'package:frosty/screens/vod/widgets/video_card_layout.dart';
import 'package:intl/intl.dart';

/// A past broadcast, highlight or upload in a list, laid out like the live
/// stream cards: thumbnail with its length, then title and details.
class VodCard extends StatelessWidget {
  const VodCard({
    super.key,
    required this.vod,
    this.progress,
    this.watched = false,
    this.onTap,
    this.showChannel = false,
  });

  /// Names the channel instead of the category (a category's list).
  final bool showChannel;

  final Vod vod;

  /// Saved resume point as a fraction of the length, drawn on the thumbnail.
  final double? progress;

  /// Watched to the end.
  final bool watched;

  /// Defaults to opening the VOD in-app.
  final VoidCallback? onTap;

  /// Twitch serves a "processing" image for videos still being encoded.
  String? get _thumbnailUrl {
    final url = vod.previewThumbnailUrl;
    if (url == null || url.isEmpty || url.contains('404_processing')) {
      return null;
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = vod.title.trim().isEmpty ? 'Untitled' : vod.title.trim();
    final details = [
      formatTimeAgo(vod.createdAt),
      '${NumberFormat().format(vod.viewCount)} '
          '${vod.viewCount == 1 ? 'view' : 'views'}',
    ].join(' · ');

    return VideoCardLayout(
      thumbnailUrl: _thumbnailUrl,
      fallbackIcon: Icons.video_library_outlined,
      lengthLabel: formatVodTime(vod.duration),
      topChips: [
        if (vod.isRecording)
          VideoCardChip(
            color: colors.error.withValues(alpha: 0.9),
            child: const Text('Recording'),
          ),
        if (watched) const VideoCardChip(child: Text('Watched')),
        if (vod.isRestricted)
          VideoCardChip(
            child: Icon(
              Icons.lock_rounded,
              size: 12,
              color: videoCardOnImage(context),
            ),
          ),
      ],
      progress: progress,
      title: title,
      subtitle: showChannel ? vod.ownerDisplayName : vod.gameName,
      details: details,
      footer: vod.isRestricted
          ? Text(
              'Subscribers only',
              style: TextStyle(fontSize: 14, color: colors.primary),
            )
          : null,
      onTap: onTap ?? () => VodScreen.open(context, vodId: vod.id, vod: vod),
    );
  }
}

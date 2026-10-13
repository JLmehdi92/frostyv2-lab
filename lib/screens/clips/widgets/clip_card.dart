import 'package:flutter/material.dart';
import 'package:frosty/models/clip.dart';
import 'package:frosty/screens/clips/clip_screen.dart';
import 'package:frosty/screens/vod/vod_time.dart';
import 'package:frosty/screens/vod/widgets/video_card_layout.dart';
import 'package:intl/intl.dart';

/// A clip in a list, laid out like the VOD cards: thumbnail with its length
/// and views, then the title, category, age and clipper.
class ClipCard extends StatelessWidget {
  const ClipCard({super.key, required this.clip, this.onTap});

  final Clip clip;

  /// Defaults to opening the clip in-app.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final views =
        '${NumberFormat.compact().format(clip.viewCount)} '
        '${clip.viewCount == 1 ? 'view' : 'views'}';
    final curator = clip.curatorDisplayName;
    final details = [
      formatTimeAgo(clip.createdAt),
      if (curator != null) 'Clipped by $curator',
    ].join(' · ');
    final title = clip.title.trim();

    return VideoCardLayout(
      thumbnailUrl: clip.thumbnailUrl,
      fallbackIcon: Icons.movie_outlined,
      lengthLabel: formatVodTime(clip.duration),
      topChips: [VideoCardChip(child: Text(views))],
      title: title.isEmpty ? 'Untitled clip' : title,
      subtitle: clip.gameName,
      details: details,
      onTap:
          onTap ?? () => ClipScreen.open(context, slug: clip.slug, clip: clip),
    );
  }
}

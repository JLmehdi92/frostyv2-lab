import 'package:flutter/material.dart' hide Clip;
import 'package:intl/intl.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/screens/clips/clip_screen.dart';
import 'package:onset/screens/vod/vod_time.dart';
import 'package:onset/screens/vod/widgets/video_card_layout.dart';
import 'package:onset/screens/vod/widgets/video_glyph.dart';

/// A clip in a list, laid out like the VOD cards (board VideosChaine's
/// Clips): thumbnail with its views and length, then the title, category
/// (or channel), age and clipper.
class ClipCard extends StatelessWidget {
  const ClipCard({
    super.key,
    required this.clip,
    this.onTap,
    this.showChannel = false,
    this.tile = false,
  });

  /// Names the channel instead of the category (a category's list).
  final bool showChannel;

  /// The picture on top, for a tablet's grid.
  final bool tile;

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
      fallback: (glyph: VideoGlyphKind.clip, label: null),
      lengthLabel: formatVodTime(clip.duration),
      tile: tile,
      topChips: [VideoCardChip(large: tile, child: Text(views))],
      title: title.isEmpty ? 'Untitled clip' : title,
      subtitle: showChannel ? clip.broadcasterDisplayName : clip.gameName,
      channelLogin: showChannel && tile ? clip.broadcasterLogin : null,
      details: details,
      onTap:
          onTap ?? () => ClipScreen.open(context, slug: clip.slug, clip: clip),
    );
  }
}

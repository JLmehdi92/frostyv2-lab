import 'package:flutter/material.dart' hide Clip;
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/screens/clips/clip_screen.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/vod/vod_time.dart';
import 'package:onset/screens/vod/widgets/video_card_layout.dart';
import 'package:onset/screens/vod/widgets/video_glyph.dart';
import 'package:onset/theme.dart';

/// A clip in a list, laid out like the VOD cards: thumbnail with its views and length, then the title, category
/// (or channel), age and clipper.
class ClipCard extends StatelessWidget {
  const ClipCard({
    super.key,
    required this.clip,
    this.onTap,
    this.onManage,
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

  final VoidCallback? onManage;

  static ValueKey<String> manageKey(String slug) =>
      ValueKey('clip-manage-$slug');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final views = l.videoViewsCompact(count: clip.viewCount);
    final curator = clip.curatorDisplayName;
    final details = [
      formatTimeAgo(clip.createdAt, l),
      if (curator != null) l.clipClippedBy(curator: curator),
    ].join(' · ');
    final title = clip.title.trim();

    return VideoCardLayout(
      thumbnailUrl: clip.thumbnailUrl,
      fallback: (glyph: VideoGlyphKind.clip, label: null),
      lengthLabel: formatVodTime(clip.duration),
      tile: tile,
      topChips: [VideoCardChip(large: tile, child: Text(views))],
      title: title.isEmpty ? l.clipUntitled : title,
      subtitle: showChannel ? clip.broadcasterDisplayName : clip.gameName,
      channelLogin: showChannel && tile ? clip.broadcasterLogin : null,
      details: details,
      footer: switch (onManage) {
        final manage? => Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: manageKey(clip.slug),
            onPressed: manage,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: FeedColors.of(context).text,
            ),
            icon: VideoGlyph(
              VideoGlyphKind.pencil,
              size: 16,
              color: FeedColors.of(context).text,
            ),
            label: Text(
              l.clipManage,
              style: const TextStyle(
                fontFamily: OnsetTokens.bodyFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        null => null,
      },
      onTap:
          onTap ?? () => ClipScreen.open(context, slug: clip.slug, clip: clip),
    );
  }
}

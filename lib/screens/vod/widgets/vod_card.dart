import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/vod/vod_screen.dart';
import 'package:onset/screens/vod/vod_time.dart';
import 'package:onset/screens/vod/widgets/video_card_layout.dart';
import 'package:onset/screens/vod/widgets/video_glyph.dart';
import 'package:onset/screens/vod/widgets/vod_info_strip.dart';

/// [vod]'s picture, or null while Twitch still serves its "processing"
/// image (a video being encoded).
String? vodThumbnailUrl(Vod vod) {
  final url = vod.previewThumbnailUrl;
  if (url == null || url.isEmpty || url.contains('404_processing')) {
    return null;
  }
  return url;
}

/// A past broadcast, highlight or upload in a list:
/// the thumbnail with Recording,
/// Watched or the lock and its length and progress, then the title, the
/// category (or the channel) and the age and views.
class VodCard extends StatelessWidget {
  const VodCard({
    super.key,
    required this.vod,
    this.progress,
    this.watched = false,
    this.onTap,
    this.showChannel = false,
    this.sidePadding = 16,
    this.tile = false,
    this.channelAvatar = false,
  });

  /// The card's sides (see [VideoCardLayout.sidePadding]).
  final double sidePadding;

  /// Names the channel instead of the category (a category's list).
  final bool showChannel;

  /// With [showChannel], the channel's picture beside its name (followed
  /// videos).
  final bool channelAvatar;

  /// The picture on top, for a tablet's grid.
  final bool tile;

  final Vod vod;

  /// Saved resume point as a fraction of the length, drawn on the thumbnail.
  final double? progress;

  /// Watched to the end.
  final bool watched;

  /// Defaults to opening the VOD in-app.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = vod.title.trim().isEmpty ? l.videoUntitled : vod.title.trim();
    final details = vodDetails(vod, l);
    final channel = vod.ownerDisplayName.isNotEmpty
        ? vod.ownerDisplayName
        : vod.ownerLogin;

    return VideoCardLayout(
      thumbnailUrl: vodThumbnailUrl(vod),
      fallback: (glyph: VideoGlyphKind.camera, label: l.videoProcessing),
      lengthLabel: formatVodTime(vod.duration),
      tile: tile,
      topChips: [
        if (vod.isRecording)
          RecordingBadge(height: tile ? 22 : 19, fontSize: tile ? 11.5 : 10.5),
        if (watched)
          VideoCardChip(
            large: tile,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                const VideoGlyph(
                  VideoGlyphKind.check,
                  color: Color(0xFFF5F5F5),
                  size: 10,
                  strokeWidth: 3,
                ),
                Text(l.profileWatched),
              ],
            ),
          ),
        if (vod.isRestricted)
          VideoCardChip(
            large: tile,
            square: true,
            child: Semantics(
              label: l.profileSubscribersOnly,
              child: const VideoGlyph(
                VideoGlyphKind.lock,
                color: Color(0xFFF5F5F5),
                size: 11,
                strokeWidth: 2.4,
              ),
            ),
          ),
      ],
      progress: progress,
      title: title,
      subtitle: showChannel ? channel : vod.gameName,
      channelLogin: showChannel && (channelAvatar || tile)
          ? vod.ownerLogin
          : null,
      details: details,
      footer: vod.isRestricted ? const SubscribersOnlyLabel() : null,
      onTap: onTap ?? () => VodScreen.open(context, vodId: vod.id, vod: vod),
      sidePadding: sidePadding,
    );
  }
}

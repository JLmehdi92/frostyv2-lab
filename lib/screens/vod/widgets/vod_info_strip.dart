import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/vod/vod_time.dart';
import 'package:onset/screens/vod/widgets/video_kit.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';

/// "Yesterday · 3,104 views".
String vodDetails(Vod vod) => [
  formatTimeAgo(vod.createdAt),
  '${NumberFormat().format(vod.viewCount)} '
      '${vod.viewCount == 1 ? 'view' : 'views'}',
].join(' · ');

/// Title and details of a VOD under the player (boards Rediff and
/// RediffTablette): the title, then the category pill and the age and
/// views; a broadcast still recording says so.
class VodInfoStrip extends StatelessWidget {
  const VodInfoStrip({
    super.key,
    required this.vod,
    this.large = false,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
    this.divider = true,
  });

  final Vod vod;

  /// A tablet's title (20 / 800).
  final bool large;
  final EdgeInsetsGeometry padding;

  /// The hairline under the strip (above the chat replay).
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final gameId = vod.gameId;
    final gameName = vod.gameName;
    final hasCategory = gameId != null && gameName != null;
    final title = vod.title.trim().isEmpty
        ? 'Untitled broadcast'
        : vod.title.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider
            ? Border(
                bottom: BorderSide(
                  color: colors.hairline,
                  width: OnsetTokens.hairlineWidth,
                ),
              )
            : null,
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: large ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: OnsetTokens.displayFamily,
                fontSize: large ? 20 : 16,
                fontWeight: large ? FontWeight.w800 : FontWeight.w700,
                letterSpacing: large ? -0.4 : -0.16,
                height: 1.3,
                color: colors.text,
              ),
            ),
            // The pill's 44 dp target takes the board's 8 dp gap.
            if (!hasCategory) const SizedBox(height: 8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                if (vod.isRecording) const RecordingBadge(),
                if (hasCategory)
                  VideoCategoryChip(name: gameName, gameId: gameId),
                Text(
                  vodDetails(vod),
                  style: OnsetType.tabular(
                    TextStyle(
                      fontFamily: OnsetTokens.bodyFamily,
                      fontSize: 13,
                      height: 1.3,
                      color: colors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "● Recording": a broadcast still live, in the signal (boards
/// VideosChaine, VideosSuivies).
class RecordingBadge extends StatelessWidget {
  const RecordingBadge({super.key, this.height = 19, this.fontSize = 10.5});

  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final accent = context.onsetColors.live;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: OnsetTokens.backgroundDark,
              shape: BoxShape.circle,
            ),
          ),
          Text(
            'Recording',
            style: TextStyle(
              fontFamily: OnsetTokens.bodyFamily,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              height: 1,
              color: OnsetTokens.backgroundDark,
            ),
          ),
        ],
      ),
    );
  }
}

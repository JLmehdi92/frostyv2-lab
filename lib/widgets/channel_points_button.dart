import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/models/community_points.dart';
import 'package:frosty/screens/channel/stores/channel_events_store.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/utils/modal_bottom_sheet.dart';
import 'package:frosty/widgets/channel_points_sheet.dart';
import 'package:provider/provider.dart';

/// The channel points balance, sitting in the chat's bottom bar.
///
/// Placed there because that is where Twitch puts it — bottom-left of the
/// chat, beside the message box, not above the message list. Tapping it opens
/// the rewards and the running prediction.
///
/// Renders nothing at all when there is no channel points context: signed out,
/// a channel with the feature switched off, or the mini player, where no
/// [ChannelEventsStore] is provided.
/// The streamer's own points icon, or the generic one when they kept the
/// default.
///
/// Twitch lets a channel upload artwork for its points and most sizeable ones
/// do; showing a generic star instead is the kind of small wrongness that makes
/// a client feel like a copy. Falls back to the star if the image fails, so a
/// dead CDN costs the picture and nothing else.
class _PointsIcon extends StatelessWidget {
  final CommunityPointsContext points;
  final double size;

  const _PointsIcon({required this.points, required this.size});

  @override
  Widget build(BuildContext context) {
    final color = context.frostyColors.live;
    final fallback = Icon(Icons.stars_rounded, size: size, color: color);

    // 2x: these render small, and the 1x copy Twitch hands back is visibly
    // soft on a 1440p tablet.
    final url = points.pointsImageUrlAt(2);
    if (url == null) return fallback;

    return Image.network(
      url,
      width: size,
      height: size,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class ChannelPointsButton extends StatelessWidget {
  const ChannelPointsButton({super.key});

  /// Shortens a balance the way Twitch does, so a seven-figure total does not
  /// push the message box off a narrow landscape chat column.
  static String compact(int value) {
    if (value >= 1000000) {
      final millions = value / 1000000;
      return millions >= 10
          ? '${millions.round()}M'
          : '${millions.toStringAsFixed(1).replaceFirst('.0', '')}M';
    }
    if (value >= 1000) {
      final thousands = value / 1000;
      return thousands >= 10
          ? '${thousands.round()}K'
          : '${thousands.toStringAsFixed(1).replaceFirst('.0', '')}K';
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    // Absent in the mini player and anywhere outside a channel.
    final store = context.watch<ChannelEventsStore?>();
    if (store == null) return const SizedBox.shrink();

    return Observer(
      builder: (context) {
        final points = store.points;
        if (!points.hasAnything) return const SizedBox.shrink();

        final colors = context.frostyColors;
        final prediction = points.activePrediction;

        return Tooltip(
          message: points.pointsName ?? 'Channel points',
          preferBelow: false,
          child: InkWell(
            borderRadius: const BorderRadius.all(
              Radius.circular(FrostyTokens.radiusPill),
            ),
            onTap: () => showModalBottomSheetWithProperFocus(
              context: context,
              isScrollControlled: true,
              // The store goes with it: the sheet is where points are spent,
              // and it stays live so a redeem's new balance lands without
              // reopening the panel.
              builder: (_) => ChannelPointsSheet(points: points, store: store),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The two things worth interrupting for take the icon over,
                  // rather than adding controls to a bar that already loses its
                  // message box below 30% of a landscape screen. A chest
                  // expires in minutes, so it outranks a prediction — and both
                  // outrank the streamer's artwork, which is decoration.
                  if (points.hasClaim)
                    Icon(
                      Icons.card_giftcard_rounded,
                      size: 16,
                      color: colors.live,
                    )
                  else if (prediction != null && prediction.isOpen)
                    Icon(
                      Icons.leaderboard_rounded,
                      size: 16,
                      color: colors.live,
                    )
                  else
                    _PointsIcon(points: points, size: 16),
                  const SizedBox(width: 5),
                  Text(
                    points.balance == null
                        ? '—'
                        : compact(points.balance!),
                    style: context.frostyText.metadata.copyWith(
                      color: colors.live,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

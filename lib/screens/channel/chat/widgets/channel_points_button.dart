import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/screens/channel/chat/widgets/channel_points_sheet.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/sheet/onset_panel.dart';
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
    final color = context.onsetColors.live;
    // The generic mark: a ring in the signal colour.
    final fallback = Container(
      key: ChannelPointsButton.genericIconKey,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
    );

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
  /// The channel whose chat holds the button. The store belongs to the
  /// watched channel, so another channel's chat tab shows nothing rather
  /// than spending points on the wrong channel.
  final String? channelId;

  /// The tablet-portrait size (48 high instead of 44).
  final bool large;

  /// Space before the button, only when it shows.
  final double gap;

  const ChannelPointsButton({
    super.key,
    this.channelId,
    this.large = false,
    this.gap = 0,
  });

  /// The generic points mark, when the channel kept Twitch's default.
  static const genericIconKey = ValueKey('channel-points-generic-icon');

  /// Shortens a balance the way Twitch does, so a seven-figure total does not
  /// push the message box off a narrow landscape chat column.
  static String compact(int value) {
    if (value < 1000) return value.toString();

    // A unit only fits if the value does not round up to the next one:
    // 999 500 is "1M", not "1000K".
    final thousands = _shorten(value / 1000);
    if (thousands.rounded < 1000) return '${thousands.text}K';

    return '${_shorten(value / 1000000).text}M';
  }

  /// One decimal below ten, none from ten up — and what that rounds to.
  static ({String text, double rounded}) _shorten(double amount) {
    if (amount >= 10) {
      final rounded = amount.round();
      return (text: '$rounded', rounded: rounded.toDouble());
    }
    final fixed = amount.toStringAsFixed(1);
    return (
      text: fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed,
      rounded: double.parse(fixed),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Absent in the mini player and anywhere outside a channel.
    final store = context.watch<ChannelEventsStore?>();
    if (store == null) return const SizedBox.shrink();
    if (channelId != null && channelId != store.channelId) {
      return const SizedBox.shrink();
    }

    return Observer(
      builder: (context) {
        final points = store.points;
        if (!points.hasAnything) return const SizedBox.shrink();

        final colors = context.onsetColors;
        final prediction = points.activePrediction;

        final balance = points.balance == null ? '—' : compact(points.balance!);
        final height = large ? 48.0 : 44.0;
        final shape = StadiumBorder(
          side: BorderSide(
            color: colors.hairline,
            width: OnsetTokens.hairlineWidth,
          ),
        );

        void openPoints() {
          // Fresh, like Twitch's panel (at most once a minute).
          unawaited(store.refreshWatchStreak());
          // A sheet on a phone; on a tablet a panel above the pill.
          showSheetOrPanel<void>(
            context: context,
            size: ChannelPointsSheet.panelSize,
            sides: const [PanelSide.above, PanelSide.below],
            anchor: globalRectOf(context),
            region: PanelRegion.of(context),
            // The store goes with it: the sheet is where points are spent,
            // and it stays live so a redeem's new balance lands without
            // reopening the panel.
            builder: (_) => ChannelPointsSheet(points: points, store: store),
          );
        }

        // A pill beside the message box.
        final button = Tooltip(
          message: points.pointsName ?? context.l10n.pointsChannelPoints,
          preferBelow: false,
          child: Semantics(
            button: true,
            label:
                '${points.pointsName ?? context.l10n.pointsChannelPoints}, '
                '$balance',
            onTap: openPoints,
            excludeSemantics: true,
            child: Material(
              color: context.theme.inputDecorationTheme.fillColor,
              shape: shape,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: shape,
                onTap: openPoints,
                child: Container(
                  height: height,
                  padding: EdgeInsets.symmetric(horizontal: large ? 14 : 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: large ? 7 : 6,
                    children: [
                      // The two things worth interrupting for take the icon
                      // over, rather than adding controls to a bar that
                      // already loses its message box below 30% of a
                      // landscape screen. A chest expires in minutes, so it
                      // outranks a prediction — and both outrank the
                      // streamer's artwork, which is decoration.
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
                      Text(
                        balance,
                        maxLines: 1,
                        style: OnsetType.tabular(
                          TextStyle(
                            fontFamily: OnsetTokens.bodyFamily,
                            fontSize: large ? 14 : 13,
                            fontWeight: FontWeight.w600,
                            height: 1,
                            color: context.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        return gap == 0
            ? button
            : Padding(
                padding: EdgeInsetsDirectional.only(start: gap),
                child: button,
              );
      },
    );
  }
}

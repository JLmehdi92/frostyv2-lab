import 'package:flutter/material.dart';
import 'package:onset/models/hype_train.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_card_pill.dart';
import 'package:onset/screens/home/stream_list/stream_card.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/motion/rolling_number.dart';
import 'package:onset/widgets/uptime.dart';

/// The hero live card (boards Accueil and, [large], TabletteAccueil): the
/// stream's picture with the "LIVE" badge, its viewers and uptime, the
/// channel in the live ring, its title and category, and the viewer's
/// streak; on a tablet a "Watch" button. Also every card of a list with
/// the "large stream card" setting.
///
/// Without a thumbnail it is a [StreamCard] row: a picture-less hero
/// carries nothing more and only costs height.
class LargeStreamCard extends StatelessWidget {
  final StreamTwitch streamInfo;
  final bool showThumbnail;
  final bool showCategory;
  final bool showPinOption;
  final bool? isPinned;

  /// The channel's running hype train, if any (followed list).
  final HtCardStatus? hypeTrain;

  /// The viewer's running watch streak here, if any (followed list).
  final int? watchStreak;

  /// The tablet hero (TabletteAccueil): larger type, the viewers spelled
  /// out, the uptime and streak in the meta line, a "Watch" button.
  final bool large;

  /// Around the card; null: the list's gutters.
  final EdgeInsetsGeometry? padding;

  const LargeStreamCard({
    super.key,
    required this.streamInfo,
    required this.showThumbnail,
    this.showCategory = true,
    this.showPinOption = false,
    this.isPinned,
    this.hypeTrain,
    this.watchStreak,
    this.large = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (!showThumbnail) {
      return StreamCard(
        streamInfo: streamInfo,
        showThumbnail: false,
        showCategory: showCategory,
        showPinOption: showPinOption,
        isPinned: isPinned,
        hypeTrain: hypeTrain,
        watchStreak: watchStreak,
      );
    }
    final safe = MediaQuery.paddingOf(context);
    final radius = BorderRadius.circular(large ? 22 : 18);
    final inset = large ? 18.0 : 12.0;
    final name = getReadableName(streamInfo.userName, streamInfo.userLogin);
    final title = streamInfo.title.trim();
    final openCategory = openCategoryOf(context, streamInfo);
    final streak = watchStreak;

    final meta = <InlineSpan>[
      if (showCategory && streamInfo.gameName.isNotEmpty)
        TextSpan(text: streamInfo.gameName),
      if (large) ...[
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Uptime(
            startTime: streamInfo.startedAt,
            style: const TextStyle(
              fontSize: 13,
              color: OverImage.secondary,
              height: 1.2,
            ),
          ),
        ),
        if (streak != null) TextSpan(text: 'Streak $streak'),
      ],
    ];
    final metaLine = <InlineSpan>[
      for (final (i, span) in meta.indexed) ...[
        if (i > 0) const TextSpan(text: ' · '),
        span,
      ],
    ];

    final card = ClipRRect(
      borderRadius: radius,
      child: ColoredBox(
        color: FeedColors.of(context).well,
        child: Stack(
          fit: StackFit.expand,
          children: [
            StreamThumbnail(stream: streamInfo, borderRadius: radius),
            // Board: 35 % black at the top, clear in the middle, 90 % at
            // the bottom (gradients only: nothing is blurred).
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x59000000),
                    Color(0x00000000),
                    Color(0x00000000),
                    Color(0xE6000000),
                  ],
                  stops: [0, 0.3, 0.45, 1],
                ),
              ),
            ),
            InsetHairline(borderRadius: radius),
            PositionedDirectional(
              start: inset,
              top: inset,
              end: inset,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      LiveBadge(large: large),
                      Semantics(
                        label:
                            '${formatViewers(streamInfo.viewerCount, compact: false)} viewers',
                        child: ExcludeSemantics(
                          child: OverlayPill(
                            height: large ? 26 : 24,
                            radius: large ? 7 : 6,
                            padding: large ? 9 : 8,
                            child: RollingViewers(
                              viewers: streamInfo.viewerCount,
                              spelled: large,
                              fontSize: large ? 13 : 12,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (!large)
                        OverlayPill(
                          child: Uptime(
                            startTime: streamInfo.startedAt,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: OnsetTokens.textBodyDark,
                              height: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (hypeTrain case final status?)
                    HypeTrainCardPill(status: status),
                ],
              ),
            ),
            PositionedDirectional(
              start: large ? 20 : inset,
              end: large ? 20 : inset,
              bottom: large ? 20 : inset,
              child: Row(
                crossAxisAlignment: large
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.center,
                spacing: large ? 14 : 10,
                children: [
                  RingedAvatar(
                    login: streamInfo.userLogin,
                    size: large ? 52 : 40,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      spacing: large ? 4 : 3,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: OnsetTokens.displayFamily,
                            fontSize: large ? 22 : 16,
                            fontWeight: large
                                ? FontWeight.w800
                                : FontWeight.w700,
                            letterSpacing:
                                (large ? -0.025 : -0.01) * (large ? 22 : 16),
                            color: OverImage.text,
                          ),
                        ),
                        if (title.isNotEmpty)
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: large ? 15 : 13,
                              color: OverImage.body,
                            ),
                          ),
                        if (metaLine.isNotEmpty)
                          Semantics(
                            button: openCategory != null,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: openCategory,
                              child: Text.rich(
                                TextSpan(children: metaLine),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: OnsetType.tabular(
                                  TextStyle(
                                    fontSize: large ? 13 : 12,
                                    color: OverImage.secondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (large)
                    _WatchButton(
                      onPressed: () => openStream(context, streamInfo),
                    )
                  else if (streak != null)
                    StreakPill(value: streak, overImage: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // The card sinks as soon as the finger is down (design system press).
    return Padding(
      padding:
          padding ??
          EdgeInsets.fromLTRB(
            OnsetSpacing.gutterPhone + safe.left,
            6,
            OnsetSpacing.gutterPhone + safe.right,
            8,
          ),
      child: PressScale(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            // The finger is down: get the stream's token while the page
            // opens.
            onTapDown: (_) => preloadStream(context, streamInfo),
            onTap: () => openStream(context, streamInfo),
            onLongPress: () => showStreamActions(
              context,
              streamInfo,
              showPinOption: showPinOption,
              isPinned: isPinned,
            ),
            // Boards: 358 x 204 on a phone, 640 x 330 on a tablet.
            child: AspectRatio(
              aspectRatio: large ? 640 / 330 : 16 / 9,
              child: card,
            ),
          ),
        ),
      ),
    );
  }
}

/// The viewers of a hero: "2.4k" or, [spelled], "2,445 watching"; the
/// digits roll when a refresh changes them.
class RollingViewers extends StatelessWidget {
  const RollingViewers({
    super.key,
    required this.viewers,
    this.spelled = false,
    this.fontSize = 12,
  });

  final int viewers;
  final bool spelled;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = OnsetType.tabular(
      TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: OverImage.text,
        height: 1,
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RollingNumber(formatViewers(viewers, compact: !spelled), style: style),
        if (spelled) Text(' watching', style: style),
      ],
    );
  }
}

class _WatchButton extends StatelessWidget {
  const _WatchButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: OnsetTokens.accent,
        foregroundColor: OnsetTokens.backgroundDark,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: OnsetTokens.bodyFamily,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      icon: const Icon(Icons.play_arrow_rounded, size: 18),
      label: const Text('Watch'),
    );
  }
}

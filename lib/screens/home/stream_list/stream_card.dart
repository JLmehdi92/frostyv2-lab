import 'package:flutter/material.dart';
import 'package:onset/models/hype_train.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_card_pill.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/home/stream_list/stream_tags.dart';
import 'package:onset/screens/home/stream_list/watch_streak_tag.dart';
import 'package:onset/screens/home/top/tags/tag_streams.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/profile_picture.dart';
import 'package:onset/widgets/uptime.dart';

/// A live stream in a list (board Accueil: the 150 x 84 thumbnail beside
/// the channel, title and category) or, as a [tile], in a tablet grid
/// (board TabletteAccueil: the thumbnail on top, the channel's picture
/// beside its lines).
///
/// A tap opens the channel (its token is asked for as the finger lands), a
/// long press its actions, a long press on the thumbnail enlarges it; the
/// category and the tags open their lists.
class StreamCard extends StatelessWidget {
  final StreamTwitch streamInfo;
  final bool showThumbnail;
  final bool showCategory;
  final bool showPinOption;
  final bool? isPinned;

  /// The channel's running hype train, if any (followed list).
  final HtCardStatus? hypeTrain;

  /// The viewer's running watch streak here, if any (followed list).
  final int? watchStreak;

  /// The grid tile of a tablet (thumbnail on top).
  final bool tile;

  /// The tag of the list the card is in (a tag's page): its pill is lit
  /// and does not open the page again.
  final String? activeTag;

  const StreamCard({
    super.key,
    required this.streamInfo,
    required this.showThumbnail,
    this.showCategory = true,
    this.showPinOption = false,
    this.isPinned,
    this.hypeTrain,
    this.watchStreak,
    this.tile = false,
    this.activeTag,
  });

  /// The row's thumbnail width (board: 150; 200 in a wide row).
  static double rowThumbnailWidth(double rowWidth) =>
      rowWidth >= 500 ? 200 : 150;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final content = tile && showThumbnail
        ? _tile(context)
        : LayoutBuilder(
            builder: (context, constraints) => _row(context, constraints),
          );
    // The card sinks as soon as the finger is down (design system press).
    return PressScale(
      child: InkWell(
        borderRadius: BorderRadius.circular(tile ? 16 : 12),
        // The finger is down: get the stream's token while the page opens.
        onTapDown: (_) => preloadStream(context, streamInfo),
        onTap: () => openStream(context, streamInfo),
        onLongPress: () => showStreamActions(
          context,
          streamInfo,
          showPinOption: showPinOption,
          isPinned: isPinned,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            (tile ? 0 : OnsetSpacing.gutterPhone) + padding.left,
            tile ? 0 : 6,
            (tile ? 0 : OnsetSpacing.gutterPhone) + padding.right,
            tile ? 0 : 6,
          ),
          child: content,
        ),
      ),
    );
  }

  String get _name =>
      getReadableName(streamInfo.userName, streamInfo.userLogin);

  Widget _thumbnail(BuildContext context, {required bool large}) {
    final radius = BorderRadius.circular(large ? 14 : 12);
    final inset = large ? 8.0 : 6.0;
    return ClipRRect(
      borderRadius: radius,
      child: ColoredBox(
        color: FeedColors.of(context).well,
        child: Stack(
          fit: StackFit.expand,
          children: [
            StreamThumbnail(stream: streamInfo, borderRadius: radius),
            InsetHairline(borderRadius: radius),
            if (hypeTrain case final status?)
              PositionedDirectional(
                start: 0,
                top: 0,
                child: HypeTrainCardPill(status: status),
              ),
            PositionedDirectional(
              start: inset,
              bottom: inset,
              child: ViewerPill(
                viewers: streamInfo.viewerCount,
                height: large ? 22 : 20,
                fontSize: large ? 12 : 11,
              ),
            ),
            PositionedDirectional(
              end: inset,
              bottom: inset,
              child: OverlayPill(
                height: large ? 22 : 20,
                radius: large ? 6 : 5,
                padding: large ? 7 : 6,
                color: OverImage.pillStrong,
                child: Uptime(
                  startTime: streamInfo.startedAt,
                  style: TextStyle(
                    fontSize: large ? 12 : 11,
                    fontWeight: FontWeight.w500,
                    color: OnsetTokens.textBodyDark,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The name, title, category, then the streak and tags.
  Widget _lines(
    BuildContext context, {
    required double avatar,
    required bool tile,
  }) {
    final colors = FeedColors.of(context);
    final title = streamInfo.title.trim();
    final category = streamInfo.gameName.isNotEmpty
        ? streamInfo.gameName
        : 'No Category';
    final openCategory = openCategoryOf(context, streamInfo);
    final tags = streamInfo.tags.isEmpty
        ? null
        : StreamTags(
            tags: streamInfo.tags,
            active: activeTag,
            onTap: (tag) => TagStreams.open(context, tag),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: tile ? 2 : 3,
      children: [
        Row(
          spacing: 6,
          children: [
            if (avatar > 0)
              ProfilePicture(
                userLogin: streamInfo.userLogin,
                radius: avatar / 2,
              ),
            Flexible(
              child: Text(
                _name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: OnsetTokens.displayFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.01 * 15,
                  color: colors.text,
                ),
              ),
            ),
          ],
        ),
        if (title.isNotEmpty)
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: colors.body),
          ),
        // A category's list names no category: its viewers instead (board
        // Categorie).
        if (!showCategory && showThumbnail)
          Text(
            '${formatViewers(streamInfo.viewerCount, compact: false)} viewers',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OnsetType.tabular(
              TextStyle(fontSize: 12, color: colors.secondary),
            ),
          ),
        if (showCategory)
          Semantics(
            button: openCategory != null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: openCategory,
              child: Text(
                category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colors.secondary),
              ),
            ),
          ),
        if (!showThumbnail)
          // Without a thumbnail, the viewers and uptime come in the text.
          DefaultTextStyle.merge(
            style: OnsetType.tabular(
              TextStyle(fontSize: 12, color: colors.secondary),
            ),
            child: Row(
              spacing: 5,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: context.onsetColors.live,
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  '${formatViewers(streamInfo.viewerCount, compact: false)} viewers',
                ),
                const Text('·'),
                Flexible(
                  child: Uptime(
                    startTime: streamInfo.startedAt,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colors.secondary),
                  ),
                ),
              ],
            ),
          ),
        if (watchStreak case final streak?)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            // Twitch's Following tab puts it with the tags; they stay.
            child: Row(
              spacing: 4,
              children: [
                WatchStreakTag(value: streak),
                if (tags != null) Expanded(child: tags),
              ],
            ),
          )
        else if (tags != null)
          Padding(padding: const EdgeInsets.only(top: 3), child: tags),
      ],
    );
  }

  Widget _row(BuildContext context, BoxConstraints constraints) {
    if (!showThumbnail) {
      return Row(
        spacing: 12,
        children: [
          ProfilePicture(userLogin: streamInfo.userLogin),
          Expanded(child: _lines(context, avatar: 0, tile: false)),
        ],
      );
    }
    final width = StreamCard.rowThumbnailWidth(constraints.maxWidth);
    return Row(
      spacing: 12,
      children: [
        SizedBox(
          width: width,
          height: width * 9 / 16,
          child: _thumbnail(context, large: false),
        ),
        Expanded(child: _lines(context, avatar: 18, tile: false)),
      ],
    );
  }

  Widget _tile(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _thumbnail(context, large: true),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            ProfilePicture(userLogin: streamInfo.userLogin, radius: 17),
            Expanded(child: _lines(context, avatar: 0, tile: true)),
          ],
        ),
      ],
    );
  }
}

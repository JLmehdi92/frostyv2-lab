import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frosty/screens/home/stream_list/stream_card_parts.dart';
import 'package:frosty/screens/vod/widgets/video_glyph.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';
import 'package:frosty/widgets/frosty_photo_view_dialog.dart';
import 'package:frosty/widgets/motion/press_scale.dart';
import 'package:frosty/widgets/profile_picture.dart';
import 'package:frosty/widgets/skeleton_loader.dart';

/// A small label over a video thumbnail (length, "Watched", views…): 19 dp
/// (22 on a tile), black at 65 %, a light hairline (boards VideosChaine,
/// VideosSuivies).
class VideoCardChip extends StatelessWidget {
  const VideoCardChip({
    super.key,
    required this.child,
    this.color,
    this.large = false,
    this.ring = true,
    this.square = false,
  });

  final Widget child;

  /// The ground (black at 65 % when null).
  final Color? color;

  /// A tile's chip (22 dp, 11.5 sp).
  final bool large;

  /// The light hairline (not under the length, as drawn).
  final bool ring;

  /// As wide as tall (an icon alone).
  final bool square;

  @override
  Widget build(BuildContext context) {
    final height = large ? 22.0 : 19.0;
    return Container(
      height: height,
      width: square ? height : null,
      padding: square ? null : const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color ?? const Color(0xA6000000),
        borderRadius: BorderRadius.circular(5),
        border: ring && color == null
            ? Border.all(
                color: const Color(0x24FFFFFF),
                width: FrostyTokens.hairlineWidth,
              )
            : null,
      ),
      child: DefaultTextStyle.merge(
        style: FrostyType.tabular(
          TextStyle(
            fontFamily: FrostyTokens.bodyFamily,
            fontSize: large ? 11.5 : 10.5,
            fontWeight: FontWeight.w600,
            height: 1,
            color: OverImage.text,
          ),
        ),
        child: IconTheme.merge(
          data: const IconThemeData(color: OverImage.text),
          child: child,
        ),
      ),
    );
  }
}

/// Text and icon colour over a thumbnail.
Color videoCardOnImage(BuildContext context) => OverImage.text;

/// What a card shows while Twitch has no picture: a glyph and a word
/// ("Processing").
typedef VideoCardFallback = ({VideoGlyphKind glyph, String? label});

/// A recorded video in a list (VOD, clip): the thumbnail with its chips,
/// length and progress, then the title and details. A row beside its text
/// (board VideosChaine, VideosSuivies), or a [tile] with the text under it
/// (board VideosSuiviesTablette). The card sinks under the finger; a long
/// press on the picture enlarges it.
class VideoCardLayout extends StatelessWidget {
  const VideoCardLayout({
    super.key,
    required this.thumbnailUrl,
    required this.fallback,
    required this.lengthLabel,
    required this.title,
    required this.onTap,
    this.topChips = const [],
    this.progress,
    this.subtitle,
    this.channelLogin,
    this.details,
    this.footer,
    this.sidePadding = 16,
    this.tile = false,
    this.semanticsLabel,
  });

  /// The card's sides (before the window's insets): none in a column that
  /// has its own.
  final double sidePadding;

  /// Null when there is no usable image yet ([fallback] is shown).
  final String? thumbnailUrl;
  final VideoCardFallback fallback;

  /// Bottom-right chip ("1:02:05", "0:30").
  final String lengthLabel;
  final List<Widget> topChips;

  /// Resume point as a fraction of the length, drawn along the bottom.
  final double? progress;
  final String title;

  /// The category line, or the channel's name.
  final String? subtitle;

  /// The channel the [subtitle] names: its picture goes beside the name
  /// (a row) or the title (a tile).
  final String? channelLogin;

  /// "2 days ago · 1,500 views".
  final String? details;
  final Widget? footer;
  final VoidCallback onTap;

  /// The picture on top, the text under it, for a grid.
  final bool tile;

  /// What a screen reader says for the whole card (its text otherwise).
  final String? semanticsLabel;

  /// The row's picture on a phone (board VideosChaine: 152 × 86).
  static const rowThumbnailWidth = 152.0;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final insets = MediaQuery.paddingOf(context);
    final content = tile ? _tile(context, colors) : _row(context, colors);
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: tile
                ? EdgeInsets.fromLTRB(
                    10 + insets.left,
                    10,
                    10 + insets.right,
                    10,
                  )
                : EdgeInsets.fromLTRB(
                    sidePadding + insets.left,
                    8,
                    sidePadding + insets.right,
                    8,
                  ),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, FeedColors colors) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The board's 152 dp on a phone; a wider row (a tablet's) gives the
        // picture more, up to 240.
        final width = math.min(
          240.0,
          math.max(rowThumbnailWidth, constraints.maxWidth * 0.36),
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            SizedBox(
              width: width,
              child: _VideoPicture(
                url: thumbnailUrl,
                fallback: fallback,
                lengthLabel: lengthLabel,
                chips: topChips,
                progress: progress,
                radius: 12,
                large: false,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: _text(colors, large: false),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tile(BuildContext context, FeedColors colors) {
    final login = channelLogin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        _VideoPicture(
          url: thumbnailUrl,
          fallback: fallback,
          lengthLabel: lengthLabel,
          chips: topChips,
          progress: progress,
          radius: 14,
          large: true,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            if (login != null && login.isNotEmpty)
              ProfilePicture(userLogin: login, radius: 16),
            Expanded(child: _text(colors, large: true)),
          ],
        ),
      ],
    );
  }

  Widget _text(FeedColors colors, {required bool large}) {
    final subtitle = this.subtitle;
    final details = this.details;
    final login = channelLogin;
    final subtitleStyle = TextStyle(
      fontFamily: FrostyTokens.bodyFamily,
      fontSize: large ? 13 : 12.5,
      height: 1.3,
      color: login != null ? colors.body : colors.secondary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: !large && login != null ? 4 : 3,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: FrostyTokens.bodyFamily,
            fontSize: large ? 14.5 : 14,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: colors.text,
          ),
        ),
        if (subtitle != null)
          // A row names the channel with its picture (board VideosSuivies);
          // a tile has it beside the title already.
          !large && login != null && login.isNotEmpty
              ? Row(
                  spacing: 6,
                  children: [
                    ProfilePicture(userLogin: login, radius: 8),
                    Flexible(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: subtitleStyle,
                      ),
                    ),
                  ],
                )
              : Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: subtitleStyle,
                ),
        if (details != null)
          Text(
            details,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FrostyType.tabular(
              TextStyle(
                fontFamily: FrostyTokens.bodyFamily,
                fontSize: 12.5,
                height: 1.3,
                color: colors.tertiary,
              ),
            ),
          ),
        ?footer,
      ],
    );
  }
}

/// A video's picture: the image (or the fallback), the chips at the top
/// left, the length at the bottom right and the progress along the bottom.
class _VideoPicture extends StatelessWidget {
  const _VideoPicture({
    required this.url,
    required this.fallback,
    required this.lengthLabel,
    required this.chips,
    required this.progress,
    required this.radius,
    required this.large,
  });

  final String? url;
  final VideoCardFallback fallback;
  final String lengthLabel;
  final List<Widget> chips;
  final double? progress;
  final double radius;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final borderRadius = BorderRadius.circular(radius);
    final url = this.url;
    final progress = this.progress;
    final inset = large ? 6.0 : 5.0;
    final label = fallback.label;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: colors.well),
            if (url == null)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 4,
                children: [
                  VideoGlyph(fallback.glyph, color: colors.tertiary),
                  if (label != null)
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: FrostyTokens.bodyFamily,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: colors.tertiary,
                      ),
                    ),
                ],
              )
            else
              Semantics(
                container: true,
                image: true,
                label: 'Thumbnail',
                onLongPressHint: 'enlarge',
                child: GestureDetector(
                  onLongPress: () {
                    HapticFeedback.lightImpact();
                    showDialog(
                      context: context,
                      builder: (context) =>
                          FrostyPhotoViewDialog(imageUrl: url),
                    );
                  },
                  child: FrostyCachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        SkeletonLoader(borderRadius: borderRadius),
                  ),
                ),
              ),
            InsetHairline(borderRadius: borderRadius),
            if (chips.isNotEmpty)
              Positioned(
                left: inset,
                top: inset,
                child: Row(spacing: 4, children: chips),
              ),
            Positioned(
              right: inset,
              bottom: progress == null ? inset : inset + 3,
              child: VideoCardChip(
                large: large,
                ring: false,
                child: Text(lengthLabel),
              ),
            ),
            if (progress != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 3,
                child: ColoredBox(
                  color: const Color(0x2EFFFFFF),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: ColoredBox(color: context.frostyColors.live),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A row card loading (board VideosChaine): the picture and three lines,
/// under the global sheen.
class VideoRowSkeleton extends StatelessWidget {
  const VideoRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final radius = BorderRadius.circular(6);
    return Padding(
      padding: EdgeInsets.fromLTRB(16 + insets.left, 8, 16 + insets.right, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          SizedBox(
            width: VideoCardLayout.rowThumbnailWidth,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: SkeletonLoader(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                const SizedBox(height: 2),
                SkeletonLoader(height: 12, borderRadius: radius),
                FractionallySizedBox(
                  widthFactor: 0.6,
                  child: SkeletonLoader(height: 10, borderRadius: radius),
                ),
                FractionallySizedBox(
                  widthFactor: 0.45,
                  child: SkeletonLoader(height: 10, borderRadius: radius),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A tile loading (board VideosSuiviesTablette).
class VideoTileSkeleton extends StatelessWidget {
  const VideoTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final radius = BorderRadius.circular(6);
    return Padding(
      padding: EdgeInsets.fromLTRB(10 + insets.left, 10, 10 + insets.right, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: SkeletonLoader(borderRadius: BorderRadius.circular(14)),
          ),
          FractionallySizedBox(
            widthFactor: 0.8,
            child: SkeletonLoader(height: 12, borderRadius: radius),
          ),
          FractionallySizedBox(
            widthFactor: 0.5,
            child: SkeletonLoader(height: 10, borderRadius: radius),
          ),
        ],
      ),
    );
  }
}

/// "Subscribers only" under a video's details (the community green).
class SubscribersOnlyLabel extends StatelessWidget {
  const SubscribersOnlyLabel({super.key});

  @override
  Widget build(BuildContext context) => Text(
    'Subscribers only',
    style: TextStyle(
      fontFamily: FrostyTokens.bodyFamily,
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: Theme.of(context).brightness == Brightness.dark
          ? FrostyTokens.hypeText
          : FrostyColors.light.subNoticeText,
    ),
  );
}

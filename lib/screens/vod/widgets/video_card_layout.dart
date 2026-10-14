import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';
import 'package:frosty/widgets/frosty_photo_view_dialog.dart';
import 'package:frosty/widgets/skeleton_loader.dart';

/// A small label over a video thumbnail (length, "Watched", views…).
class VideoCardChip extends StatelessWidget {
  const VideoCardChip({super.key, required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(3),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color: color ?? Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.08),
        width: 0.5,
      ),
    ),
    child: DefaultTextStyle.merge(
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: videoCardOnImage(context),
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      child: child,
    ),
  );
}

/// Text and icon colour over a thumbnail.
Color videoCardOnImage(BuildContext context) =>
    Theme.of(context).extension<FrostyColors>()?.overlayOnSurface ??
    Colors.white;

/// A recorded video in a list (VOD, clip), laid out like the live stream
/// cards: the thumbnail with its length chip, then the title and details.
class VideoCardLayout extends StatelessWidget {
  const VideoCardLayout({
    super.key,
    required this.thumbnailUrl,
    required this.fallbackIcon,
    required this.lengthLabel,
    required this.title,
    required this.onTap,
    this.topChips = const [],
    this.progress,
    this.subtitle,
    this.details,
    this.footer,
  });

  /// Null when there is no usable image yet ([fallbackIcon] is shown).
  final String? thumbnailUrl;
  final IconData fallbackIcon;

  /// Bottom-right chip ("1:02:05", "0:30").
  final String lengthLabel;
  final List<Widget> topChips;

  /// Resume point as a fraction of the length, drawn along the bottom.
  final double? progress;
  final String title;

  /// The category line.
  final String? subtitle;

  /// "2 days ago · 1,500 views".
  final String? details;
  final Widget? footer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final onImage = videoCardOnImage(context);
    final fontColor = DefaultTextStyle.of(context).style.color;
    final mutedColor = fontColor?.withValues(alpha: 0.8);
    const subFontSize = 14.0;
    final url = thumbnailUrl;

    final thumbnail = AspectRatio(
      aspectRatio: 16 / 9,
      child: url == null
          ? ColoredBox(
              color: colors.surfaceContainer,
              child: Icon(fallbackIcon, color: colors.onSurfaceVariant),
            )
          : FrostyCachedNetworkImage(
              imageUrl: url,
              placeholder: (context, url) =>
                  const SkeletonLoader(borderRadius: kCardBorderRadius),
            ),
    );

    final progressValue = progress;
    final imageSection = ClipRRect(
      borderRadius: kCardBorderRadius,
      child: Stack(
        children: [
          Semantics(
            container: url != null,
            image: url != null,
            label: url == null ? null : 'Thumbnail',
            onLongPressHint: url == null ? null : 'enlarge',
            child: GestureDetector(
              onLongPress: url == null
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      showDialog(
                        context: context,
                        builder: (context) =>
                            FrostyPhotoViewDialog(imageUrl: url),
                      );
                    },
              child: thumbnail,
            ),
          ),
          Positioned(
            right: 0,
            bottom: progressValue == null ? 0 : 3,
            child: VideoCardChip(child: Text(lengthLabel)),
          ),
          Positioned(left: 0, top: 0, child: Row(children: topChips)),
          if (progressValue != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 3,
              child: ColoredBox(
                color: onImage.withValues(alpha: 0.3),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progressValue.clamp(0.0, 1.0),
                  child: ColoredBox(color: colors.primary),
                ),
              ),
            ),
        ],
      ),
    );

    final infoSection = Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Tooltip(
            message: title,
            preferBelow: false,
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: fontColor,
              ),
            ),
          ),
          if (subtitle case final subtitle?)
            Text(
              subtitle,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: subFontSize, color: mutedColor),
            ),
          if (details case final details?)
            Text(
              details,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: subFontSize,
                color: mutedColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ?footer,
        ],
      ),
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(
          top: 8,
          bottom: 8,
          left: 16 + MediaQuery.of(context).padding.left,
          right: 16 + MediaQuery.of(context).padding.right,
        ),
        child: Row(
          children: [
            Flexible(child: imageSection),
            Flexible(flex: 2, child: infoSection),
          ],
        ),
      ),
    );
  }
}

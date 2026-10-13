import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/vod/vod_screen.dart';
import 'package:frosty/screens/vod/vod_time.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';
import 'package:frosty/widgets/frosty_photo_view_dialog.dart';
import 'package:frosty/widgets/skeleton_loader.dart';
import 'package:intl/intl.dart';

/// A past broadcast, highlight or upload in a list, laid out like the live
/// stream cards: thumbnail with its length, then title and details.
class VodCard extends StatelessWidget {
  const VodCard({
    super.key,
    required this.vod,
    this.progress,
    this.watched = false,
    this.onTap,
  });

  final Vod vod;

  /// Saved resume point as a fraction of the length, drawn on the thumbnail.
  final double? progress;

  /// Watched to the end.
  final bool watched;

  /// Defaults to opening the VOD in-app.
  final VoidCallback? onTap;

  /// Twitch serves a "processing" image for videos still being encoded.
  String? get _thumbnailUrl {
    final url = vod.previewThumbnailUrl;
    if (url == null || url.isEmpty || url.contains('404_processing')) {
      return null;
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final onImage =
        Theme.of(context).extension<FrostyColors>()?.overlayOnSurface ??
        Colors.white;
    final fontColor = DefaultTextStyle.of(context).style.color;
    final mutedColor = fontColor?.withValues(alpha: 0.8);
    const subFontSize = 14.0;
    final url = _thumbnailUrl;

    Widget chip(Widget child, {Color? color}) => Container(
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
          color: onImage,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        child: child,
      ),
    );

    final thumbnail = AspectRatio(
      aspectRatio: 16 / 9,
      child: url == null
          ? ColoredBox(
              color: colors.surfaceContainer,
              child: Icon(
                Icons.video_library_outlined,
                color: colors.onSurfaceVariant,
              ),
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
          GestureDetector(
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
          Positioned(
            right: 0,
            bottom: progressValue == null ? 0 : 3,
            child: chip(Text(formatVodTime(vod.duration))),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Row(
              children: [
                if (vod.isRecording)
                  chip(
                    const Text('Recording'),
                    color: colors.error.withValues(alpha: 0.9),
                  ),
                if (watched) chip(const Text('Watched')),
                if (vod.isRestricted)
                  chip(Icon(Icons.lock_rounded, size: 12, color: onImage)),
              ],
            ),
          ),
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

    final title = vod.title.trim().isEmpty ? 'Untitled' : vod.title.trim();
    final details = [
      formatTimeAgo(vod.createdAt),
      '${NumberFormat().format(vod.viewCount)} '
          '${vod.viewCount == 1 ? 'view' : 'views'}',
    ].join(' · ');

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
          if (vod.gameName case final game?)
            Text(
              game,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: subFontSize, color: mutedColor),
            ),
          Text(
            details,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: subFontSize,
              color: mutedColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (vod.isRestricted)
            Text(
              'Subscribers only',
              style: TextStyle(fontSize: subFontSize, color: colors.primary),
            ),
        ],
      ),
    );

    return InkWell(
      onTap: onTap ?? () => VodScreen.open(context, vodId: vod.id, vod: vod),
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

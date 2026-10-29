import 'package:flutter/material.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/home/top/categories/category_streams.dart';
import 'package:onset/screens/vod/widgets/video_glyph.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/press_scale.dart';

/// "● synced to video": the signal pill beside a replay's title (boards
/// Rediff, Clips).
class SyncedPill extends StatelessWidget {
  const SyncedPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final accent = context.frostyColors.live;
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: ShapeDecoration(
        color: accent.withValues(alpha: 0.10),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 5,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: FrostyTokens.bodyFamily,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A 40 dp pill action under a video ("Copy link", "Watch full video",
/// "Speed 1.25×"): raised grey, or tinted with the signal when [selected].
class VideoActionPill extends StatelessWidget {
  const VideoActionPill({
    super.key,
    required this.label,
    required this.onTap,
    this.glyph,
    this.selected = false,
    this.raised = false,
    this.semanticsLabel,
  });

  final String label;
  final VoidCallback? onTap;
  final VideoGlyphKind? glyph;
  final bool selected;

  /// On #1E1E1E (the clip screen) instead of the surface (#141414).
  final bool raised;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final accent = context.frostyColors.live;
    final foreground = selected ? accent : colors.text;
    final glyph = this.glyph;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      child: PressScale(
        enabled: onTap != null,
        child: Material(
          color: selected
              ? accent.withValues(alpha: 0.10)
              : raised
              ? colors.raised
              : colors.surface,
          shape: StadiumBorder(
            side: BorderSide(
              color: selected
                  ? accent
                  : raised && dark
                  ? FrostyTokens.hairlineStrongDark
                  : colors.pillBorder,
              width: FrostyTokens.hairlineWidth,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 7,
                children: [
                  if (glyph != null)
                    VideoGlyph(
                      glyph,
                      color: foreground,
                      size: 16,
                      strokeWidth: 1.9,
                    ),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FrostyType.tabular(
                        TextStyle(
                          fontFamily: FrostyTokens.bodyFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          color: foreground,
                        ),
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
  }
}

/// A video's category as a pill (28 dp) that opens its streams.
class VideoCategoryChip extends StatelessWidget {
  const VideoCategoryChip({
    super.key,
    required this.name,
    required this.gameId,
    this.height = 28,
  });

  final String name;
  final String gameId;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    return Semantics(
      button: true,
      label: name,
      excludeSemantics: true,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: CategoryStreams.routeName),
              builder: (context) => CategoryStreams(categoryId: gameId),
            ),
          ),
          child: SizedBox(
            height: 44,
            child: Center(
              widthFactor: 1,
              child: Container(
                height: height,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: colors.surface,
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: colors.pillBorder,
                      width: FrostyTokens.hairlineWidth,
                    ),
                  ),
                ),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: FrostyTokens.bodyFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: colors.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A short status in a video pane ("No messages yet", "Chat replay is
/// unavailable…"), with "Try again" when it can be retried.
class VideoPaneNotice extends StatelessWidget {
  const VideoPaneNotice({
    super.key,
    required this.message,
    this.onRetry,
    this.glyph,
  });

  final String message;
  final VoidCallback? onRetry;
  final VideoGlyphKind? glyph;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final glyph = this.glyph;
    final retry = onRetry;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            if (glyph != null)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.pillBorder,
                    width: FrostyTokens.hairlineWidth,
                  ),
                ),
                child: Center(
                  child: VideoGlyph(glyph, color: colors.secondary),
                ),
              ),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: FrostyTokens.bodyFamily,
                fontSize: 13.5,
                height: 1.45,
                color: colors.secondary,
              ),
            ),
            if (retry != null)
              TextButton.icon(
                onPressed: retry,
                style: TextButton.styleFrom(
                  foregroundColor: colors.text,
                  backgroundColor: colors.raised,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: colors.pillBorder,
                      width: FrostyTokens.hairlineWidth,
                    ),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: FrostyTokens.bodyFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Try again'),
              ),
          ],
        ),
      ),
    );
  }
}

/// "TODAY", "UP NEXT IN CLIPS": a section's label (11 / 600, wide tracking,
/// upper case, the secondary grey).
class VideoSectionLabel extends StatelessWidget {
  const VideoSectionLabel(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 6),
  });

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: FrostyTokens.bodyFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.54,
          height: 1.3,
          color: FeedColors.of(context).secondary,
        ),
      ),
    ),
  );
}

/// An empty list of videos (board VideosChaine): the camera in a tile,
/// what is missing, "Pull down to check again."
class VideoListEmpty extends StatelessWidget {
  const VideoListEmpty({
    super.key,
    required this.message,
    this.hint = 'Pull down to check again.',
  });

  final String message;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final hint = this.hint;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.hairline,
                width: FrostyTokens.hairlineWidth,
              ),
            ),
            child: Center(
              child: VideoGlyph(
                VideoGlyphKind.cameraAdd,
                color: colors.secondary,
                size: 24,
              ),
            ),
          ),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: FrostyTokens.bodyFamily,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
          if (hint != null)
            Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: FrostyTokens.bodyFamily,
                fontSize: 13,
                height: 1.5,
                color: colors.secondary,
              ),
            ),
        ],
      ),
    );
  }
}

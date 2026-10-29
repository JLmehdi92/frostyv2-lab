import 'package:flutter/material.dart';
import 'package:frosty/screens/vod/widgets/video_glyph.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/widgets/motion/press_scale.dart';

/// The player's back chevron alone (boards Rediff, Clips): over a player
/// that has no controls yet (loading, an error, Twitch's own warning in the
/// web player).
class VideoBackButton extends StatelessWidget {
  const VideoBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Back',
      child: PressScale(
        child: IconButton(
          onPressed: () => Navigator.maybePop(context),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          style: IconButton.styleFrom(
            foregroundColor: FrostyTokens.textPrimaryDark,
            highlightColor: const Color(0x1FFFFFFF),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const VideoGlyph(
            VideoGlyphKind.back,
            color: FrostyTokens.textPrimaryDark,
            size: 22,
            strokeWidth: 2,
            shadow: true,
          ),
        ),
      ),
    );
  }
}

/// [child] with [VideoBackButton] at the top left, where the controls put
/// it.
class VideoBackButtonLayer extends StatelessWidget {
  const VideoBackButtonLayer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      child,
      const Positioned(left: 4, top: 4, child: VideoBackButton()),
    ],
  );
}

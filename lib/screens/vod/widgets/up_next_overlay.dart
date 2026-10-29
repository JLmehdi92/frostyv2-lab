import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/vod/stores/up_next_store.dart';
import 'package:onset/screens/vod/vod_time.dart';
import 'package:onset/screens/vod/widgets/video_glyph.dart';
import 'package:onset/screens/vod/widgets/vod_card.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/frosty_cached_network_image.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';

/// The official app's Up Next card over the ended video (board Rediff):
/// "UP NEXT" and the seconds left, Cancel, the next video's picture, title
/// and channel, and "Play now" in a ring that closes over the countdown.
/// Without autoplay it waits for the viewer, without a countdown. Dark
/// gradients only, never a blur over the video.
class UpNextOverlay extends StatelessWidget {
  const UpNextOverlay({super.key, required this.store});

  final UpNextStore store;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final phase = store.phase;
        final next = store.next;
        final counting = phase == UpNextPhase.countdown;
        if (next == null || (!counting && phase != UpNextPhase.waiting)) {
          return const SizedBox.shrink();
        }
        return Positioned.fill(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: motionDuration(
              context,
              const Duration(milliseconds: 220),
            ),
            builder: (context, t, child) => Opacity(opacity: t, child: child),
            child: _UpNextCard(
              next: next,
              similar: store.similar,
              counting: counting,
              secondsLeft: store.secondsLeft,
              onCancel: store.cancel,
              onPlayNow: store.playNow,
            ),
          ),
        );
      },
    );
  }
}

class _UpNextCard extends StatelessWidget {
  const _UpNextCard({
    required this.next,
    required this.similar,
    required this.counting,
    required this.secondsLeft,
    required this.onCancel,
    required this.onPlayNow,
  });

  final Vod next;
  final bool similar;
  final bool counting;
  final int secondsLeft;
  final VoidCallback onCancel;
  final VoidCallback onPlayNow;

  static const _text = FrostyTokens.textPrimaryDark;
  static const _secondary = FrostyTokens.textSecondaryDark;

  @override
  Widget build(BuildContext context) {
    final channel = next.ownerDisplayName.isNotEmpty
        ? next.ownerDisplayName
        : next.ownerLogin;
    final title = next.title.trim().isEmpty ? 'Untitled' : next.title.trim();
    final thumbnail = vodThumbnailUrl(next);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xEB0A0A0A), Color(0xD60A0A0A)],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // A short player keeps the header and the play button.
            final roomy = constraints.maxHeight >= 150;
            final wide = constraints.maxWidth >= 360;
            return SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  SizedBox(
                    height: 36,
                    child: Row(
                      spacing: 8,
                      children: [
                        Text(
                          'Up Next'.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: FrostyTokens.bodyFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.54,
                            color: _secondary,
                          ),
                        ),
                        if (counting)
                          Text(
                            '$secondsLeft '
                            '${secondsLeft == 1 ? 'second' : 'seconds'}',
                            style: FrostyType.tabular(
                              const TextStyle(
                                fontFamily: FrostyTokens.bodyFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _text,
                              ),
                            ),
                          ),
                        const Spacer(),
                        TextButton(
                          onPressed: onCancel,
                          style: TextButton.styleFrom(
                            foregroundColor: _text,
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontFamily: FrostyTokens.bodyFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    spacing: 12,
                    children: [
                      if (roomy && wide)
                        _Picture(
                          url: thumbnail,
                          length: formatVodTime(next.duration),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 3,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: FrostyTokens.bodyFamily,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                                color: _text,
                              ),
                            ),
                            Text(
                              similar ? '$channel · Similar video' : channel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: FrostyTokens.bodyFamily,
                                fontSize: 12,
                                color: _secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _PlayNowButton(
                        counting: counting,
                        secondsLeft: secondsLeft,
                        onPressed: onPlayNow,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The next video's picture (132 × 74) with its length.
class _Picture extends StatelessWidget {
  const _Picture({required this.url, required this.length});

  final String? url;
  final String length;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    final radius = BorderRadius.circular(10);
    return SizedBox(
      width: 132,
      height: 74,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: FrostyTokens.surfaceDark),
            if (url != null)
              FrostyCachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
            InsetHairline(borderRadius: radius),
            Positioned(
              right: 5,
              bottom: 5,
              child: OverlayPill(
                height: 18,
                radius: 5,
                padding: 5,
                child: Text(
                  length,
                  style: FrostyType.tabular(
                    const TextStyle(
                      fontFamily: FrostyTokens.bodyFamily,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Play now" in a 56 dp disc, its ring closing over the countdown.
class _PlayNowButton extends StatelessWidget {
  const _PlayNowButton({
    required this.counting,
    required this.secondsLeft,
    required this.onPressed,
  });

  final bool counting;
  final int secondsLeft;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const total = UpNextStoreBase.countdownSeconds;
    final accent = context.frostyColors.live;
    // The ring empties over the seconds, smoothly between the ticks (to
    // where the next tick lands).
    final target = counting ? ((secondsLeft - 1) / total).clamp(0.0, 1.0) : 0.0;
    return Tooltip(
      message: 'Play now',
      child: PressScale(
        child: Material(
          color: FrostyTokens.raisedDark,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(
              dimension: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: target),
                    duration: reduceMotionOf(context)
                        ? Duration.zero
                        : const Duration(seconds: 1),
                    curve: FrostyMotion.standard,
                    builder: (context, value, _) => CustomPaint(
                      size: const Size.square(56),
                      painter: _RingPainter(
                        fraction: counting ? value : 0,
                        color: accent,
                      ),
                    ),
                  ),
                  const VideoGlyph(
                    VideoGlyphKind.playNext,
                    color: FrostyTokens.textPrimaryDark,
                    size: 22,
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

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.fraction, required this.color});

  /// How much of the countdown is left, 1 to 0.
  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: 26);
    canvas.drawCircle(
      rect.center,
      26,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0x1AFFFFFF),
    );
    if (fraction <= 0) return;
    canvas.drawArc(
      rect,
      -1.5707963267948966,
      6.283185307179586 * fraction,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color;
}

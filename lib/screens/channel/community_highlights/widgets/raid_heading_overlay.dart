import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:onset/models/raid_arrival.dart';
import 'package:onset/screens/channel/community_highlights/raid_text.dart';
import 'package:onset/screens/channel/community_highlights/widgets/raid_avatar.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';

/// When the channel switches after "Go now" (or the raid leaving): long
/// enough for the hit on the card and the overlay to read.
const kRaidDepartureDelay = Duration(milliseconds: 1350);

/// The same under reduce motion: a short fade, then the switch.
const kRaidDepartureDelayReduced = Duration(milliseconds: 700);

/// How long the overlay takes to fade out on the channel arrived at (its
/// 150 ms hold and 300 ms fade, and a frame to spare).
const kRaidArrivalFade = Duration(milliseconds: 500);

/// The raid overlays of the channel screen, over the video: leaving
/// ([departure]) or arriving ([arrival]); never in the PiP window. A
/// departure called off fades out.
class RaidOverlayLayer extends StatelessWidget {
  const RaidOverlayLayer({
    super.key,
    this.departure,
    this.arrival,
    this.inPip = false,
  });

  final RaidArrival? departure;
  final RaidArrival? arrival;
  final bool inPip;

  @override
  Widget build(BuildContext context) {
    final departure = this.departure;
    final arrival = this.arrival;
    final Widget child;
    if (inPip) {
      child = const SizedBox.shrink();
    } else if (departure != null) {
      child = RaidHeadingOverlay(
        key: const ValueKey('raid-leaving'),
        arrival: departure,
        leaving: true,
      );
    } else if (arrival != null) {
      child = RaidHeadingOverlay(
        key: const ValueKey('raid-arriving'),
        arrival: arrival,
        leaving: false,
      );
    } else {
      child = const SizedBox.shrink();
    }
    return AnimatedSwitcher(
      duration: motionDuration(context, const Duration(milliseconds: 200)),
      // Out at once into PiP; a called-off departure fades.
      reverseDuration: inPip ? Duration.zero : null,
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      child: child,
    );
  }
}

/// "Heading to Y" over the video: an opaque scrim — never a
/// blur over the video —, the target's picture inside a lime ring that
/// sweeps around it, and "N viewers coming with you".
///
/// [leaving] plays it in on the channel being left (after the card's hit,
/// 380 ms in); otherwise it starts shown on the channel arrived at and
/// fades out, then calls [onDone]. Under reduce motion it only fades.
/// It never takes a tap.
class RaidHeadingOverlay extends StatefulWidget {
  const RaidHeadingOverlay({
    super.key,
    required this.arrival,
    required this.leaving,
    this.onDone,
  });

  final RaidArrival arrival;
  final bool leaving;
  final VoidCallback? onDone;

  static const scrimKey = ValueKey('raid-heading-scrim');

  @override
  State<RaidHeadingOverlay> createState() => _RaidHeadingOverlayState();
}

class _RaidHeadingOverlayState extends State<RaidHeadingOverlay>
    with SingleTickerProviderStateMixin {
  // Leaving: the whole entrance, 1.4 s. Arriving: a 150 ms hold, then a
  // 300 ms fade.
  static const _leaving = Duration(milliseconds: 1400);
  static const _arriving = Duration(milliseconds: 450);

  late final AnimationController _controller = AnimationController(vsync: this);
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduce = reduceMotionOf(context);
    _controller.duration = widget.leaving
        ? (reduce ? OnsetMotion.reducedFade : _leaving)
        : (reduce ? OnsetMotion.reducedFade : _arriving);
    _controller.forward().whenCompleteOrCancel(() {
      if (mounted && !widget.leaving) widget.onDone?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// [from]..[to] of the leaving timeline (ms), eased.
  double _phase(double ms, double from, double to, Curve curve) =>
      curve.transform(((ms - from) / (to - from)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    final arrival = widget.arrival;
    return IgnorePointer(
      child: RepaintBoundary(
        child: Semantics(
          liveRegion: true,
          label: 'Heading to ${arrival.targetName}',
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final v = _controller.value;
              final double fade;
              var avatar = 1.0;
              var ring = 1.0;
              var text = 1.0;
              if (!widget.leaving) {
                fade = reduce ? 1 - v : 1 - ((v * 450 - 150) / 300).clamp(0, 1);
              } else if (reduce) {
                fade = v;
              } else {
                final ms = v * _leaving.inMilliseconds;
                fade = _phase(ms, 380, 600, Curves.ease);
                avatar = _phase(ms, 440, 1080, OnsetMotion.standard);
                ring = _phase(ms, 500, 1400, Curves.fastOutSlowIn);
                text = _phase(ms, 640, 960, OnsetMotion.standard);
              }
              if (fade <= 0) return const SizedBox.shrink();
              return Opacity(
                opacity: fade,
                child: ColoredBox(
                  key: RaidHeadingOverlay.scrimKey,
                  color: OnsetTokens.backgroundDark.withValues(alpha: 0.9),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 14,
                          children: [
                            SizedBox.square(
                              dimension: 92,
                              child: CustomPaint(
                                painter: _SweepPainter(progress: ring),
                                child: Center(
                                  child: Opacity(
                                    opacity: avatar,
                                    child: Transform.scale(
                                      scale: 0.6 + 0.4 * avatar,
                                      child: RaidAvatar(
                                        name: arrival.targetName,
                                        url: arrival.targetAvatarUrl,
                                        size: 72,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Opacity(
                              opacity: text,
                              child: Transform.translate(
                                offset: Offset(0, 6 * (1 - text)),
                                child: ExcludeSemantics(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    spacing: 3,
                                    children: [
                                      Text(
                                        'Heading to ${arrival.targetName}',
                                        style: const TextStyle(
                                          fontFamily: OnsetTokens.bodyFamily,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: OnsetTokens.textPrimaryDark,
                                        ),
                                      ),
                                      Text(
                                        '${raidViewers(arrival.viewers)} coming with you',
                                        style: const TextStyle(
                                          fontFamily: OnsetTokens.bodyFamily,
                                          fontSize: 12.5,
                                          color: OnsetTokens.textSecondaryDark,
                                        ),
                                      ),
                                    ],
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
            },
          ),
        ),
      ),
    );
  }
}

/// The 92 dp ring: a faint lime track and the lime sweep from the top.
class _SweepPainter extends CustomPainter {
  const _SweepPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: 40);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      paint..color = OnsetTokens.accent.withValues(alpha: 0.16),
    );
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      paint
        ..color = OnsetTokens.accent
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SweepPainter old) => old.progress != progress;
}

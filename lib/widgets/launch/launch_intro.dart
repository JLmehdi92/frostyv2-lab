import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/launch/onset_mark.dart';
import 'package:frosty/widgets/motion/motion.dart';
import 'package:frosty/widgets/motion/reduce_motion.dart';
import 'package:frosty/widgets/motion/staggered_entrance.dart';

/// The launch intro of the boards "Lancement" (phone), "LancementTablette"
/// and "Storyboard", drawn over the app on a cold start:
///
/// 0 ms the signal dot lights up → it grows into the tile with a small
/// overshoot → "ON" appears and two rings leave the tile → O-N-S-E-T rise
/// one by one over a signal underline → the tile flies to its place in the
/// header → the ground clears and the home cards come in, 60 ms apart.
/// 1.4 s in all.
///
/// - Never blocks loading: [child] (the app) is built from the first frame
///   underneath, and only its [StaggeredEntrance]s wait (an [EntranceGate])
///   until the ground clears.
/// - Plays only when [play] (a cold start), and never under reduce motion or
///   a screen reader. A tap, [skipAll] (a deep link) or leaving the app ends
///   it at once.
/// - [fromTile]: the native splash already showed the tile (Android), so the
///   first frame is that tile and the sequence picks up from there.
/// - [slotKey]: the header's mark, where the tile lands. Without one the
///   tile lands where the boards put it (16 / 28 dp from the left edge, in
///   the header row) and dissolves into the header.
/// - No blur anywhere: fills and a soft shadow only.
class LaunchIntro extends StatefulWidget {
  final Widget child;
  final bool play;
  final bool fromTile;
  final GlobalKey? slotKey;
  final VoidCallback? onFinished;

  const LaunchIntro({
    super.key,
    required this.child,
    this.play = false,
    this.fromTile = false,
    this.slotKey,
    this.onFinished,
  });

  /// The whole sequence (the storyboard's 1 400 ms).
  static const duration = Duration(milliseconds: 1400);

  @visibleForTesting
  static const overlayKey = ValueKey('launch-intro');
  @visibleForTesting
  static const tileKey = ValueKey('launch-intro-tile');
  @visibleForTesting
  static const ringKeys = [
    ValueKey('launch-intro-ring-1'),
    ValueKey('launch-intro-ring-2'),
  ];

  static final _running = <_LaunchIntroState>{};

  /// Ends any running intro at once (the app was opened on a channel).
  static void skipAll() {
    for (final intro in _running.toList()) {
      intro._finish();
    }
  }

  @override
  State<LaunchIntro> createState() => _LaunchIntroState();
}

/// Where each step sits on the 0–1 timeline. The fractions are the boards'
/// keyframes (written for 1.9 s), played over [LaunchIntro.duration].
abstract final class _Timeline {
  static const dotEnd = 0.08;
  static const tileEnd = 0.26;
  static const markStart = 0.18;
  static const markEnd = 0.30;
  static const ring1Start = 0.26;
  static const ring1End = 0.46;
  static const ring2Start = 0.32;
  static const ring2End = 0.54;
  static const letterStart = 0.30;
  static const letterEnd = 0.42;
  static const letterStep = 35 / 1900;
  static const underlineStart = 0.40;
  static const underlineEnd = 0.54;
  static const nameOutStart = 0.60;
  static const nameOutEnd = 0.70;
  static const flightStart = 0.58;
  static const flightEnd = 0.78;
  static const groundOutStart = 0.68;
  static const groundOutEnd = 0.80;
  static const reveal = 0.70;
  static const tileOutStart = 0.74;
  static const tileOutEnd = 0.86;

  /// Progress through [start]–[end] at [t], through [curve].
  static double span(
    double t,
    double start,
    double end, [
    Curve curve = Curves.linear,
  ]) => curve.transform(((t - start) / (end - start)).clamp(0.0, 1.0));
}

class _LaunchIntroState extends State<LaunchIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _revealed = ValueNotifier<bool>(false);
  AppLifecycleListener? _lifecycle;
  bool _decided = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: LaunchIntro.duration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;

    final screenReader = MediaQuery.maybeAccessibleNavigationOf(context);
    if (!widget.play || reduceMotionOf(context) || screenReader == true) {
      _done = true;
      _revealed.value = true;
      return;
    }

    LaunchIntro._running.add(this);
    _lifecycle = AppLifecycleListener(
      onInactive: _finish,
      onHide: _finish,
      onPause: _finish,
    );
    _controller
      ..addListener(_onTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      })
      ..forward(from: widget.fromTile ? _Timeline.tileEnd : 0);
  }

  void _onTick() {
    if (!_revealed.value && _controller.value >= _Timeline.reveal) {
      _revealed.value = true;
    }
  }

  void _finish() {
    if (_done) return;
    LaunchIntro._running.remove(this);
    _lifecycle?.dispose();
    _lifecycle = null;
    _controller.stop();
    _revealed.value = true;
    if (mounted) setState(() => _done = true);
    widget.onFinished?.call();
  }

  @override
  void dispose() {
    LaunchIntro._running.remove(this);
    _lifecycle?.dispose();
    _controller.dispose();
    _revealed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        EntranceGate(open: _revealed, child: widget.child),
        if (!_done)
          Positioned.fill(
            key: LaunchIntro.overlayKey,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _finish,
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => _IntroFrame(
                      t: _controller.value,
                      fromTile: widget.fromTile,
                      slot: _slotRect(context),
                      slotIsReal: _hasRealSlot,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  bool get _hasRealSlot =>
      widget.slotKey?.currentContext?.findRenderObject() is RenderBox;

  /// Where the tile lands, in this widget's coordinates: the header's mark
  /// when there is one, else the boards' header slot.
  Rect _slotRect(BuildContext context) {
    final target = widget.slotKey?.currentContext?.findRenderObject();
    final self = context.findRenderObject();
    if (target is RenderBox &&
        target.hasSize &&
        self is RenderBox &&
        self.hasSize) {
      final topLeft = target.localToGlobal(Offset.zero, ancestor: self);
      return topLeft & target.size;
    }
    final top = MediaQuery.paddingOf(context).top;
    return isLargeScreenSize(MediaQuery.sizeOf(context))
        ? Rect.fromLTWH(28, top + 21, 30, 30)
        : Rect.fromLTWH(16, top + 14, 28, 28);
  }
}

/// One frame of the intro at [t] (0–1).
class _IntroFrame extends StatelessWidget {
  final double t;
  final bool fromTile;
  final Rect slot;
  final bool slotIsReal;

  const _IntroFrame({
    required this.t,
    required this.fromTile,
    required this.slot,
    required this.slotIsReal,
  });

  static const _tile = OnsetMark.designSize;
  static const _ground = FrostyTokens.backgroundDark;
  static const _accent = FrostyTokens.accent;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final tablet = isLargeScreenSize(size);
    final center = size.center(Offset.zero);
    const span = _Timeline.span;

    // The tile: a dot, then the tile with an overshoot, then the flight.
    final double grow;
    if (fromTile) {
      grow = 1;
    } else if (t < _Timeline.dotEnd) {
      grow = 0.2 * span(t, 0, _Timeline.dotEnd, FrostyMotion.standard);
    } else {
      grow =
          0.2 +
          0.8 *
              span(
                t,
                _Timeline.dotEnd,
                _Timeline.tileEnd,
                FrostyMotion.overshoot,
              );
    }
    final settle = span(
      t,
      _Timeline.dotEnd,
      _Timeline.tileEnd,
      FrostyMotion.standard,
    );
    final radius = fromTile ? 20.0 : 36 - 16 * settle;
    final flight = span(
      t,
      _Timeline.flightStart,
      _Timeline.flightEnd,
      FrostyMotion.standard,
    );
    final tileCenter = Offset.lerp(center, slot.center, flight)!;
    final tileScale = grow + (slot.width / _tile - 1) * flight;
    final tileOpacity = slotIsReal
        ? 1.0
        : 1 - span(t, _Timeline.tileOutStart, _Timeline.tileOutEnd);
    final markIn = fromTile
        ? 1.0
        : span(t, _Timeline.markStart, _Timeline.markEnd, Curves.ease);
    final glowIn = fromTile
        ? span(t, _Timeline.tileEnd, _Timeline.tileEnd + 0.1)
        : 1.0;

    // The name.
    final nameOut =
        1 - span(t, _Timeline.nameOutStart, _Timeline.nameOutEnd, Curves.ease);
    final letterSize = tablet ? 40.0 : 34.0;
    final letterRise = tablet ? 22.0 : 20.0;
    final underline = span(
      t,
      _Timeline.underlineStart,
      _Timeline.underlineEnd,
      FrostyMotion.standard,
    );

    final ground =
        1 -
        span(t, _Timeline.groundOutStart, _Timeline.groundOutEnd, Curves.ease);

    Widget ring(int index, double start, double end, double width) {
      if (t < start - 0.01) return const SizedBox.shrink();
      final p = span(t, start, end, FrostyMotion.standard);
      final maxScale = switch ((index, tablet)) {
        (0, false) => 2.8,
        (0, true) => 3.2,
        (_, false) => 3.6,
        (_, true) => 4.4,
      };
      final startAlpha = index == 0 ? 0.8 : 0.55;
      return Positioned(
        left: center.dx - _tile / 2,
        top: center.dy - _tile / 2,
        width: _tile,
        height: _tile,
        child: Transform.scale(
          key: LaunchIntro.ringKeys[index],
          scale: 1 + (maxScale - 1) * p,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _accent.withValues(alpha: startAlpha * (1 - p)),
                width: width,
              ),
            ),
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ground > 0.5
          ? SystemUiOverlayStyle.light
          : const SystemUiOverlayStyle(),
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: FrostyTokens.displayFamily,
          decoration: TextDecoration.none,
        ),
        child: IgnorePointer(
          ignoring: ground <= 0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (ground > 0)
                ColoredBox(color: _ground.withValues(alpha: ground)),
              if (t < _Timeline.ring1End)
                ring(0, _Timeline.ring1Start, _Timeline.ring1End, 2),
              if (t < _Timeline.ring2End)
                ring(1, _Timeline.ring2Start, _Timeline.ring2End, 1.5),
              if (nameOut > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  top: center.dy + _tile / 2 + (tablet ? 31 : 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final (i, letter) in 'ONSET'.split('').indexed)
                            _Letter(
                              letter: letter,
                              size: letterSize,
                              progress: span(
                                t,
                                _Timeline.letterStart +
                                    i * _Timeline.letterStep,
                                _Timeline.letterEnd + i * _Timeline.letterStep,
                                FrostyMotion.emphasizedDecelerate,
                              ),
                              rise: letterRise,
                              opacity: nameOut,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: tablet ? 140 : 120,
                        height: 2,
                        child: Transform.scale(
                          scaleX: underline,
                          alignment: Alignment.centerLeft,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _accent.withValues(alpha: nameOut),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Positioned(
                left: tileCenter.dx - _tile / 2,
                top: tileCenter.dy - _tile / 2,
                width: _tile,
                height: _tile,
                child: Transform.scale(
                  scale: tileScale,
                  child: Opacity(
                    key: LaunchIntro.tileKey,
                    opacity: tileOpacity.clamp(0.0, 1.0),
                    child: OnsetMarkTile(
                      radius: radius,
                      markOpacity: markIn,
                      markScale: 0.6 + 0.4 * markIn,
                      glow: [
                        BoxShadow(
                          color: _accent.withValues(alpha: 0.25 * glowIn),
                          blurRadius: tablet ? 48 : 40,
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
    );
  }
}

/// One letter of the wordmark rising into place.
class _Letter extends StatelessWidget {
  final String letter;
  final double size;
  final double progress;
  final double rise;
  final double opacity;

  const _Letter({
    required this.letter,
    required this.size,
    required this.progress,
    required this.rise,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, rise * (1 - progress)),
      child: Text(
        letter,
        style: TextStyle(
          fontFamily: FrostyTokens.displayFamily,
          fontSize: size,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.035 * size,
          height: 1.2,
          color: FrostyTokens.textPrimaryDark.withValues(
            alpha: (progress * opacity).clamp(0.0, 1.0),
          ),
        ),
      ),
    );
  }
}

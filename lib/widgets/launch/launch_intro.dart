import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/launch/onset_mark.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/motion/staggered_entrance.dart';

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
/// - Plays only when [play] (a cold start from the launcher), and never under
///   reduce motion or a screen reader. A tap, [skipAll] (a deep link), any
///   page opening ([navigatorObserver]) or leaving the app ends it at once.
///   Once the ground starts clearing, taps go to the app.
/// - [fromTile]: the native splash already showed the tile (Android), so the
///   first frame is that tile and the sequence picks up from there;
///   [splashTile] is where the splash really drew it, once known.
/// - [slotKey]: the header's mark, where the tile lands. Without one the
///   tile lands where the boards put it (16 / 28 dp from the left edge, in
///   the header row) and dissolves into the header.
/// - [holdOnName] (the first run): the intro stops once the name is drawn,
///   without the flight. The onboarding starts on that very frame (the same
///   tile at the same place, the same black, the name underlined), told
///   where the tile rests by [restingTile].
/// - [land] plays the end of the intro once more when the onboarding hands
///   over to the home: the tile flies into the header and the home comes in.
/// - No blur anywhere: fills and a soft shadow only.
class LaunchIntro extends StatefulWidget {
  final Widget child;
  final bool play;
  final bool fromTile;
  final bool holdOnName;
  final GlobalKey? slotKey;
  final ValueListenable<Rect?>? splashTile;

  const LaunchIntro({
    super.key,
    required this.child,
    this.play = false,
    this.fromTile = false,
    this.holdOnName = false,
    this.slotKey,
    this.splashTile,
  });

  /// The whole sequence (the storyboard's 1 400 ms).
  static const duration = Duration(milliseconds: 1400);

  /// The landing from the onboarding (board Onboarding, its last frame).
  static const landingDuration = Duration(milliseconds: 1400);

  /// The tablet's landing, from the tile already on screen (board
  /// OnboardingTablette).
  static const landingFromTileDuration = Duration(milliseconds: 1250);

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
  static final _mounted = <_LaunchIntroState>{};

  static final _restingTile = ValueNotifier<Rect?>(null);

  /// Where the tile rested when an intro held on the name ([holdOnName])
  /// ended, in the app's coordinates: the onboarding picks it up from there.
  /// Null when no intro held.
  static ValueListenable<Rect?> get restingTile => _restingTile;

  static final _landingNotifier = ValueNotifier(false);

  /// Whether a [land] plays now: a page that would open over the new one
  /// (the release notes) waits until it is false, or it would cut it short.
  static ValueListenable<bool> get landing => _landingNotifier;

  /// Completes once no [land] plays (at once when none does).
  static Future<void> landed() {
    if (!_landingNotifier.value) return Future.value();
    final done = Completer<void>();
    void check() {
      if (_landingNotifier.value) return;
      _landingNotifier.removeListener(check);
      done.complete();
    }

    _landingNotifier.addListener(check);
    return done.future;
  }

  /// Whether a page swap of [land] is under way: its push must not end the
  /// landing.
  static bool _swapping = false;

  static final _runningNotifier = ValueNotifier(false);

  /// Whether an intro covers the app now: what would compete with it for
  /// the device (a live preview's decoder) waits until it is false.
  static ValueListenable<bool> get running => _runningNotifier;

  static void _updateRunning() => _runningNotifier.value = _running.isNotEmpty;

  /// Ends any running intro at once (the app was opened on a channel).
  static void skipAll() => _skipAll();

  /// [fromPush]: a page is being pushed now, so a landing's own swap (a
  /// push too) waits until after this frame.
  static void _skipAll({bool fromPush = false}) {
    for (final intro in _running.toList()) {
      intro._finish(deferCover: fromPush);
    }
  }

  /// Plays the end of the intro over the app once more (the onboarding's
  /// "Let's go!"): the screen fades to the intro's black around the tile at
  /// [from] (popping in first when [appear], as on a phone where the last
  /// step does not show it), [onCovered] swaps the page underneath while it
  /// is black, then the tile flies into the header ([LaunchIntro.slotKey])
  /// and the new page's entrances play as the black clears.
  ///
  /// [onCovered] runs exactly once, also when the landing is cut short (a
  /// tap, leaving the app). Returns false, without calling it, when nothing
  /// can play: no intro mounted, reduce motion or a screen reader. The
  /// caller then swaps the page itself.
  static bool land({
    required Rect from,
    required VoidCallback onCovered,
    bool appear = true,
  }) {
    final intro = _mounted.isEmpty ? null : _mounted.last;
    if (intro == null || !intro.mounted) return false;
    return intro._land(from: from, appear: appear, onCovered: onCovered);
  }

  /// Ends the intro as soon as any page opens over the first one (a link, a
  /// notice, the release notes, a sheet): it never plays over a new page.
  static final NavigatorObserver navigatorObserver = _SkipOnPush();

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

  /// Where a first run's intro stops: the name and its underline are drawn,
  /// the rings are gone, nothing has started to leave.
  static const holdEnd = 0.56;

  /// Progress through [start]–[end] at [t], through [curve].
  static double span(
    double t,
    double start,
    double end, [
    Curve curve = Curves.linear,
  ]) => curve.transform(((t - start) / (end - start)).clamp(0.0, 1.0));
}

/// The landing's keyframes (board Onboarding: tile pops in 0–18 %, one ring
/// 18–40 %, flight 40–78 %, header 64–80 %, cards from 66 %; board
/// OnboardingTablette, from the tile already there: flight 8–52 %, header
/// 40–62 %, cards from 44 %). The screen first fades to black over the
/// onboarding (its 280 ms fade-out) and the page is swapped underneath.
/// The flight never starts before the swap: the header it lands on only
/// exists once the new page is built (the tablet's starts at 24 % instead
/// of 8 %, and ends a little later).
class _LandingTimeline {
  final bool appear;

  const _LandingTimeline({required this.appear});

  Duration get duration => appear
      ? LaunchIntro.landingDuration
      : LaunchIntro.landingFromTileDuration;

  double get coverEnd => 0.2;
  double get appearEnd => 0.18;
  double get ringStart => 0.18;
  double get ringEnd => 0.40;
  double get flightStart => appear ? 0.40 : 0.24;
  double get flightEnd => appear ? 0.78 : 0.64;
  double get groundOutStart => appear ? 0.64 : 0.48;
  double get groundOutEnd => appear ? 0.80 : 0.68;
  double get reveal => appear ? 0.66 : 0.50;
  double get tileOutStart => appear ? 0.74 : 0.60;
  double get tileOutEnd => appear ? 0.86 : 0.72;
}

class _LaunchIntroState extends State<LaunchIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _revealed = ValueNotifier<bool>(false);
  AppLifecycleListener? _lifecycle;
  bool _decided = false;
  bool _done = false;

  /// The landing in progress, if any ([LaunchIntro.land]).
  _LandingTimeline? _landing;
  Rect _landFrom = Rect.zero;
  VoidCallback? _onCovered;

  @override
  void initState() {
    super.initState();
    LaunchIntro._mounted.add(this);
    _controller =
        AnimationController(vsync: this, duration: LaunchIntro.duration)
          ..addListener(_onTick)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) _finish();
          });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;

    if (!widget.play || !_canPlay(context)) {
      _done = true;
      _revealed.value = true;
      return;
    }

    _start();
    _controller.forward(from: widget.fromTile ? _Timeline.tileEnd : 0);
  }

  bool _canPlay(BuildContext context) {
    final screenReader = MediaQuery.maybeAccessibleNavigationOf(context);
    return !reduceMotionOf(context) && screenReader != true;
  }

  void _start() {
    LaunchIntro._running.add(this);
    LaunchIntro._updateRunning();
    _lifecycle?.dispose();
    _lifecycle = AppLifecycleListener(
      onInactive: _finish,
      onHide: _finish,
      onPause: _finish,
    );
  }

  bool _land({
    required Rect from,
    required bool appear,
    required VoidCallback onCovered,
  }) {
    if (!_canPlay(context)) return false;
    // A landing replaces whatever still runs (it never does in practice:
    // the onboarding comes after the intro).
    if (!_done) _finish();
    _landing = _LandingTimeline(appear: appear);
    LaunchIntro._landingNotifier.value = true;
    _landFrom = from;
    _onCovered = onCovered;
    _revealed.value = false;
    setState(() => _done = false);
    _start();
    _controller
      ..duration = _landing!.duration
      ..forward(from: 0);
    return true;
  }

  void _onTick() {
    final t = _controller.value;
    final landing = _landing;
    if (landing != null) {
      if (t >= landing.coverEnd) _cover();
      if (!_revealed.value && t >= landing.reveal) _revealed.value = true;
      return;
    }
    if (widget.holdOnName && t >= _Timeline.holdEnd) {
      _finish();
      return;
    }
    if (!_revealed.value && _controller.value >= _Timeline.reveal) {
      _revealed.value = true;
    }
  }

  /// The landing's black is up: the page underneath is swapped, once.
  void _cover() {
    final onCovered = _onCovered;
    if (onCovered == null) return;
    _onCovered = null;
    LaunchIntro._swapping = true;
    try {
      onCovered();
    } finally {
      LaunchIntro._swapping = false;
    }
  }

  /// [_cover], after this frame: when it cannot push now (inside another
  /// push, or while the tree is locked).
  void _coverAfterFrame() {
    final onCovered = _onCovered;
    _onCovered = null;
    if (onCovered == null) return;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        LaunchIntro._swapping = true;
        try {
          onCovered();
        } finally {
          LaunchIntro._swapping = false;
        }
      })
      ..ensureVisualUpdate();
  }

  void _finish({bool deferCover = false}) {
    if (_done) return;
    if (_landing != null) {
      if (deferCover) {
        _coverAfterFrame();
      } else {
        _cover();
      }
    } else if (widget.holdOnName && mounted) {
      LaunchIntro._restingTile.value = _restingRect(context);
    }
    LaunchIntro._running.remove(this);
    LaunchIntro._updateRunning();
    _lifecycle?.dispose();
    _lifecycle = null;
    _controller.stop();
    _revealed.value = true;
    if (_landing != null) {
      _landing = null;
      LaunchIntro._landingNotifier.value = false;
    }
    if (mounted) setState(() => _done = true);
  }

  @override
  void dispose() {
    if (_landing != null) LaunchIntro._landingNotifier.value = false;
    // A landing cut short by the app's teardown still swaps the page, as
    // promised (after this frame: the tree is locked now).
    _coverAfterFrame();
    LaunchIntro._mounted.remove(this);
    LaunchIntro._running.remove(this);
    LaunchIntro._updateRunning();
    _lifecycle?.dispose();
    _controller.dispose();
    _revealed.dispose();
    super.dispose();
  }

  /// Where the tile rests once grown: on the native splash's tile when it
  /// handed over, else in the middle at the boards' 72 dp.
  Rect _restingRect(BuildContext context) {
    final splash = widget.fromTile ? widget.splashTile?.value : null;
    return splash ??
        Rect.fromCenter(
          center: MediaQuery.sizeOf(context).center(Offset.zero),
          width: _IntroFrame._tile,
          height: _IntroFrame._tile,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        EntranceGate(open: _revealed, child: widget.child),
        if (!_done)
          Positioned.fill(
            key: LaunchIntro.overlayKey,
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_controller, widget.splashTile]),
                  builder: (context, _) {
                    final t = _controller.value;
                    final landing = _landing;
                    // Covering: a tap skips. Once the app shows through,
                    // taps go to it.
                    return IgnorePointer(
                      ignoring: t >= (landing?.reveal ?? _Timeline.reveal),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _finish,
                        child: landing != null
                            ? _LandingFrame(
                                t: t,
                                timeline: landing,
                                from: _landFrom,
                                slot: _slotRect(context),
                                slotIsReal: _hasRealSlot,
                              )
                            : _IntroFrame(
                                t: t,
                                fromTile: widget.fromTile,
                                splash: widget.fromTile
                                    ? widget.splashTile?.value
                                    : null,
                                slot: _slotRect(context),
                                slotIsReal: _hasRealSlot,
                              ),
                      ),
                    );
                  },
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
        target.attached &&
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

class _SkipOnPush extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null && !LaunchIntro._swapping) {
      LaunchIntro._skipAll(fromPush: true);
    }
  }
}

/// One frame of the intro at [t] (0–1).
class _IntroFrame extends StatelessWidget {
  final double t;
  final bool fromTile;

  /// Where the native splash drew the tile, when known: the tile, its rings
  /// and the name are laid out around it instead of the view's centre.
  final Rect? splash;
  final Rect slot;
  final bool slotIsReal;

  const _IntroFrame({
    required this.t,
    required this.fromTile,
    required this.splash,
    required this.slot,
    required this.slotIsReal,
  });

  static const _tile = OnsetMark.designSize;
  static const _ground = OnsetTokens.backgroundDark;
  static const _accent = OnsetTokens.accent;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final tablet = isLargeScreenSize(size);
    final center = splash?.center ?? size.center(Offset.zero);
    // The tile's resting size, as a share of the boards' 72 dp.
    final rest = (splash?.width ?? _tile) / _tile;
    const span = _Timeline.span;

    // The tile: a dot, then the tile with an overshoot, then the flight.
    final double grow;
    if (fromTile) {
      grow = 1;
    } else if (t < _Timeline.dotEnd) {
      grow = 0.2 * span(t, 0, _Timeline.dotEnd, OnsetMotion.standard);
    } else {
      grow =
          0.2 +
          0.8 *
              span(
                t,
                _Timeline.dotEnd,
                _Timeline.tileEnd,
                OnsetMotion.overshoot,
              );
    }
    final settle = span(
      t,
      _Timeline.dotEnd,
      _Timeline.tileEnd,
      OnsetMotion.standard,
    );
    final radius = fromTile ? 20.0 : 36 - 16 * settle;
    final flight = span(
      t,
      _Timeline.flightStart,
      _Timeline.flightEnd,
      OnsetMotion.standard,
    );
    final tileCenter = Offset.lerp(center, slot.center, flight)!;
    final tileScale = grow * rest + (slot.width / _tile - rest) * flight;
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
    final underline = span(
      t,
      _Timeline.underlineStart,
      _Timeline.underlineEnd,
      OnsetMotion.standard,
    );

    final ground =
        1 -
        span(t, _Timeline.groundOutStart, _Timeline.groundOutEnd, Curves.ease);

    Widget ring(int index, double start, double end, double width) {
      if (t < start - 0.01) return const SizedBox.shrink();
      final p = span(t, start, end, OnsetMotion.standard);
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

    final frame = DefaultTextStyle(
      style: const TextStyle(
        fontFamily: OnsetTokens.displayFamily,
        decoration: TextDecoration.none,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (ground > 0) ColoredBox(color: _ground.withValues(alpha: ground)),
          if (t < _Timeline.ring1End)
            ring(0, _Timeline.ring1Start, _Timeline.ring1End, 2),
          if (t < _Timeline.ring2End)
            ring(1, _Timeline.ring2Start, _Timeline.ring2End, 1.5),
          if (nameOut > 0)
            Positioned(
              left: 0,
              right: 0,
              top:
                  center.dy +
                  _tile / 2 +
                  OnsetWordmark.gapBelowTile(tablet: tablet),
              child: Center(
                child: OnsetWordmark(
                  tablet: tablet,
                  letters: [
                    for (var i = 0; i < 5; i++)
                      span(
                        t,
                        _Timeline.letterStart + i * _Timeline.letterStep,
                        _Timeline.letterEnd + i * _Timeline.letterStep,
                        OnsetMotion.emphasizedDecelerate,
                      ),
                  ],
                  underline: underline,
                  opacity: nameOut,
                ),
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
    );

    // Light status-bar icons over the black ground; once it clears, the
    // app's own bars apply again.
    return ground > 0.5
        ? AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: frame,
          )
        : frame;
  }
}

/// One frame of the landing at [t] (0–1): the intro's black over the app,
/// the tile (popping in at [from] on a phone), one ring, the flight into
/// the header, then the black clears.
class _LandingFrame extends StatelessWidget {
  final double t;
  final _LandingTimeline timeline;
  final Rect from;
  final Rect slot;
  final bool slotIsReal;

  const _LandingFrame({
    required this.t,
    required this.timeline,
    required this.from,
    required this.slot,
    required this.slotIsReal,
  });

  static const _tile = OnsetMark.designSize;

  @override
  Widget build(BuildContext context) {
    const span = _Timeline.span;
    final tablet = isLargeScreenSize(MediaQuery.sizeOf(context));
    final rest = from.width / _tile;

    final ground = t < timeline.coverEnd
        ? span(t, 0, timeline.coverEnd, OnsetMotion.emphasizedAccelerate)
        : 1 -
              span(
                t,
                timeline.groundOutStart,
                timeline.groundOutEnd,
                Curves.ease,
              );

    final pop = timeline.appear
        ? span(t, 0, timeline.appearEnd, OnsetMotion.overshoot)
        : 1.0;
    final popOpacity = timeline.appear ? span(t, 0, timeline.appearEnd) : 1.0;
    final flight = span(
      t,
      timeline.flightStart,
      timeline.flightEnd,
      OnsetMotion.standard,
    );
    final center = Offset.lerp(from.center, slot.center, flight)!;
    final scale =
        (0.6 + 0.4 * pop) * rest + (slot.width / _tile - rest) * flight;
    final tileOpacity =
        popOpacity *
        (slotIsReal
            ? 1.0
            : 1 - span(t, timeline.tileOutStart, timeline.tileOutEnd));

    Widget? ring;
    if (timeline.appear && t >= timeline.ringStart && t < timeline.ringEnd) {
      final p = span(t, timeline.ringStart, timeline.ringEnd);
      ring = Positioned(
        left: from.center.dx - _tile / 2,
        top: from.center.dy - _tile / 2,
        width: _tile,
        height: _tile,
        child: Transform.scale(
          key: LaunchIntro.ringKeys[0],
          scale: rest * (1 + 1.6 * OnsetMotion.standard.transform(p)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(OnsetMark.designRadius),
              border: Border.all(
                color: OnsetTokens.accent.withValues(alpha: 0.7 * (1 - p)),
                width: 2,
              ),
            ),
          ),
        ),
      );
    }

    final frame = Stack(
      fit: StackFit.expand,
      children: [
        if (ground > 0)
          ColoredBox(
            color: OnsetTokens.backgroundDark.withValues(
              alpha: ground.clamp(0.0, 1.0),
            ),
          ),
        ?ring,
        Positioned(
          left: center.dx - _tile / 2,
          top: center.dy - _tile / 2,
          width: _tile,
          height: _tile,
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              key: LaunchIntro.tileKey,
              opacity: tileOpacity.clamp(0.0, 1.0),
              child: OnsetMarkTile(
                glow: [
                  BoxShadow(
                    color: OnsetTokens.accent.withValues(
                      alpha: 0.25 * (1 - flight),
                    ),
                    blurRadius: tablet ? 48 : 40,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    return ground > 0.5
        ? AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: frame,
          )
        : frame;
  }
}

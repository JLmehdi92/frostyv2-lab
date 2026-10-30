import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:onset/screens/channel/celebrations/celebration_art.dart';
import 'package:onset/screens/channel/celebrations/signal_pill.dart';
import 'package:onset/screens/channel/chat/gift_bomb_tracker.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/motion/rolling_number.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

/// "X is gifting N subs", pinned above chat for a gift bomb of five subs or
/// more: ONSET's gift box in a ring that fills
/// as the gifts are handed out, the gifter in the signal colour, and a 2 dp
/// bar draining until the pin leaves, Twitch's 10 to 30 s.
///
/// Wide (56 dp, two lines) in portrait and in a wide chat; one line (44 dp,
/// "X ×N") in a narrow side chat ([compact]). Only the gifter's name ever
/// ellipsizes: the count stays whole.
///
/// The closed box hops while gifts arrive; at the last one it squashes, opens
/// in a burst of signal light and sparks, then waits out the countdown and
/// folds away (280 ms), as it does on the close button. Reduce motion: no
/// hop and no burst, the box opens in a 150 ms cross-fade, the bar steps.
class GiftBombPin extends StatefulWidget {
  const GiftBombPin({
    super.key,
    required this.banner,
    required this.now,
    this.onDismiss,
    this.compact = false,
  });

  final GiftBombBanner banner;

  /// Twitch's current time, for the countdown.
  final DateTime Function() now;

  /// The close button; none without it (the details sheet).
  final VoidCallback? onDismiss;

  /// One line, for a narrow side chat.
  final bool compact;

  /// The pin itself (56 dp, or 44 dp [compact]).
  static const pinKey = ValueKey('gift-bomb-pin');
  static const nameKey = ValueKey('gift-bomb-pin-name');

  /// " is gifting N subs" (wide) or the "×N" chip ([compact]).
  static const countKey = ValueKey('gift-bomb-pin-count');

  /// "3 of 5 handed out", then "5 of 5 · thanks!" (wide only).
  static const progressKey = ValueKey('gift-bomb-pin-progress');
  static const ringKey = ValueKey('gift-bomb-pin-ring');
  static const closedBoxKey = ValueKey('gift-bomb-pin-closed');
  static const openBoxKey = ValueKey('gift-bomb-pin-open');
  static const glowKey = ValueKey('gift-bomb-pin-glow');
  static const sparksKey = ValueKey('gift-bomb-pin-sparks');
  static const drainKey = ValueKey('gift-bomb-pin-drain');

  /// The hop of the closed box while gifts arrive.
  static const hopPeriod = Duration(milliseconds: 1200);

  /// Squash, open, glow and sparks at the last gift (sparks end last).
  static const burst = Duration(milliseconds: 620);

  /// The fold at the end, or on the close button.
  static const exit = Duration(milliseconds: 280);

  /// The narrowest chat that still gets the wide pin.
  static const minWideWidth = 300.0;

  @override
  State<GiftBombPin> createState() => _GiftBombPinState();
}

/// One spark of the burst: which art, where it flies (degrees from the
/// right, clockwise, and how far), its size and its turn, all in
/// dp/degrees.
typedef _Spark = ({
  String art,
  double deg,
  double dist,
  double size,
  double rot,
});

const List<_Spark> _sparks = [
  (art: CelebrationArt.sparkLime, deg: -86, dist: 24, size: 12, rot: 18),
  (art: CelebrationArt.sparkMint, deg: -41, dist: 19, size: 9, rot: -32),
  (art: CelebrationArt.sparkWhite, deg: 3, dist: 27, size: 10, rot: 40),
  (art: CelebrationArt.sparkDot, deg: 48, dist: 21, size: 8, rot: -12),
  (art: CelebrationArt.sparkLime, deg: 92, dist: 26, size: 14, rot: 26),
  (art: CelebrationArt.sparkWhite, deg: 139, dist: 18, size: 9, rot: -44),
  (art: CelebrationArt.sparkMint, deg: 182, dist: 28, size: 13, rot: 8),
  (art: CelebrationArt.sparkDot, deg: 226, dist: 22, size: 9, rot: 34),
];

/// The `cubic-bezier(.2,0,0,1)`, applied to each keyframe segment.
const _ease = OnsetMotion.standard;

class _GiftBombPinState extends State<GiftBombPin>
    with TickerProviderStateMixin {
  late final _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final _exit = AnimationController(
    vsync: this,
    duration: GiftBombPin.exit,
  );
  late final _hop = AnimationController(
    vsync: this,
    duration: GiftBombPin.hopPeriod,
  );
  late final _burst = AnimationController(
    vsync: this,
    duration: GiftBombPin.burst,
  );

  Timer? _leaveTimer;
  ValueListenable<GiftBomb>? _live;
  late GiftBomb _bomb;
  var _reduceMotion = false;
  var _leaving = false;

  /// The burst plays only for a last gift seen arriving here.
  var _burstPlayed = false;

  @override
  void initState() {
    super.initState();
    _follow(widget.banner.live);
    _bomb = widget.banner.live?.value ?? widget.banner.bomb;
    _scheduleLeave();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = reduceMotionOf(context);
    final first = !_entry.isAnimating && _entry.value == 0;
    _reduceMotion = reduce;
    _entry.duration = reduce
        ? const Duration(milliseconds: 200)
        : const Duration(milliseconds: 260);
    _exit.duration = reduce
        ? const Duration(milliseconds: 200)
        : GiftBombPin.exit;
    if (first) _entry.forward();
    _syncHop();
    _precache();
  }

  /// Device pixel ratio the art was last precached for.
  double? _precachedFor;

  /// The open box (at both slot sizes: the layout picks one) and the sparks
  /// are decoded before the last gift, once per pixel ratio.
  void _precache() {
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    if (_precachedFor == ratio) return;
    _precachedFor = ratio;
    for (final (art, size) in [
      (CelebrationArt.giftOpen, 20.0),
      (CelebrationArt.giftOpen, 28.0),
      for (final spark in _sparks) (spark.art, 14.0),
    ]) {
      precacheImage(
        CelebrationArt.sized(context, art, size),
        context,
        onError: (_, _) {},
      );
    }
  }

  bool get _compact => widget.compact;

  @override
  void didUpdateWidget(GiftBombPin oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.banner;
    final banner = widget.banner;
    if (old.id != banner.id) {
      // Another bomb in the same place (the details sheet is not keyed):
      // start over as a new pin.
      _follow(banner.live);
      _bomb = banner.live?.value ?? banner.bomb;
      _burstPlayed = false;
      _burst.value = 0;
      _leaving = false;
      _exit.value = 0;
      _entry.forward(from: 0);
      _syncHop();
      _scheduleLeave();
      return;
    }
    if (old.live != banner.live) {
      _follow(banner.live);
      _onBomb();
    } else if (banner.live == null && old.bomb != banner.bomb) {
      setState(() => _bomb = banner.bomb);
    }
    if (old.endsAt != banner.endsAt || old.startedAt != banner.startedAt) {
      // Pinned again for longer: back up if it was already folding away.
      if (_leaving && banner.endsAt.isAfter(widget.now())) {
        _leaving = false;
        _exit.value = 0;
        _syncHop();
      }
      _scheduleLeave();
    }
  }

  void _follow(ValueListenable<GiftBomb>? live) {
    _live?.removeListener(_onBomb);
    _live = live;
    live?.addListener(_onBomb);
  }

  void _onBomb() {
    if (!mounted) return;
    final next = _live?.value ?? widget.banner.bomb;
    final completes = !_bomb.complete && next.complete;
    setState(() {
      _bomb = next;
      if (completes && !_reduceMotion) _burstPlayed = true;
    });
    if (completes && !_reduceMotion) _burst.forward(from: 0);
    _syncHop();
  }

  void _syncHop() {
    final hop = !_reduceMotion && !_bomb.complete && !_leaving;
    if (hop && !_hop.isAnimating) {
      _hop.repeat();
    } else if (!hop && _hop.isAnimating) {
      _hop
        ..stop()
        ..value = 0;
    }
  }

  /// Folds away just as the countdown ends.
  void _scheduleLeave() {
    _leaveTimer?.cancel();
    final left =
        widget.banner.endsAt.difference(widget.now()) - GiftBombPin.exit;
    _leaveTimer = Timer(left.isNegative ? Duration.zero : left, () => _leave());
  }

  void _leave({VoidCallback? then}) {
    if (!mounted) return;
    if (_leaving) return;
    _leaving = true;
    _leaveTimer?.cancel();
    _syncHop();
    _exit.forward().whenComplete(() {
      if (mounted) then?.call();
    });
  }

  @override
  void dispose() {
    _leaveTimer?.cancel();
    _live?.removeListener(_onBomb);
    _entry.dispose();
    _exit.dispose();
    _hop.dispose();
    _burst.dispose();
    super.dispose();
  }

  String get _subs => _bomb.count == 1 ? 'sub' : 'subs';

  String get _semanticsValue {
    final count = _bomb.count;
    final received = math.min(_bomb.received, count);
    return _bomb.complete
        ? 'all $count handed out'
        : '$received of $count handed out';
  }

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = SheetColors.accentOf(context);
    // Lime is a fill, not a text colour, on a light card.
    final accentText = dark ? accent : context.onsetColors.subNoticeText;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            _compact || constraints.maxWidth < GiftBombPin.minWideWidth;
        final pin = _pin(
          context,
          compact: compact,
          colors: colors,
          accent: accent,
          accentText: accentText,
        );
        return _Leave(
          exit: _exit,
          reduceMotion: _reduceMotion,
          child: _Enter(entry: _entry, reduceMotion: _reduceMotion, child: pin),
        );
      },
    );
  }

  Widget _pin(
    BuildContext context, {
    required bool compact,
    required SheetColors colors,
    required Color accent,
    required Color accentText,
  }) {
    final bomb = _bomb;
    final height = compact ? 44.0 : 56.0;
    final onDismiss = widget.onDismiss;
    final close = onDismiss == null
        ? SizedBox(width: compact ? 8 : 12)
        : IconButton(
            tooltip: 'Hide',
            onPressed: () => _leave(then: onDismiss),
            style: IconButton.styleFrom(
              fixedSize: const Size(44, 44),
              minimumSize: const Size(44, 44),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: SheetGlyph(
              SheetGlyphKind.close,
              size: compact ? 14 : 16,
              strokeWidth: 2.2,
              color: colors.secondary,
            ),
          );

    final name = Text(
      bomb.gifterName,
      key: GiftBombPin.nameKey,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: TextStyle(fontWeight: FontWeight.w700, color: accentText),
    );

    final Widget text;
    if (compact) {
      text = DefaultTextStyle.merge(
        style: TextStyle(
          fontFamily: OnsetTokens.bodyFamily,
          fontSize: 13,
          height: 18 / 13,
          color: colors.text,
        ),
        child: _NameThenTail(
          gap: 8,
          name: name,
          tail: _CountChip(count: bomb.count, accent: accent, text: accentText),
        ),
      );
    } else {
      text = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 1,
        children: [
          DefaultTextStyle.merge(
            style: TextStyle(
              fontFamily: OnsetTokens.bodyFamily,
              fontSize: 14,
              height: 19 / 14,
              color: colors.text,
            ),
            child: _NameThenTail(
              name: name,
              tail: Text(
                ' is gifting ${bomb.count} $_subs',
                key: GiftBombPin.countKey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          DefaultTextStyle.merge(
            style: OnsetType.tabular(
              TextStyle(
                fontFamily: OnsetTokens.bodyFamily,
                fontSize: 12.5,
                height: 16 / 12.5,
                color: colors.secondary,
              ),
            ),
            maxLines: 1,
            softWrap: false,
            child: SizedBox(
              key: GiftBombPin.progressKey,
              height: 16,
              child: _progress(accentText),
            ),
          ),
        ],
      );
    }

    final card = Container(
      key: GiftBombPin.pinKey,
      constraints: BoxConstraints(minHeight: height),
      padding: EdgeInsetsDirectional.only(start: 8, end: compact ? 0 : 4),
      decoration: ShapeDecoration(
        color: colors.sheet,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      // In front, so the hairline adds no padding (an inset ring).
      foregroundDecoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colors.ring,
            width: OnsetTokens.hairlineWidth,
          ),
        ),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: _ring(compact: compact, accent: accent),
          ),
          SizedBox(width: compact ? 8 : 10),
          Expanded(child: ExcludeSemantics(child: text)),
          close,
        ],
      ),
    );

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Semantics(
        container: true,
        liveRegion: true,
        label: '${bomb.gifterName} is gifting ${bomb.count} $_subs',
        value: _semanticsValue,
        child: RepaintBoundary(
          // Unclipped: the sparks may fly past the card's edge. Only the
          // drain bar follows the rounded corners.
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              card,
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: GiftBombCountdownBar(
                        key: GiftBombPin.drainKey,
                        startedAt: widget.banner.startedAt,
                        endsAt: widget.banner.endsAt,
                        now: widget.now,
                        color: accent,
                      ),
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

  /// "3 of 5 handed out", the count rolling; "5 of 5 · thanks!" at the end.
  Widget _progress(Color accentText) {
    final count = _bomb.count;
    if (_bomb.complete) {
      final done = Text(
        '$count of $count · thanks!',
        style: TextStyle(fontWeight: FontWeight.w600, color: accentText),
      );
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: _reduceMotion
            ? const Duration(milliseconds: 200)
            : const Duration(milliseconds: 260),
        curve: _ease,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, _reduceMotion ? 0 : 5 * (1 - t)),
            child: child,
          ),
        ),
        child: done,
      );
    }
    return Row(
      children: [
        RollingNumber(
          '${math.min(_bomb.received, count)}',
          duration: const Duration(milliseconds: 260),
        ),
        Flexible(
          child: Text(
            ' of $count handed out',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// The ring and the box inside it, with the glow and sparks of the burst.
  Widget _ring({required bool compact, required Color accent}) {
    final slot = compact ? 28.0 : 40.0;
    final stroke = compact ? 2.0 : 2.5;
    final inset = compact ? 4.0 : 6.0;
    final glowOut = compact ? 5.0 : 7.0;
    final bomb = _bomb;
    final fraction = bomb.count <= 0
        ? 0.0
        : (bomb.received / bomb.count).clamp(0.0, 1.0);
    final box = slot - inset * 2;

    Widget art(String asset, Key key) => Image(
      key: key,
      image: CelebrationArt.sized(context, asset, box),
      width: box,
      height: box,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );

    final closed = art(CelebrationArt.giftClosed, GiftBombPin.closedBoxKey);
    final open = art(CelebrationArt.giftOpen, GiftBombPin.openBoxKey);

    Widget boxes;
    if (_reduceMotion || !_burstPlayed) {
      // A plain cross-fade (or the open box at once when first seen done).
      boxes = TweenAnimationBuilder<double>(
        tween: Tween(end: bomb.complete ? 1 : 0),
        duration: const Duration(milliseconds: 150),
        builder: (context, t, _) => Stack(
          children: [
            Opacity(opacity: 1 - t, child: closed),
            Opacity(opacity: t, child: open),
          ],
        ),
      );
    } else {
      boxes = AnimatedBuilder(
        animation: _burst,
        builder: (context, _) {
          final ms = _burst.value * GiftBombPin.burst.inMilliseconds;
          final t = ((ms - 60) / 120).clamp(0.0, 1.0);
          return Transform.scale(
            scale: _popScale((ms / 320).clamp(0.0, 1.0)),
            alignment: const Alignment(0, 0.4),
            child: Stack(
              children: [
                Opacity(opacity: 1 - t, child: closed),
                Opacity(opacity: t, child: open),
              ],
            ),
          );
        },
      );
    }

    if (!_reduceMotion && !bomb.complete) {
      boxes = AnimatedBuilder(
        animation: _hop,
        builder: (context, child) {
          final (dy, turn) = _hopAt(_hop.value);
          return Transform(
            alignment: const Alignment(0, 0.8),
            transform: Matrix4.translationValues(0, dy, 0)
              ..rotateZ(turn * math.pi / 180),
            child: child,
          );
        },
        child: boxes,
      );
    }

    final burst = _burstPlayed && !_reduceMotion;
    return SizedBox.square(
      key: GiftBombPin.ringKey,
      dimension: slot,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: fraction),
              duration: _reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 140),
              builder: (context, value, _) => CustomPaint(
                painter: GiftBombRingPainter(
                  fraction: value,
                  color: accent,
                  track: accent.withValues(alpha: 0.18),
                  stroke: stroke,
                ),
              ),
            ),
          ),
          if (burst)
            Positioned(
              left: inset - glowOut,
              top: inset - glowOut,
              width: box + glowOut * 2,
              height: box + glowOut * 2,
              child: AnimatedBuilder(
                animation: _burst,
                builder: (context, _) {
                  final ms = _burst.value * GiftBombPin.burst.inMilliseconds;
                  final (opacity, scale) = _glowAt(
                    ((ms - 60) / 400).clamp(0.0, 1.0),
                  );
                  return Opacity(
                    key: GiftBombPin.glowKey,
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              accent.withValues(alpha: 0.55),
                              accent.withValues(alpha: 0.18),
                              accent.withValues(alpha: 0),
                            ],
                            stops: const [0, 0.45, 0.7],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          Positioned(left: inset, top: inset, child: boxes),
          if (burst)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  key: GiftBombPin.sparksKey,
                  animation: _burst,
                  builder: (context, _) {
                    final ms = _burst.value * GiftBombPin.burst.inMilliseconds;
                    final t = ((ms - 60) / 560).clamp(0.0, 1.0);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final spark in _sparks)
                          _spark(context, spark, t, slot),
                      ],
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _spark(BuildContext context, _Spark spark, double t, double slot) {
    final (position, turn, scale, opacity) = _sparkAt(t);
    final angle = spark.deg * math.pi / 180;
    final dx = math.cos(angle) * spark.dist * position;
    final dy = math.sin(angle) * spark.dist * position;
    return Positioned(
      left: slot / 2 - spark.size / 2 + dx,
      top: slot / 2 - spark.size / 2 + dy,
      width: spark.size,
      height: spark.size,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: spark.rot * turn * math.pi / 180,
          child: Transform.scale(
            scale: scale,
            child: Image(
              image: CelebrationArt.sized(context, spark.art, 14),
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    );
  }
}

/// The hop at [t] of its 1.2 s loop: up 2 dp and tilted 4°
/// left at a quarter, back, then the same to the right, each quarter eased
/// in and out. Returns the lift (negative is up) and the tilt in degrees.
@visibleForTesting
(double, double) giftBoxHopAt(double t) => _hopAt(t);

(double, double) _hopAt(double t) {
  final quarter = (t.clamp(0.0, 1.0) * 4).floor().clamp(0, 3);
  final local = Curves.easeInOut.transform(t * 4 - quarter);
  final amount = quarter.isEven ? local : 1 - local;
  final side = quarter < 2 ? -1.0 : 1.0;
  return (-2 * amount, side * 4 * amount);
}

/// The box's squash then swell at [t] of its 320 ms: 0.92
/// at 20 %, 1.12 at 70 %, back to 1.
double _popScale(double t) {
  double seg(double a, double b, double from, double to) =>
      from + (to - from) * _ease.transform(((t - a) / (b - a)).clamp(0, 1));
  if (t <= 0.2) return seg(0, 0.2, 1, 0.92);
  if (t <= 0.7) return seg(0.2, 0.7, 0.92, 1.12);
  return seg(0.7, 1, 1.12, 1);
}

/// The glow's opacity and scale at [t] of its 400 ms.
(double, double) _glowAt(double t) {
  if (t <= 0) return (0, 0.6);
  if (t <= 0.4) {
    final e = _ease.transform(t / 0.4);
    return (e, 0.6 + 0.4 * e);
  }
  final e = _ease.transform((t - 0.4) / 0.6);
  return (1 - e, 1 + 0.25 * e);
}

/// A spark at [t] of its 560 ms: how far along its path,
/// how much of its turn, its scale and its opacity.
(double, double, double, double) _sparkAt(double t) {
  final double opacity;
  if (t <= 0) {
    opacity = 0;
  } else if (t <= 0.12) {
    opacity = _ease.transform(t / 0.12);
  } else if (t <= 0.55) {
    opacity = 1;
  } else {
    opacity = 1 - _ease.transform((t - 0.55) / 0.45);
  }
  if (t <= 0.55) {
    final e = _ease.transform(t / 0.55);
    return (0.82 * e, 0.8 * e, 0.5 + 0.5 * e, opacity);
  }
  final e = _ease.transform((t - 0.55) / 0.45);
  return (0.82 + 0.18 * e, 0.8 + 0.2 * e, 1 - 0.7 * e, opacity);
}

/// "×N" on a signal-tinted pill, for the one-line pin.
class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.count,
    required this.accent,
    required this.text,
  });

  final int count;
  final Color accent;
  final Color text;

  @override
  Widget build(BuildContext context) => Container(
    key: GiftBombPin.countKey,
    height: 22,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: signalPillDecoration(accent),
    child: Center(
      widthFactor: 1,
      child: Text(
        '×$count',
        maxLines: 1,
        softWrap: false,
        style: OnsetType.tabular(
          TextStyle(
            fontFamily: OnsetTokens.bodyFamily,
            fontSize: 12,
            height: 1,
            fontWeight: FontWeight.w800,
            color: text,
          ),
        ),
      ),
    ),
  );
}

/// The pin coming in (260 ms): from 8 dp higher, at 98.5 %,
/// fading in. Reduce motion: a plain fade.
class _Enter extends StatelessWidget {
  const _Enter({
    required this.entry,
    required this.reduceMotion,
    required this.child,
  });

  final AnimationController entry;
  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: entry,
    builder: (context, child) {
      final t = reduceMotion
          ? entry.value
          : OnsetMotion.emphasizedDecelerate.transform(entry.value);
      // One structure either way: the pin's state survives a change.
      final travel = reduceMotion ? 0.0 : 1 - t;
      return Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, -8 * travel),
          child: Transform.scale(scale: 1 - 0.015 * travel, child: child),
        ),
      );
    },
    child: child,
  );
}

/// The pin folding away: its height to nothing in
/// 280 ms while it fades out in 200 ms, so chat moves up without a jump.
/// Reduce motion: a fade only.
class _Leave extends StatelessWidget {
  const _Leave({
    required this.exit,
    required this.reduceMotion,
    required this.child,
  });

  final AnimationController exit;
  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: exit,
    builder: (context, child) {
      final ms = exit.value * (exit.duration?.inMilliseconds ?? 280);
      final fade = reduceMotion
          ? exit.value
          : Curves.ease.transform((ms / 200).clamp(0.0, 1.0));
      // One structure either way: the pin's state survives a change.
      // Clipped only while it folds, so the sparks are free at rest.
      return ClipRect(
        clipBehavior: exit.value == 0 ? Clip.none : Clip.hardEdge,
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: reduceMotion ? 1 : 1 - _ease.transform(exit.value),
          child: Opacity(opacity: 1 - fade, child: child),
        ),
      );
    },
    child: child,
  );
}

/// The ring around the gift box: a track at 18 % of [color] and the arc of
/// gifts handed out, from the top, clockwise, round-capped.
class GiftBombRingPainter extends CustomPainter {
  const GiftBombRingPainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double fraction;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - stroke / 2 - 0.25;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, paint..color = track);
    if (fraction <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction.clamp(0.0, 1.0),
      false,
      paint
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(GiftBombRingPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.color != color ||
      oldDelegate.track != track ||
      oldDelegate.stroke != stroke;
}

/// A bar that drains linearly from [startedAt] to [endsAt] (Twitch time,
/// from [now]), [height] dp tall along the pin's bottom edge. With reduced
/// motion it steps once a second instead.
///
/// The countdown keeps its real duration even when the system removes
/// animations, which would otherwise shorten it to a twentieth.
class GiftBombCountdownBar extends StatefulWidget {
  const GiftBombCountdownBar({
    super.key,
    required this.startedAt,
    required this.endsAt,
    required this.now,
    required this.color,
    this.height = 2,
  });

  final DateTime startedAt;
  final DateTime endsAt;
  final DateTime Function() now;
  final Color color;
  final double height;

  @override
  State<GiftBombCountdownBar> createState() => GiftBombCountdownBarState();
}

class GiftBombCountdownBarState extends State<GiftBombCountdownBar>
    with SingleTickerProviderStateMixin {
  // Preserve: the drain is a timer, not a decoration.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );

  /// Ticks once a second under reduced motion.
  Timer? _stepper;

  /// Whole seconds left, under reduced motion.
  var _stepsLeft = 0;

  bool? _reduceMotion;

  Duration get _total => widget.endsAt.difference(widget.startedAt);

  /// The part of the bar still drawn, 0–1.
  double get value {
    if (!(_reduceMotion ?? false)) return _controller.value;
    final seconds = _total.inMilliseconds / 1000;
    return seconds <= 0 ? 0 : (_stepsLeft / seconds).clamp(0.0, 1.0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = reduceMotionOf(context);
    if (reduceMotion != _reduceMotion) {
      _reduceMotion = reduceMotion;
      _start();
    }
  }

  @override
  void didUpdateWidget(GiftBombCountdownBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAt != widget.startedAt ||
        oldWidget.endsAt != widget.endsAt) {
      _start();
    }
  }

  /// One linear drain, or one step a second, over the time left.
  void _start() {
    _stepper?.cancel();
    _stepper = null;
    _controller.stop();

    final total = _total;
    final left = widget.endsAt.difference(widget.now());
    if (total <= Duration.zero || left <= Duration.zero) {
      _controller.value = 0;
      _stepsLeft = 0;
      return;
    }

    if (_reduceMotion ?? false) {
      _stepsLeft = (left.inMilliseconds / 1000).ceil();
      _stepper = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _stepsLeft--);
        if (_stepsLeft <= 0) timer.cancel();
      });
      return;
    }

    _controller.value = (left.inMicroseconds / total.inMicroseconds).clamp(
      0.0,
      1.0,
    );
    _controller.animateBack(0, duration: left);
  }

  @override
  void dispose() {
    _stepper?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _bar(double value) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: FractionallySizedBox(
      widthFactor: value.clamp(0.0, 1.0),
      child: SizedBox(
        height: widget.height,
        child: ColoredBox(color: widget.color),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.height,
    child: (_reduceMotion ?? false)
        ? _bar(value)
        : AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => _bar(_controller.value),
          ),
  );
}

/// The gifter's name, then [tail] ("is gifting N subs", or the "×N" chip),
/// on one line: the tail is laid out first and keeps its whole width, the
/// name gets what is left and ellipsizes. Only a tail wider than the line
/// itself is cut.
class _NameThenTail extends MultiChildRenderObjectWidget {
  _NameThenTail({required Widget name, required Widget tail, this.gap = 0})
    : super(children: [name, tail]);

  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderNameThenTail(gap: gap, textDirection: Directionality.of(context));

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderNameThenTail renderObject,
  ) => renderObject
    ..gap = gap
    ..textDirection = Directionality.of(context);
}

class _NameThenTailData extends ContainerBoxParentData<RenderBox> {}

class _RenderNameThenTail extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _NameThenTailData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _NameThenTailData> {
  _RenderNameThenTail({
    required double gap,
    required TextDirection textDirection,
  }) : _gap = gap,
       _textDirection = textDirection;

  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _NameThenTailData) {
      child.parentData = _NameThenTailData();
    }
  }

  RenderBox get _name => firstChild!;
  RenderBox get _tail => lastChild!;

  @override
  double computeMinIntrinsicHeight(double width) => math.max(
    _name.getMinIntrinsicHeight(width),
    _tail.getMinIntrinsicHeight(width),
  );

  @override
  double computeMaxIntrinsicHeight(double width) => math.max(
    _name.getMaxIntrinsicHeight(width),
    _tail.getMaxIntrinsicHeight(width),
  );

  @override
  double computeMinIntrinsicWidth(double height) =>
      _tail.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _name.getMaxIntrinsicWidth(height) +
      _gap +
      _tail.getMaxIntrinsicWidth(height);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final max = constraints.maxWidth;
    final tail = _tail.getDryLayout(BoxConstraints(maxWidth: max));
    final room = math.max(0.0, max - tail.width - _gap);
    final name = _name.getDryLayout(BoxConstraints(maxWidth: room));
    return constraints.constrain(
      Size(name.width + _gap + tail.width, math.max(name.height, tail.height)),
    );
  }

  @override
  void performLayout() {
    final max = constraints.maxWidth;
    _tail.layout(BoxConstraints(maxWidth: max), parentUsesSize: true);
    final room = math.max(0.0, max - _tail.size.width - _gap);
    _name.layout(BoxConstraints(maxWidth: room), parentUsesSize: true);
    final width = math.min(max, _name.size.width + _gap + _tail.size.width);
    final height = math.max(_name.size.height, _tail.size.height);
    size = constraints.constrain(Size(width, height));
    final ltr = _textDirection == TextDirection.ltr;
    final nameX = ltr ? 0.0 : size.width - _name.size.width;
    final tailX = ltr
        ? _name.size.width + _gap
        : size.width - _name.size.width - _gap - _tail.size.width;
    (_name.parentData! as _NameThenTailData).offset = Offset(
      nameX,
      (size.height - _name.size.height) / 2,
    );
    (_tail.parentData! as _NameThenTailData).offset = Offset(
      tailX,
      (size.height - _tail.size.height) / 2,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}

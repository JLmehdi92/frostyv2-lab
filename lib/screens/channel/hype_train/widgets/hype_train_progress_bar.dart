import 'package:flutter/material.dart';
import 'package:onset/screens/channel/hype_train/hype_train_timings.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_palette.dart';

/// The level's progress as the banner's background, as on Twitch: the
/// track fills the banner and the fill grows over it from the start edge.
/// A gradient spans the whole width and is clipped to the progress, not
/// squeezed into it; an unlocked treasure's gradient covers everything.
/// It animates to [percent] in [duration] (a `fillTo` step).
///
/// ONSET's level colours: a new level's colour
/// morphs in over [morph] (600 ms, 200 ms with reduced motion); on a higher
/// [level] the bar starts again from 0 rather than draining back; the level 6+
/// gradient flows (4 s a period) unless [animateSheen] is off.
class HypeTrainProgressBar extends StatefulWidget {
  const HypeTrainProgressBar({
    super.key,
    required this.percent,
    required this.palette,
    this.duration = HtTimings.extraShort,
    this.morph = morphDuration,
    this.animateSheen = true,
    this.edge,
    this.level,
  });

  final int percent;
  final HtPalette palette;

  /// Zero with reduced motion.
  final Duration duration;

  /// How long a new palette takes to replace the old one.
  final Duration morph;

  /// Off with reduced motion: the level 6+ gradient stands still.
  final bool animateSheen;

  /// Receives the drawn fill (0–1) on every frame, for text that turns at
  /// the fill's edge.
  final ValueNotifier<double>? edge;

  /// The level the bar fills: a higher one starts again from 0.
  final int? level;

  static const morphDuration = Duration(milliseconds: 600);
  static const reducedMorph = Duration(milliseconds: 200);
  static const sheenPeriod = Duration(seconds: 4);

  @override
  State<HypeTrainProgressBar> createState() => HypeTrainProgressBarState();
}

class HypeTrainProgressBarState extends State<HypeTrainProgressBar>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _morph = AnimationController(
    vsync: this,
    value: 1,
  );
  AnimationController? _sheen;

  /// The palette being morphed away from.
  HtPalette? _previous;

  /// The drawn fill, 0–1.
  double get value => _controller.value;

  /// How far the latest palette has replaced the previous one, 0–1.
  double get morphValue => _morph.value;

  /// Where the flowing gradient is in its period, 0–1 (0 when still).
  double get sheenValue => _sheen?.value ?? 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, value: widget.percent / 100)
      ..addListener(_publish);
    _publish();
    _syncSheen();
  }

  void _publish() => widget.edge?.value = _controller.value;

  void _syncSheen() {
    final flows = widget.palette.fillSheen && widget.animateSheen;
    if (flows && _sheen == null) {
      _sheen = AnimationController(
        vsync: this,
        duration: HypeTrainProgressBar.sheenPeriod,
      )..repeat();
    } else if (!flows && _sheen != null) {
      _sheen!.dispose();
      _sheen = null;
    }
  }

  @override
  void didUpdateWidget(HypeTrainProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.edge != widget.edge) _publish();
    if (!_samePaint(oldWidget.palette, widget.palette)) {
      _previous = oldWidget.palette;
      if (widget.morph == Duration.zero) {
        _morph.value = 1;
      } else {
        _morph
          ..duration = widget.morph
          ..forward(from: 0);
      }
    }
    _syncSheen();
    if (oldWidget.percent == widget.percent) return;
    final target = widget.percent / 100;
    if (widget.duration == Duration.zero) {
      _controller.value = target;
      return;
    }
    // A level up: the new level fills up from nothing.
    final oldLevel = oldWidget.level;
    final level = widget.level;
    if (oldLevel != null && level != null && level > oldLevel) {
      _controller.value = 0;
    }
    _controller.animateTo(
      target,
      duration: widget.duration,
      curve: Curves.decelerate,
    );
  }

  static bool _samePaint(HtPalette a, HtPalette b) =>
      a.track == b.track &&
      a.fill == b.fill &&
      a.fillSheen == b.fillSheen &&
      a.fillCoversAll == b.fillCoversAll &&
      _sameColors(a.fillColors, b.fillColors);

  static bool _sameColors(List<Color>? a, List<Color>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _sheen?.dispose();
    _morph.dispose();
    _controller.dispose();
    super.dispose();
  }

  Decoration _decoration(HtPalette palette, double sheen) {
    final colors = palette.fillColors;
    if (colors == null) return BoxDecoration(color: palette.fill);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: AlignmentDirectional.centerStart,
        end: AlignmentDirectional.centerEnd,
        colors: colors,
        tileMode: palette.fillSheen ? TileMode.repeated : TileMode.clamp,
        transform: palette.fillSheen && sheen != 0 ? _Slide(sheen) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final previous = _previous;
    final animations = Listenable.merge([_morph, ?_sheen]);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : 0,
          constraints.hasBoundedHeight ? constraints.maxHeight : 0,
        );
        final fill = AnimatedBuilder(
          animation: animations,
          builder: (context, _) {
            final t = Curves.easeOut.transform(_morph.value);
            final sheen = sheenValue;
            final current = DecoratedBox(
              key: const ValueKey('ht-fill'),
              decoration: _decoration(palette, sheen),
            );
            return SizedBox.fromSize(
              size: size,
              child: previous == null || t >= 1
                  ? current
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(decoration: _decoration(previous, sheen)),
                        Opacity(opacity: t, child: current),
                      ],
                    ),
            );
          },
        );
        return AnimatedBuilder(
          animation: _morph,
          builder: (context, child) => ColoredBox(
            color: previous == null
                ? palette.track
                : Color.lerp(
                    previous.track,
                    palette.track,
                    Curves.easeOut.transform(_morph.value),
                  )!,
            child: child,
          ),
          child: palette.fillCoversAll
              ? fill
              : AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ClipRect(
                      key: const ValueKey('ht-fill-clip'),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: _controller.value.clamp(0.0, 1.0),
                        child: child,
                      ),
                    ),
                  ),
                  child: fill,
                ),
        );
      },
    );
  }
}

/// Moves a repeating gradient along by [t] of the box's width.
class _Slide extends GradientTransform {
  const _Slide(this.t);

  final double t;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final dx = bounds.width * t;
    return Matrix4.translationValues(
      textDirection == TextDirection.rtl ? dx : -dx,
      0,
      0,
    );
  }
}

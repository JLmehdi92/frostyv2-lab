import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:frosty/widgets/motion/reduce_motion.dart';

/// ONSET's own raid rocket (board KitAssets), drawn for this project.
const kRocketAsset = 'assets/celebrations/rocket.svg';

/// The rocket drawing, whole and split into its body and its flame so the
/// flame can flicker on its own.
typedef RocketArt = ({String whole, String body, String flame});

/// Splits [svg] (the rocket asset) into body and flame, or null when it no
/// longer has the flame group: it is then drawn whole, never flickering.
RocketArt? splitRocketSvg(String svg) {
  const flameOpen = '<g class="rk-flame">';
  const frameOpen = '<g transform="rotate(45 60 60)">';
  final start = svg.indexOf(flameOpen);
  final frame = svg.indexOf(frameOpen);
  if (start == -1 || frame == -1 || frame > start) return null;
  final end = svg.indexOf('</g>', start);
  final close = svg.lastIndexOf('</g>');
  if (end == -1 || close <= end) return null;
  final flameGroup = svg.substring(start, end + 4);
  return (
    whole: svg,
    body: svg.replaceRange(start, end + 4, ''),
    flame:
        svg.substring(0, frame + frameOpen.length) +
        flameGroup +
        svg.substring(close),
  );
}

/// The rocket, [size] square, pointing up and to the right; [angle] (in
/// radians, clockwise) turns it. With [flicker] the flame flickers as it
/// appears (not under reduce motion). The asset is read once for the app; until it is,
/// nothing shows, and an unreadable asset shows nothing at all.
class OnsetRocket extends StatefulWidget {
  const OnsetRocket({
    super.key,
    this.size = 24,
    this.angle = 0,
    this.flicker = false,
  });

  final double size;
  final double angle;
  final bool flicker;

  @override
  State<OnsetRocket> createState() => _OnsetRocketState();
}

/// The drawing, read once for the app.
Future<RocketArt?>? _art;
RocketArt? _loaded;

/// Tests: the drawing, as if already read ([svg] null forgets it).
@visibleForTesting
void debugSetRocketArt(String? svg) {
  _loaded = svg == null
      ? null
      : splitRocketSvg(svg) ?? (whole: svg, body: svg, flame: '');
  _art = svg == null ? null : Future.value(_loaded);
}

/// Half-flickers of the flame as the rocket appears (about 2.4 s).
const _flickerCount = 22;

class _OnsetRocketState extends State<OnsetRocket>
    with SingleTickerProviderStateMixin {
  static RocketArt _artOfSvg(String svg) =>
      splitRocketSvg(svg) ?? (whole: svg, body: svg, flame: '');

  static Future<RocketArt?> _load(AssetBundle bundle) async {
    try {
      final svg = await bundle.loadString(kRocketAsset);
      return _loaded = _artOfSvg(svg);
    } on Object catch (e) {
      debugPrint('OnsetRocket: $e');
      // Asked again next time (a test bundle, a transient failure).
      _art = null;
      return null;
    }
  }

  RocketArt? _rocket = _loaded;

  AnimationController? _flame;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rocket == null) {
      final art = _art ??= _load(DefaultAssetBundle.of(context));
      art.then((value) {
        if (!mounted || value == null) return;
        setState(() => _rocket = value);
        _syncFlame();
      });
    }
    _syncFlame();
  }

  @override
  void didUpdateWidget(OnsetRocket oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFlame();
  }

  bool get _flickers =>
      widget.flicker &&
      !reduceMotionOf(context) &&
      (_rocket?.flame.isNotEmpty ?? false);

  void _syncFlame() {
    if (_flickers) {
      if (_flame != null) return;
      // A burst as it appears, then a still flame: nothing loops for the
      // whole raid.
      _flame = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 110),
      )..repeat(reverse: true, count: _flickerCount);
    } else {
      _flame?.stop();
    }
  }

  @override
  void dispose() {
    _flame?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final rocket = _rocket;
    Widget child;
    if (rocket == null) {
      child = const SizedBox.shrink();
    } else if (_flickers && _flame != null) {
      // Where the flame leaves the nozzle, in the drawing's 120 box: the
      // flame stretches from there along the rocket's axis (45°).
      final k = size / 120;
      final nozzle = Offset(60 - 19 * math.sqrt1_2, 60 + 19 * math.sqrt1_2) * k;
      final flame = _flame!;
      child = Stack(
        alignment: Alignment.topLeft,
        children: [
          AnimatedBuilder(
            animation: flame,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(flame.value);
              final sx = 0.94 + 0.10 * t;
              final sy = 0.82 + 0.30 * t;
              final matrix = Matrix4.identity()
                ..translateByDouble(nozzle.dx, nozzle.dy, 0, 1)
                ..rotateZ(math.pi / 4)
                ..scaleByDouble(sx, sy, 1, 1)
                ..rotateZ(-math.pi / 4)
                ..translateByDouble(-nozzle.dx, -nozzle.dy, 0, 1);
              return Transform(transform: matrix, child: child);
            },
            child: SvgPicture.string(rocket.flame, width: size, height: size),
          ),
          SvgPicture.string(rocket.body, width: size, height: size),
        ],
      );
    } else {
      child = SvgPicture.string(rocket.whole, width: size, height: size);
    }
    if (widget.angle != 0) {
      child = Transform.rotate(angle: widget.angle, child: child);
    }
    return ExcludeSemantics(
      child: SizedBox.square(dimension: size, child: child),
    );
  }
}

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:onset/models/celebration.dart';
import 'package:onset/screens/channel/celebrations/particles/celebration_particles.dart';
import 'package:onset/screens/channel/celebrations/particles/celebration_sprites.dart';
import 'package:onset/theme.dart';

/// Draws a celebration [preset] at [progress], filling the space it is given.
///
/// One [CustomPainter] repainting on [progress] — no widget per particle, no
/// ticker of its own: whoever owns [progress] owns the timing. Behind a
/// [RepaintBoundary] so a frame of particles repaints only itself, never the
/// player or the chat under it.
class CelebrationParticles extends StatefulWidget {
  final CelebrationPreset preset;
  final Animation<double> progress;
  final Duration duration;
  final int seed;

  /// A short still flash instead of moving particles.
  final bool reduceMotion;

  const CelebrationParticles({
    super.key,
    required this.preset,
    required this.progress,
    required this.duration,
    required this.seed,
    this.reduceMotion = false,
  });

  @override
  State<CelebrationParticles> createState() => _CelebrationParticlesState();
}

class _CelebrationParticlesState extends State<CelebrationParticles> {
  /// Celebrations on screen; the laid-out glyphs go with the last one.
  static var _live = 0;

  late CelebrationSimulation _simulation = _simulate();

  CelebrationSimulation _simulate() => CelebrationSimulation(
    preset: widget.preset,
    duration: widget.duration,
    seed: widget.seed,
    reduceMotion: widget.reduceMotion,
  );

  @override
  void initState() {
    super.initState();
    _live++;
    if (CelebrationSprites.images == null) {
      unawaited(
        CelebrationSprites.load().then((_) {
          // A paused or very short celebration would otherwise keep its
          // stand-in sparks until its next frame.
          if (mounted && CelebrationSprites.images != null) setState(() {});
        }),
      );
    }
  }

  @override
  void didUpdateWidget(CelebrationParticles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preset != widget.preset ||
        oldWidget.duration != widget.duration ||
        oldWidget.seed != widget.seed ||
        oldWidget.reduceMotion != widget.reduceMotion) {
      _simulation = _simulate();
    }
  }

  @override
  void dispose() {
    if (--_live == 0) _Glyphs.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: CelebrationPainter(
          simulation: _simulation,
          progress: widget.progress,
          sprites: CelebrationSprites.images,
        ),
      ),
    );
  }
}

/// Paints a [CelebrationSimulation] at the [progress] it is told.
class CelebrationPainter extends CustomPainter {
  final CelebrationSimulation simulation;
  final Animation<double> progress;
  final Map<CelebrationSprite, ui.Image>? sprites;

  CelebrationPainter({
    required this.simulation,
    required this.progress,
    required this.sprites,
  }) : super(repaint: progress);

  /// Reused frame after frame: a celebration allocates no draw buffers.
  final _atlas = _Atlas();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.isFinite) return;
    final frames = simulation.frameAt(progress.value);
    if (frames.isEmpty) return;

    final unit = size.shortestSide;
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final atlas = _atlas;
    final glow = CelebrationSprites.glow;
    final paint = Paint()..isAntiAlias = true;

    // Drawn in the simulation's order (back to front). Consecutive particles
    // of the same image share one atlas draw; anything else drawn in between
    // sends the pending ones first, so the stacking holds.
    for (final f in frames) {
      final center = Offset(f.x * size.width, f.y * size.height);
      final extent = f.size * unit;
      if (extent <= 0) continue;

      final image = switch (f.shape) {
        ParticleShape.sprite => sprites?[f.sprite],
        ParticleShape.glow || ParticleShape.dot => glow,
        _ => null,
      };
      if (image == null) atlas.flush(canvas);

      switch (f.shape) {
        case ParticleShape.sprite:
          if (image == null) {
            _vectorSpark(canvas, paint, f, center, extent);
          } else {
            atlas.add(canvas, image, f, center, extent);
          }
        case ParticleShape.rect:
          canvas.save();
          canvas.translate(center.dx, center.dy);
          canvas.rotate(f.rotation);
          // A confetto turning over: never quite edge-on, so it flickers
          // rather than vanishing.
          canvas.scale(1, math.max(f.flip.abs(), 0.12));
          paint
            ..style = PaintingStyle.fill
            ..shader = null
            ..color = f.color.withValues(alpha: f.opacity);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: extent,
                height: extent * f.aspect,
              ),
              Radius.circular(extent * 0.25),
            ),
            paint,
          );
          canvas.restore();
        case ParticleShape.glow:
          // The image's radius is half its width: a glow of radius [extent].
          atlas.add(canvas, glow, f, center, extent * 2);
        case ParticleShape.dot:
          // An ember: a coloured halo around a hotter, paler core.
          atlas.add(canvas, glow, f, center, extent * 2);
          atlas.add(
            canvas,
            glow,
            f,
            center,
            extent * 0.7,
            color: Color.lerp(f.color, CelebrationPalette.white, 0.6),
          );
        case ParticleShape.ring:
          paint
            ..style = PaintingStyle.stroke
            ..shader = null
            ..strokeWidth = math.max(f.stroke * unit, 0.5)
            ..color = f.color.withValues(alpha: f.opacity);
          canvas.drawCircle(center, extent, paint);
        case ParticleShape.arc:
          paint
            ..style = PaintingStyle.stroke
            ..shader = null
            ..strokeCap = StrokeCap.round
            ..strokeWidth = math.max(f.stroke * unit, 0.5)
            ..color = f.color.withValues(alpha: f.opacity);
          final oval = Rect.fromCircle(center: center, radius: extent);
          canvas.drawArc(oval, f.arcStart, f.arcSweep, false, paint);
          canvas.drawArc(oval, f.arcStart + math.pi, f.arcSweep, false, paint);
          paint.strokeCap = StrokeCap.butt;
        case ParticleShape.glyph:
          final glyph = _Glyphs.of(f.color, f.opacity);
          final scale = extent / _Glyphs.fontSize;
          canvas.save();
          canvas.translate(center.dx, center.dy);
          canvas.rotate(f.rotation);
          canvas.scale(scale);
          glyph.paint(canvas, Offset(-glyph.width / 2, -glyph.height / 2));
          canvas.restore();
      }
    }

    atlas.flush(canvas);
    canvas.restore();
  }

  /// A four-point spark in the sprite's colour, for when the images are not
  /// decoded (yet).
  static void _vectorSpark(
    Canvas canvas,
    Paint paint,
    ParticleFrame f,
    Offset center,
    double extent,
  ) {
    final sprite = f.sprite ?? CelebrationSprite.white;
    final base =
        sprite == CelebrationSprite.white && f.color != CelebrationPalette.white
        ? f.color
        : sprite.fallback;
    paint
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = base.withValues(alpha: f.opacity);
    if (sprite == CelebrationSprite.dot) {
      canvas.drawCircle(center, extent / 2, paint);
      return;
    }
    final r = extent / 2;
    final w = r * 0.28;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(f.rotation);
    canvas.drawPath(
      Path()
        ..moveTo(0, -r)
        ..quadraticBezierTo(w * 0.4, -w * 0.4, r, 0)
        ..quadraticBezierTo(w * 0.4, w * 0.4, 0, r)
        ..quadraticBezierTo(-w * 0.4, w * 0.4, -r, 0)
        ..quadraticBezierTo(-w * 0.4, -w * 0.4, 0, -r)
        ..close(),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(CelebrationPainter oldDelegate) =>
      oldDelegate.simulation != simulation ||
      oldDelegate.progress != progress ||
      oldDelegate.sprites != sprites;
}

/// Consecutive particles of one image, drawn in a single
/// [Canvas.drawRawAtlas] from buffers allocated once.
class _Atlas {
  /// Every particle twice over: an ember is a halo and a core.
  static const _capacity = kMaxCelebrationParticles * 2;

  final _transforms = Float32List(_capacity * 4);
  final _rects = Float32List(_capacity * 4);
  final _colors = Int32List(_capacity);
  final _paint = Paint()..filterQuality = FilterQuality.low;
  ui.Image? _image;
  var _count = 0;

  /// Queues [f] drawn from [image], [extent] wide, centred on [center], in
  /// [color] (else the particle's own) multiplied into the image.
  void add(
    Canvas canvas,
    ui.Image image,
    ParticleFrame f,
    Offset center,
    double extent, {
    Color? color,
  }) {
    if (!identical(_image, image) || _count == _capacity) flush(canvas);
    _image = image;

    final w = image.width.toDouble();
    final h = image.height.toDouble();
    final scale = extent / w;
    final scos = math.cos(f.rotation) * scale;
    final ssin = math.sin(f.rotation) * scale;
    final i = _count * 4;
    // An RSTransform rotating and scaling about the image's centre, then
    // placing that centre on [center].
    _transforms[i] = scos;
    _transforms[i + 1] = ssin;
    _transforms[i + 2] = center.dx - scos * w / 2 + ssin * h / 2;
    _transforms[i + 3] = center.dy - ssin * w / 2 - scos * h / 2;
    _rects[i] = 0;
    _rects[i + 1] = 0;
    _rects[i + 2] = w;
    _rects[i + 3] = h;
    // White keeps the image's colours, another colour tints it, the alpha
    // fades it.
    _colors[_count] = (color ?? f.color)
        .withValues(alpha: f.opacity)
        .toARGB32();
    _count++;
  }

  /// Draws what is queued.
  void flush(Canvas canvas) {
    final image = _image;
    if (_count == 0 || image == null) return;
    canvas.drawRawAtlas(
      image,
      Float32List.sublistView(_transforms, 0, _count * 4),
      Float32List.sublistView(_rects, 0, _count * 4),
      Int32List.sublistView(_colors, 0, _count),
      BlendMode.modulate,
      null,
      _paint,
    );
    _count = 0;
  }
}

/// The "?" of the question marks, laid out once per colour and fade step.
abstract final class _Glyphs {
  static const fontSize = 64.0;

  /// Fades are drawn in 16 steps: enough to look smooth on a particle this
  /// brief, and it keeps the cache to a few dozen laid-out glyphs.
  static const _steps = 16;
  static final _cache = <int, TextPainter>{};

  /// Releases the laid-out glyphs.
  static void clear() {
    for (final painter in _cache.values) {
      painter.dispose();
    }
    _cache.clear();
  }

  static TextPainter of(Color color, double opacity) {
    final step = (opacity.clamp(0.0, 1.0) * _steps).round();
    final key = (color.toARGB32() & 0xFFFFFF) | (step << 24);
    return _cache[key] ??= TextPainter(
      text: TextSpan(
        text: '?',
        style: TextStyle(
          fontFamily: OnsetTokens.displayFamily,
          fontWeight: FontWeight.w800,
          fontSize: fontSize,
          height: 1,
          color: color.withValues(alpha: step / _steps),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }
}

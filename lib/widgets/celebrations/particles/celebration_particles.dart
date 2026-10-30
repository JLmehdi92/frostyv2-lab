import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:onset/models/celebration.dart';

/// The most particles a celebration ever draws at once. Every preset stays
/// under it whatever the duration, so a 15 s celebration costs what a 4 s one
/// does.
const kMaxCelebrationParticles = 120;

/// How long a celebration lasts when the viewer reduces motion: a short still
/// flash of a few sparks, nothing travelling.
const kReducedCelebrationDuration = Duration(milliseconds: 360);

/// ONSET's celebration palette.
abstract final class CelebrationPalette {
  static const lime = Color(0xFFC8FF3D);
  static const mint = Color(0xFF3DDBA6);
  static const green = Color(0xFF12A87A);
  static const white = Color(0xFFF5F5F5);

  /// Only for heat: the flame and the explosion.
  static const orange = Color(0xFFFF7A45);
}

/// The spark images of `assets/celebrations/` (the user's own art).
enum CelebrationSprite {
  lime('assets/celebrations/spark_lime.png', CelebrationPalette.lime),
  mint('assets/celebrations/spark_mint.png', CelebrationPalette.mint),
  white('assets/celebrations/spark_white.png', CelebrationPalette.white),
  dot('assets/celebrations/spark_dot.png', CelebrationPalette.green);

  final String asset;

  /// Drawn as a plain vector spark of this colour until the image is decoded.
  final Color fallback;

  const CelebrationSprite(this.asset, this.fallback);
}

/// How a particle is drawn.
enum ParticleShape {
  /// A [CelebrationSprite], optionally tinted.
  sprite,

  /// A small rounded rectangle (confetti), [aspect] tall for its width.
  rect,

  /// A soft round glow fading to nothing at its edge.
  glow,

  /// A filled dot with a faint halo (embers).
  dot,

  /// A circle outline; [size] is its radius.
  ring,

  /// Part of a circle outline from [arcStart] over [arcSweep]; [size] is its
  /// radius.
  arc,

  /// A "?" set in Inter; [size] is its height.
  glyph,
}

/// One particle at one instant.
///
/// [x] and [y] are fractions of the area (0 to 1 across, 0 to 1 down);
/// [size], [stroke] are fractions of the area's shorter side.
@immutable
class ParticleFrame {
  final ParticleShape shape;
  final CelebrationSprite? sprite;
  final Color color;
  final double x;
  final double y;
  final double size;
  final double aspect;
  final double rotation;

  /// Squashes the particle vertically, -1 to 1: a confetto turning over.
  final double flip;
  final double opacity;
  final double stroke;
  final double arcStart;
  final double arcSweep;

  /// Paint it after the others (in front of them).
  final double depth;

  const ParticleFrame({
    required this.shape,
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    this.sprite,
    this.color = CelebrationPalette.white,
    this.aspect = 1,
    this.rotation = 0,
    this.flip = 1,
    this.stroke = 0,
    this.arcStart = 0,
    this.arcSweep = 0,
    this.depth = 0,
  });
}

/// A celebration's particles, worked out from a seed.
///
/// Everything is a pure function of the seed, the duration and the progress:
/// the same celebration draws the same thing on every run, any instant can be
/// drawn without playing the ones before it, and nothing accumulates frame to
/// frame.
class CelebrationSimulation {
  final CelebrationPreset preset;
  final bool reduceMotion;

  /// Seconds.
  final double _total;
  final List<_Seed> _seeds;

  CelebrationSimulation({
    required this.preset,
    required Duration duration,
    required int seed,
    this.reduceMotion = false,
  }) : _total = math.max(duration.inMicroseconds / 1e6, 0.1),
       _seeds = _build(
         preset,
         math.max(duration.inMicroseconds / 1e6, 0.1),
         math.Random(seed),
         reduceMotion,
       ) {
    assert(_seeds.length <= kMaxCelebrationParticles);
  }

  /// How many particles this celebration has in all.
  int get particleCount => _seeds.length;

  /// The particles at [progress] (0 to 1 of the duration), back to front.
  List<ParticleFrame> frameAt(double progress) {
    final p = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);
    final seconds = p * _total;
    final frames = <ParticleFrame>[];
    for (final seed in _seeds) {
      final local = seed.life <= 0 ? 1.0 : (seconds - seed.start) / seed.life;
      if (local < 0 || local > 1) continue;
      final frame = reduceMotion
          ? _still(seed, p)
          : _frame(preset, seed, local, seconds - seed.start);
      if (frame != null && frame.opacity > 0.001) frames.add(frame);
    }
    if (preset == CelebrationPreset.starBonk) {
      frames.sort((a, b) => a.depth.compareTo(b.depth));
    }
    return frames;
  }
}

/// A particle's fixed traits, drawn once from the seed.
class _Seed {
  final int kind;
  final CelebrationSprite? sprite;
  final Color color;

  /// When it appears and how long it lives, in seconds.
  final double start;
  final double life;
  final double x;
  final double y;
  final double size;

  /// Preset-specific random values, each in 0..1 unless noted.
  final double a;
  final double b;
  final double c;
  final double d;

  const _Seed({
    required this.start,
    required this.life,
    this.kind = 0,
    this.sprite,
    this.color = CelebrationPalette.white,
    this.x = 0.5,
    this.y = 0.5,
    this.size = 0.05,
    this.a = 0,
    this.b = 0,
    this.c = 0,
    this.d = 0,
  });
}

// ── Building ────────────────────────────────────────────────────────────────

List<_Seed> _build(
  CelebrationPreset preset,
  double total,
  math.Random r,
  bool reduceMotion,
) {
  if (reduceMotion) return _buildStill(preset, total, r);
  final seeds = switch (preset) {
    CelebrationPreset.confetti => _buildConfetti(total, r),
    CelebrationPreset.explosion => _buildExplosion(total, r),
    CelebrationPreset.flame => _buildFlame(total, r),
    CelebrationPreset.loud => _buildLoud(total, r),
    CelebrationPreset.onboardingSparkles => _buildTwinkles(total, r),
    CelebrationPreset.questionMarks => _buildQuestionMarks(total, r),
    CelebrationPreset.sparkles => _buildSparkles(total, r),
    CelebrationPreset.starBonk => _buildStarBonk(total, r),
  };
  return seeds.length > kMaxCelebrationParticles
      ? seeds.sublist(0, kMaxCelebrationParticles)
      : seeds;
}

/// A lifetime of [base] seconds, shortened to fit a short celebration.
double _life(double base, double total) => math.min(base, total * 0.9);

/// A start time leaving room for [life] before the end.
double _startIn(math.Random r, double total, double life) =>
    r.nextDouble() * math.max(0, total - life);

/// How long each of [waves] waves lasts so they keep the area busy without
/// a gap: [shortest] at least, slowed down to [longest] when there is room.
double _waveLife(double total, int waves, double shortest, double longest) =>
    _life((total / waves * 1.05).clamp(shortest, longest), total);

/// Evenly spread starts of [count] waves of [life] seconds.
double _wave(int index, int count, double total, double life) =>
    count <= 1 ? 0 : index * math.max(0, total - life) / (count - 1);

int _count(double perSecond, double total, int min, int max) =>
    (perSecond * total).round().clamp(min, max);

double _between(math.Random r, double from, double to) =>
    from + r.nextDouble() * (to - from);

const _sparkCycle = [
  CelebrationSprite.lime,
  CelebrationSprite.white,
  CelebrationSprite.mint,
];

/// Same spots as the board's "Étincelles", for the still flash.
const _stillSpots = [
  (0.14, 0.2, 0.09),
  (0.84, 0.16, 0.08),
  (0.88, 0.6, 0.11),
  (0.16, 0.66, 0.07),
  (0.5, 0.42, 0.1),
];

List<_Seed> _buildStill(CelebrationPreset preset, double total, math.Random r) {
  final hot =
      preset == CelebrationPreset.flame ||
      preset == CelebrationPreset.explosion;
  // Offset by the seed so two celebrations do not flash the same pattern.
  final turn = r.nextInt(_sparkCycle.length);
  return [
    for (final (i, (x, y, s)) in _stillSpots.indexed)
      _Seed(
        start: 0,
        life: total,
        sprite: hot && i.isEven
            ? CelebrationSprite.white
            : _sparkCycle[(i + turn) % _sparkCycle.length],
        color: hot && i.isEven
            ? CelebrationPalette.orange
            : CelebrationPalette.white,
        kind: hot && i.isEven ? 1 : 0,
        x: x,
        y: y,
        size: s,
        a: r.nextDouble(),
      ),
  ];
}

/// The board's confetti: lime, green, mint and white bits, 5–8 × 9–14 dp on a
/// 270 dp fall, 2.1–3 s each, swaying and turning over as they fall.
List<_Seed> _buildConfetti(double total, math.Random r) {
  const palette = [
    CelebrationPalette.lime,
    CelebrationPalette.green,
    CelebrationPalette.mint,
    CelebrationPalette.white,
  ];
  final count = _count(30 / 3.6, total, 30, 96);
  return [
    for (var i = 0; i < count; i++)
      () {
        final life = _life(_between(r, 2.1, 3.0), total);
        return _Seed(
          start: _startIn(r, total, life),
          life: life,
          color: palette[i % palette.length],
          x: _between(r, 0.02, 0.98),
          y: -0.06,
          size: _between(r, 5, 8) / 270,
          // Height for width.
          a: _between(r, 9, 14) / _between(r, 5, 8),
          // Sway: amplitude and half period.
          b: _between(r, 6, 20) / 270,
          c: _between(r, 0.7, 1.3),
          // Turn-over period, and a fixed tilt.
          d: _between(r, 0.5, 1.2),
          kind: r.nextInt(180),
        );
      }(),
  ];
}

/// Waves of: a white core, two shock rings, and sparks flung outwards.
List<_Seed> _buildExplosion(double total, math.Random r) {
  final waves = (total / 1.4).ceil().clamp(1, 4);
  final life = _waveLife(total, waves, 1.5, 3.2);
  const sparks = 22;
  return [
    for (var w = 0; w < waves; w++) ...[
      _Seed(start: _wave(w, waves, total, life), life: life),
      _Seed(
        kind: 1,
        start: _wave(w, waves, total, life),
        life: life,
        color: CelebrationPalette.orange,
      ),
      _Seed(
        kind: 2,
        start: _wave(w, waves, total, life) + life * 0.08,
        life: life * 0.92,
      ),
      for (var i = 0; i < sparks; i++)
        _Seed(
          kind: 3,
          start: _wave(w, waves, total, life),
          life: life * _between(r, 0.75, 1),
          sprite: i % 3 == 0 ? CelebrationSprite.lime : CelebrationSprite.white,
          color: i % 3 == 1
              ? CelebrationPalette.orange
              : CelebrationPalette.white,
          size: _between(r, 0.05, 0.085),
          // Direction, reach, spin.
          a: (i / sparks) * math.pi * 2 + _between(r, -0.18, 0.18),
          b: _between(r, 0.26, 0.46),
          c: _between(r, -6, 6),
        ),
    ],
  ];
}

/// Tongues of light flickering at the bottom, embers rising from them.
List<_Seed> _buildFlame(double total, math.Random r) {
  final embers = _count(18, total, 24, 100);
  return [
    for (var i = 0; i < 5; i++)
      _Seed(
        start: 0,
        life: total,
        color: i.isEven ? CelebrationPalette.orange : CelebrationPalette.lime,
        x: 0.3 + i * 0.1 + _between(r, -0.03, 0.03),
        y: 1.0,
        size: _between(r, 0.2, 0.28),
        a: r.nextDouble() * math.pi * 2,
        b: r.nextDouble() * math.pi * 2,
      ),
    for (var i = 0; i < embers; i++)
      () {
        final life = _life(_between(r, 0.9, 1.7), total);
        // Clustered at the middle, as a fire is.
        final spread =
            (r.nextDouble() + r.nextDouble() + r.nextDouble()) / 3 - 0.5;
        return _Seed(
          kind: i % 3 == 0 ? 2 : 1,
          start: _startIn(r, total, life),
          life: life,
          sprite: CelebrationSprite.white,
          color: CelebrationPalette.orange,
          x: 0.5 + spread * 0.6,
          y: 1.02,
          size: _between(r, 0.025, 0.05),
          // Rise, flicker frequency, flicker phase, drift.
          a: _between(r, 0.5, 0.9),
          b: _between(r, 3, 6),
          c: r.nextDouble() * math.pi * 2,
          d: _between(r, -0.08, 0.08),
        );
      }(),
  ];
}

/// Rings and paired arcs pulsing out from a beating dot.
List<_Seed> _buildLoud(double total, math.Random r) {
  final life = _life(1.25, total);
  final pulses = (total / 0.42).floor().clamp(2, 40);
  return [
    _Seed(start: 0, life: total, sprite: CelebrationSprite.dot),
    for (var i = 0; i < pulses; i++)
      _Seed(
        kind: i.isEven ? 1 : 2,
        start: _wave(i, pulses, total, life),
        life: life,
        color: i.isEven ? CelebrationPalette.lime : CelebrationPalette.mint,
        // Arc tilt, and how far the pulse carries.
        a: _between(r, -0.2, 0.2),
        b: _between(r, 0.34, 0.44),
      ),
  ];
}

/// Soft twinkles appearing one after another.
List<_Seed> _buildTwinkles(double total, math.Random r) {
  final count = _count(4, total, 10, 48);
  return [
    for (var i = 0; i < count; i++)
      () {
        final life = _life(1.5, total);
        final pick = r.nextDouble();
        return _Seed(
          start: _startIn(r, total, life),
          life: life,
          sprite: pick < 0.5
              ? CelebrationSprite.white
              : pick < 0.8
              ? CelebrationSprite.mint
              : CelebrationSprite.lime,
          x: _between(r, 0.08, 0.92),
          y: _between(r, 0.1, 0.9),
          size: _between(r, 0.05, 0.09),
          a: r.nextDouble() * math.pi,
        );
      }(),
  ];
}

List<_Seed> _buildQuestionMarks(double total, math.Random r) {
  const colors = [
    CelebrationPalette.lime,
    CelebrationPalette.mint,
    CelebrationPalette.white,
  ];
  final count = _count(3, total, 6, 36);
  return [
    for (var i = 0; i < count; i++)
      () {
        final life = _life(1.9, total);
        return _Seed(
          start: _startIn(r, total, life),
          life: life,
          color: colors[i % colors.length],
          x: _between(r, 0.1, 0.9),
          y: _between(r, 0.55, 0.92),
          size: _between(r, 0.09, 0.15),
          // Rise, tilt, wobble phase.
          a: _between(r, 0.22, 0.36),
          b: _between(r, -0.25, 0.25),
          c: r.nextDouble() * math.pi * 2,
        );
      }(),
  ];
}

/// Waves of stars thrown out from the middle, each twinkling as on the
/// board (grow and turn 45° by 45 %, shrink and turn on to 90°).
List<_Seed> _buildSparkles(double total, math.Random r) {
  final waves = (total / 1.4).ceil().clamp(1, 6);
  final life = _waveLife(total, waves, 1.5, 2.6);
  const stars = 16;
  return [
    for (var w = 0; w < waves; w++) ...[
      _Seed(
        start: _wave(w, waves, total, life),
        life: life * 0.3,
        color: CelebrationPalette.lime,
      ),
      for (var i = 0; i < stars; i++)
        _Seed(
          kind: 1,
          start: _wave(w, waves, total, life) + _between(r, 0, life * 0.12),
          life: life * _between(r, 0.82, 0.88),
          sprite: _sparkCycle[i % _sparkCycle.length],
          size: _between(r, 0.06, 0.11),
          a: (i / stars) * math.pi * 2 + _between(r, -0.3, 0.3),
          b: _between(r, 0.18, 0.42),
          c: r.nextDouble() * math.pi / 4,
        ),
    ],
  ];
}

/// Stars circling a dazed head, and more dropping in and bouncing.
List<_Seed> _buildStarBonk(double total, math.Random r) {
  final bouncers = _count(1.6, total, 3, 24);
  return [
    for (var i = 0; i < 6; i++)
      _Seed(
        start: 0,
        life: total,
        sprite: i.isEven ? CelebrationSprite.lime : CelebrationSprite.white,
        size: _between(r, 0.075, 0.095),
        a: i / 6 * math.pi * 2,
      ),
    for (var i = 0; i < bouncers; i++)
      () {
        final life = _life(1.6, total);
        return _Seed(
          kind: 1,
          start: _startIn(r, total, life),
          life: life,
          sprite: _sparkCycle[i % _sparkCycle.length],
          x: _between(r, 0.15, 0.85),
          y: _between(r, -0.08, 0.1),
          size: _between(r, 0.06, 0.09),
          // Drift, spin.
          a: _between(r, -0.06, 0.06),
          b: _between(r, -2, 2),
        );
      }(),
  ];
}

// ── Drawing an instant ──────────────────────────────────────────────────────

/// 0→1 over [fadeIn], 1, then 1→0 from [fadeOut] to the end.
double _window(double p, double fadeIn, double fadeOut) {
  if (p < fadeIn) return fadeIn <= 0 ? 1 : p / fadeIn;
  if (p > fadeOut) return fadeOut >= 1 ? 1 : (1 - p) / (1 - fadeOut);
  return 1;
}

double _clamp01(double v) => v.clamp(0.0, 1.0);

const _fall = Cubic(0.45, 0.05, 0.75, 0.6);

ParticleFrame _still(_Seed s, double p) => ParticleFrame(
  shape: ParticleShape.sprite,
  sprite: s.sprite,
  color: s.color,
  x: s.x,
  y: s.y,
  size: s.size,
  rotation: s.a * math.pi / 4,
  // The flash itself: in over the first third, out over the last.
  opacity: _clamp01(_window(p, 0.3, 0.6)),
);

ParticleFrame? _frame(
  CelebrationPreset preset,
  _Seed s,
  double p,
  double age,
) => switch (preset) {
  CelebrationPreset.confetti => _confetti(s, p, age),
  CelebrationPreset.explosion => _explosion(s, p),
  CelebrationPreset.flame => _flame(s, p, age),
  CelebrationPreset.loud => _loud(s, p, age),
  CelebrationPreset.onboardingSparkles => _twinkle(s, p),
  CelebrationPreset.questionMarks => _questionMark(s, p, age),
  CelebrationPreset.sparkles => _sparkle(s, p),
  CelebrationPreset.starBonk => _starBonk(s, p, age),
};

ParticleFrame _confetti(_Seed s, double p, double age) {
  // Sway back and forth (ease-in-out, alternating) and turn over.
  final sway = math.sin(age * math.pi / s.c) * s.b;
  return ParticleFrame(
    shape: ParticleShape.rect,
    color: s.color,
    x: s.x + sway,
    y: s.y + _fall.transform(p) * 1.12,
    size: s.size,
    aspect: s.a,
    rotation: s.kind * math.pi / 180,
    flip: math.cos(age * math.pi * 2 / s.d),
    opacity: _clamp01(_window(p, 0.08, 0.78)),
  );
}

ParticleFrame? _explosion(_Seed s, double p) {
  final out = Curves.easeOutCubic.transform(p);
  switch (s.kind) {
    case 0:
      // The white core: gone within a quarter.
      if (p > 0.25) return null;
      final q = p / 0.25;
      return ParticleFrame(
        shape: ParticleShape.glow,
        x: 0.5,
        y: 0.5,
        size: 0.06 + 0.12 * Curves.easeOut.transform(q),
        opacity: _clamp01(0.9 * (1 - q)),
      );
    case 1 || 2:
      return ParticleFrame(
        shape: ParticleShape.ring,
        color: s.color,
        x: 0.5,
        y: 0.5,
        size: 0.04 + (s.kind == 1 ? 0.44 : 0.36) * out,
        stroke: (s.kind == 1 ? 0.035 : 0.018) * (1 - p) + 0.003,
        opacity: _clamp01(0.9 * math.pow(1 - p, 1.5).toDouble()),
      );
    default:
      final reach = s.b * out;
      return ParticleFrame(
        shape: ParticleShape.sprite,
        sprite: s.sprite,
        color: s.color,
        x: 0.5 + math.cos(s.a) * reach,
        // A little gravity as they slow down.
        y: 0.5 + math.sin(s.a) * reach + 0.08 * p * p,
        size: s.size * (1 - 0.6 * p),
        rotation: s.c * p,
        opacity: _clamp01(_window(p, 0.04, 0.55)),
      );
  }
}

ParticleFrame _flame(_Seed s, double p, double age) {
  if (s.kind == 0) {
    // A tongue: its size and light flicker on two out-of-step beats.
    final flicker =
        math.sin(age * 13 + s.a) * 0.5 + math.sin(age * 7.3 + s.b) * 0.5;
    final total = s.life;
    final edge = _clamp01(math.min(age / 0.25, (total - age) / 0.4));
    return ParticleFrame(
      shape: ParticleShape.glow,
      color: s.color,
      x: s.x + flicker * 0.01,
      y: s.y,
      size: s.size * (0.88 + 0.12 * flicker),
      opacity: _clamp01((0.5 + 0.15 * flicker) * edge),
    );
  }
  final heat = p < 0.35
      ? Color.lerp(
          CelebrationPalette.white,
          CelebrationPalette.orange,
          p / 0.35,
        )!
      : CelebrationPalette.orange;
  final wobble = math.sin(age * math.pi * 2 * s.b + s.c) * 0.025 * p;
  return ParticleFrame(
    shape: s.kind == 2 ? ParticleShape.sprite : ParticleShape.dot,
    sprite: s.sprite,
    color: heat,
    x: s.x + wobble + s.d * p,
    y: s.y - s.a * Curves.easeOut.transform(p),
    size: s.size * (1 - 0.7 * p),
    rotation: s.c + p * 2,
    opacity: _clamp01(_window(p, 0.1, 0.55)),
  );
}

ParticleFrame _loud(_Seed s, double p, double age) {
  if (s.kind == 0) {
    // The source, beating with each pulse.
    final beat = math.exp(-((age % 0.42) / 0.12));
    final edge = _clamp01(math.min(age / 0.2, (s.life - age) / 0.3));
    return ParticleFrame(
      shape: ParticleShape.sprite,
      sprite: s.sprite,
      x: 0.5,
      y: 0.5,
      size: 0.11 * (1 + 0.2 * beat),
      opacity: edge,
      depth: 1,
    );
  }
  final out = Curves.easeOutCubic.transform(p);
  final fade = _clamp01(0.95 * math.pow(1 - p, 1.4).toDouble());
  final radius = 0.08 + s.b * out;
  final stroke = 0.03 * (1 - p) + 0.006;
  if (s.kind == 1) {
    return ParticleFrame(
      shape: ParticleShape.ring,
      color: s.color,
      x: 0.5,
      y: 0.5,
      size: radius,
      stroke: stroke,
      opacity: fade,
    );
  }
  // Sound waves: a pair of arcs, one each side.
  return ParticleFrame(
    shape: ParticleShape.arc,
    color: s.color,
    x: 0.5,
    y: 0.5,
    size: radius,
    stroke: stroke,
    arcStart: -0.6 + s.a,
    arcSweep: 1.2,
    opacity: fade,
  );
}

ParticleFrame _twinkle(_Seed s, double p) {
  final swell = math.sin(math.pi * p);
  return ParticleFrame(
    shape: ParticleShape.sprite,
    sprite: s.sprite,
    x: s.x,
    y: s.y - 0.03 * p,
    size: s.size * swell,
    rotation: s.a + p * math.pi / 2,
    opacity: _clamp01(0.85 * swell),
  );
}

ParticleFrame _questionMark(_Seed s, double p, double age) {
  final pop = p < 0.18 ? Curves.easeOutBack.transform(p / 0.18) : 1.0;
  return ParticleFrame(
    shape: ParticleShape.glyph,
    color: s.color,
    x: s.x,
    y: s.y - s.a * Curves.easeOut.transform(p),
    size: s.size * math.max(0, pop),
    rotation: s.b + 0.18 * math.sin(age * 4 + s.c),
    opacity: _clamp01(_window(p, 0.12, 0.7)),
  );
}

ParticleFrame _sparkle(_Seed s, double p) {
  if (s.kind == 0) {
    return ParticleFrame(
      shape: ParticleShape.glow,
      color: s.color,
      x: 0.5,
      y: 0.5,
      size: 0.08 + 0.1 * p,
      opacity: _clamp01(0.7 * (1 - p)),
    );
  }
  // The board's twinkle: scale 0 → 1 by 45 %, back to 0 at the end.
  final scale = p < 0.45
      ? Curves.easeOut.transform(p / 0.45)
      : 1 - Curves.easeIn.transform((p - 0.45) / 0.55);
  final reach = s.b * Curves.easeOutCubic.transform(p);
  return ParticleFrame(
    shape: ParticleShape.sprite,
    sprite: s.sprite,
    x: 0.5 + math.cos(s.a) * reach,
    y: 0.5 + math.sin(s.a) * reach,
    size: s.size * scale,
    rotation: s.c + p * math.pi / 2,
    opacity: _clamp01(scale * 1.2),
  );
}

ParticleFrame _starBonk(_Seed s, double p, double age) {
  if (s.kind == 0) {
    // Circling on a tilted ellipse: bigger and brighter at the front.
    final angle = s.a + age * math.pi * 2 / 1.6;
    final front = (math.sin(angle) + 1) / 2;
    final appear = Curves.easeOutBack.transform(_clamp01(age / 0.3));
    final leave = _clamp01((s.life - age) / 0.3);
    return ParticleFrame(
      shape: ParticleShape.sprite,
      sprite: s.sprite,
      x: 0.5 + math.cos(angle) * 0.3,
      y: 0.38 + math.sin(angle) * 0.1,
      size: s.size * (0.75 + 0.35 * front) * math.max(0, appear),
      rotation: angle,
      opacity: _clamp01((0.6 + 0.4 * front) * leave),
      depth: front,
    );
  }
  // Dropping in and bouncing on the floor, then fading where it lands.
  final fall = _clamp01(p / 0.75);
  const floor = 0.86;
  return ParticleFrame(
    shape: ParticleShape.sprite,
    sprite: s.sprite,
    x: s.x + s.a * p,
    y: s.y + (floor - s.y) * Curves.bounceOut.transform(fall),
    size: s.size,
    rotation: s.b * math.pi * 2 * p,
    opacity: _clamp01(_window(p, 0.06, 0.75)),
    depth: 0.5,
  );
}

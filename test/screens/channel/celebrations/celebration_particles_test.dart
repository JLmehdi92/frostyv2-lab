import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/celebration.dart';
import 'package:onset/screens/channel/celebrations/particles/celebration_particles.dart';

/// Progress values sampled across a whole celebration.
final _steps = [for (var i = 0; i <= 120; i++) i / 120];

CelebrationSimulation _sim(
  CelebrationPreset preset, {
  Duration duration = const Duration(seconds: 4),
  int seed = 7,
  bool reduceMotion = false,
}) => CelebrationSimulation(
  preset: preset,
  duration: duration,
  seed: seed,
  reduceMotion: reduceMotion,
);

/// What a frame looks like, to compare two runs value for value.
List<String> _describe(List<ParticleFrame> frames) => [
  for (final f in frames)
    '${f.shape.name} ${f.sprite?.name} ${f.x.toStringAsFixed(5)} '
        '${f.y.toStringAsFixed(5)} ${f.size.toStringAsFixed(5)} '
        '${f.rotation.toStringAsFixed(5)} ${f.opacity.toStringAsFixed(5)}',
];

void main() {
  test('every effect Twitch sends has a preset', () {
    expect(CelebrationEffect.fireworks.preset, CelebrationPreset.confetti);
    expect(
      CelebrationEffect.extinctionEvent.preset,
      CelebrationPreset.explosion,
    );
    expect(CelebrationEffect.flamethrower.preset, CelebrationPreset.flame);
    expect(CelebrationEffect.rain.preset, CelebrationPreset.sparkles);
    expect(CelebrationEffect.float.preset, CelebrationPreset.starBonk);
    expect(CelebrationEffect.unknown.preset, CelebrationPreset.sparkles);
  });

  test('eight presets, one per kind of motion', () {
    expect(CelebrationPreset.values.map((p) => p.name), [
      'confetti',
      'explosion',
      'flame',
      'loud',
      'onboardingSparkles',
      'questionMarks',
      'sparkles',
      'starBonk',
    ]);
  });

  for (final preset in CelebrationPreset.values) {
    group(preset.name, () {
      for (final duration in const [
        Duration(milliseconds: 500),
        Duration(seconds: 4),
        Duration(seconds: 15),
      ]) {
        test('at ${duration.inMilliseconds} ms: bounded, finite, drawn, '
            'then gone', () {
          final sim = _sim(preset, duration: duration);
          expect(
            sim.particleCount,
            lessThanOrEqualTo(kMaxCelebrationParticles),
          );

          var drawn = 0;
          for (final p in _steps) {
            final frames = sim.frameAt(p);
            expect(
              frames.length,
              lessThanOrEqualTo(kMaxCelebrationParticles),
              reason: 'at $p',
            );
            for (final f in frames) {
              for (final v in [f.x, f.y, f.size, f.rotation, f.opacity]) {
                expect(v.isFinite, isTrue, reason: '${f.shape} at $p');
              }
              expect(f.opacity, inInclusiveRange(0, 1));
              expect(f.size, greaterThanOrEqualTo(0));
            }
            if (p > 0.05 && p < 0.9) {
              drawn += frames.where((f) => f.opacity > 0.05).length;
            }
          }
          expect(drawn, greaterThan(0), reason: 'it must draw something');

          // Nothing left on screen once its time is up.
          final end = sim.frameAt(1);
          expect(
            end.fold<double>(0, (sum, f) => sum + f.opacity),
            lessThan(0.05),
          );
        });
      }

      test('the same seed draws the same thing, another seed does not', () {
        final a = _sim(preset);
        final b = _sim(preset);
        final c = _sim(preset, seed: 8);
        for (final p in [0.1, 0.35, 0.6]) {
          expect(_describe(a.frameAt(p)), _describe(b.frameAt(p)));
        }
        final differs = [0.1, 0.35, 0.6].any(
          (p) =>
              _describe(a.frameAt(p)).join() != _describe(c.frameAt(p)).join(),
        );
        expect(differs, isTrue);
      });

      test('reduce motion: a few still sparks, nothing moves', () {
        final sim = _sim(preset, reduceMotion: true);
        expect(sim.particleCount, inInclusiveRange(1, 6));
        final early = sim.frameAt(0.2);
        final late = sim.frameAt(0.8);
        expect(early, isNotEmpty);
        expect(
          early.map((f) => '${f.x} ${f.y} ${f.size} ${f.rotation}'),
          late.map((f) => '${f.x} ${f.y} ${f.size} ${f.rotation}'),
        );
      });
    });
  }

  test('confetti keeps the board size: 5-8 dp wide, 9-14 dp tall on 270', () {
    final sim = _sim(
      CelebrationPreset.confetti,
      duration: const Duration(seconds: 6),
    );
    var seen = 0;
    for (final p in _steps) {
      for (final f in sim.frameAt(p)) {
        seen++;
        expect(f.size * 270, inInclusiveRange(5 - 1e-9, 8 + 1e-9));
        expect(f.size * f.aspect * 270, inInclusiveRange(9 - 1e-9, 14 + 1e-9));
      }
    }
    expect(seen, greaterThan(100));
  });

  test('loud: the dot beats as each ring leaves it', () {
    final sim = _sim(CelebrationPreset.loud);
    double dotAt(double seconds) => sim
        .frameAt(seconds / 4)
        .firstWhere((f) => f.sprite == CelebrationSprite.dot)
        .size;
    // 9 pulses of 1.25 s spread over 4 s: one every 0.34375 s.
    const spacing = (4 - 1.25) / 8;
    for (var i = 1; i < 8; i++) {
      final onBeat = dotAt(i * spacing + 0.001);
      final between = dotAt(i * spacing + spacing / 2);
      expect(onBeat, greaterThan(between * 1.1), reason: 'pulse $i');
    }
  });

  test('out-of-range progress is clamped, never throws', () {
    for (final preset in CelebrationPreset.values) {
      final sim = _sim(preset);
      expect(() => sim.frameAt(-1), returnsNormally);
      expect(() => sim.frameAt(2), returnsNormally);
      expect(() => sim.frameAt(double.nan), returnsNormally);
    }
  });

  test('the reduced celebration is a short flash', () {
    expect(
      kReducedCelebrationDuration,
      lessThanOrEqualTo(const Duration(milliseconds: 400)),
    );
  });
}

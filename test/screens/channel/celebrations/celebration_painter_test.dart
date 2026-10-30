import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/celebration.dart';
import 'package:onset/screens/channel/celebrations/particles/celebration_particles.dart';
import 'package:onset/screens/channel/celebrations/particles/celebration_sprites.dart';
import 'package:onset/screens/channel/celebrations/particles/celebration_view.dart';

/// Serves the real assets, except that the first [failures] loads throw.
class _FlakyBundle extends CachingAssetBundle {
  int failures;

  _FlakyBundle(this.failures);

  @override
  Future<ByteData> load(String key) {
    if (failures > 0) {
      failures--;
      throw FlutterError('unreadable $key');
    }
    return rootBundle.load(key);
  }
}

void main() {
  tearDown(CelebrationSprites.reset);

  testWidgets('particles are painted back to front, glows included', (
    tester,
  ) async {
    // The explosion lists its white core (a glow) before its shock rings and
    // its sparks: the core must not end up painted over them.
    CelebrationSprites.reset();
    await tester.pumpWidget(
      const Center(
        child: SizedBox.square(
          dimension: 300,
          child: CelebrationParticles(
            preset: CelebrationPreset.explosion,
            progress: AlwaysStoppedAnimation(0.05),
            duration: Duration(seconds: 4),
            seed: 3,
          ),
        ),
      ),
    );

    expect(
      find.byType(CustomPaint).last,
      paints
        ..something((method, _) => method == #drawRawAtlas)
        ..circle()
        ..path(),
    );
  });

  testWidgets('sparks that fail to load are tried again next time', (
    tester,
  ) async {
    CelebrationSprites.reset();
    await tester.runAsync(() => CelebrationSprites.load(_FlakyBundle(1)));
    expect(CelebrationSprites.images, isNull);

    await tester.runAsync(() => CelebrationSprites.load(_FlakyBundle(0)));
    expect(CelebrationSprites.images, hasLength(4));
    for (final image in CelebrationSprites.images!.values) {
      expect(image.width, CelebrationSprites.decodeWidth);
    }
  });

  test('the sparks are the four of assets/celebrations', () {
    expect(CelebrationSprite.values.map((s) => s.asset), [
      'assets/celebrations/spark_lime.png',
      'assets/celebrations/spark_mint.png',
      'assets/celebrations/spark_white.png',
      'assets/celebrations/spark_dot.png',
    ]);
  });
}

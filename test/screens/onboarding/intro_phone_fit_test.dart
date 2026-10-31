import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/onboarding/onboarding_intro.dart';

/// How the phone's Intro gives up its decoration on a short window, so the
/// language pill always keeps its room: tighter gaps first, then a smaller
/// tile, then no version line, and only then a scrolling description.
void main() {
  const scaler = TextScaler.noScaling;
  const name = 54.8;
  const description = 70.0;

  double needed(IntroPhoneFit fit) => fit.needed(
    nameHeight: name,
    descriptionRoom: description,
    textScaler: scaler,
  );

  IntroPhoneFit fitFor(double room) => IntroPhoneFit.of(
    room: room,
    nameHeight: name,
    descriptionRoom: description,
    textScaler: scaler,
  );

  test('a roomy window keeps the design', () {
    expect(fitFor(needed(IntroPhoneFit.roomy)), IntroPhoneFit.roomy);
    expect(fitFor(1000), IntroPhoneFit.roomy);
  });

  test('a little short: the gaps tighten, the tile keeps its size', () {
    final fit = fitFor(needed(IntroPhoneFit.roomy) - 1);
    expect(fit, IntroPhoneFit.tight);
    expect(fit.tileScale, 1);
    expect(fit.showVersion, isTrue);
  });

  test('shorter: the tile shrinks only as far as needed', () {
    final room = needed(IntroPhoneFit.tight) - 10;
    final fit = fitFor(room);
    expect(fit.tileScale, closeTo(1 - 10 / IntroPhoneFit.tileSize, 1e-9));
    expect(fit.showVersion, isTrue);
    expect(needed(fit), closeTo(room, 1e-9));
  });

  test('shorter still: the version line goes, the tile grows back', () {
    final smallest =
        needed(IntroPhoneFit.tight) -
        IntroPhoneFit.tileSize * (1 - IntroPhoneFit.minTileScale);
    final fit = fitFor(smallest - 1);
    expect(fit.showVersion, isFalse);
    expect(fit.tileScale, greaterThan(IntroPhoneFit.minTileScale));
    expect(needed(fit), lessThanOrEqualTo(smallest - 1));
  });

  test('when nothing fits, the tightest: the description scrolls', () {
    final fit = fitFor(50);
    expect(fit.tileScale, IntroPhoneFit.minTileScale);
    expect(fit.showVersion, isFalse);
    expect(fit.tileGap, IntroPhoneFit.tight.tileGap);
    expect(fit.pillGap, IntroPhoneFit.tight.pillGap);
  });
}

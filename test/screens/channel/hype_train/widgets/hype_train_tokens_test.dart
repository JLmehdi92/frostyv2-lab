import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_tokens.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('each green step keeps the luminance of its purple step', () {
    const pairs = [
      (Color(0xFF5C16C5), HtGreen.g7),
      (Color(0xFF772CE8), HtGreen.g8),
      (Color(0xFF9147FF), HtGreen.g9),
      (Color(0xFFA970FF), HtGreen.g10),
      (Color(0xFFBF94FF), HtGreen.g11),
    ];
    for (final (purple, green) in pairs) {
      expect(
        green.computeLuminance(),
        closeTo(purple.computeLuminance(), 0.03),
        reason: '$green for $purple',
      );
    }
  });

  test('g10 is the fork green', () {
    expect(HtGreen.g10, const Color(0xFF12A87A));
  });

  test('base text reads at 4.5:1 on the fill in light and dark', () {
    expect(
      _contrast(HtNeutrals.light.textBase, HtGreen.g10),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(HtNeutrals.dark.textBase, HtGreen.g8),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('the neutrals follow the brightness', () {
    expect(HtNeutrals.of(Brightness.light), same(HtNeutrals.light));
    expect(HtNeutrals.of(Brightness.dark), same(HtNeutrals.dark));
    expect(HtNeutrals.dark.backgroundFloat, const Color(0xFF1F1F23));
    expect(HtNeutrals.light.backgroundFloat, const Color(0xFFFFFFFF));
  });

  test("Twitch's purples count as purple; other colours do not", () {
    for (final purple in [0xFF9146FF, 0xFF9147FF, 0xFF772CE8, 0xFFA970FF]) {
      expect(isTwitchPurple(purple), isTrue, reason: purple.toRadixString(16));
    }
    for (final other in [0xFFBD0078, 0xFF12A87A, 0xFFFFB31A]) {
      expect(isTwitchPurple(other), isFalse, reason: other.toRadixString(16));
    }
  });

  test('the banner is 74 dp, growing with text up to twice that', () {
    expect(htBannerHeight(TextScaler.noScaling), 74);
    expect(htBannerHeight(const TextScaler.linear(0.8)), 74);
    expect(htBannerHeight(const TextScaler.linear(1.3)), closeTo(96.2, 0.01));
    expect(htBannerHeight(const TextScaler.linear(2)), 148);
    expect(htBannerHeight(const TextScaler.linear(3)), 148);
  });

  test('text styles use Inter at the Twitch sizes', () {
    expect(HtType.titleDefault.fontSize, 18);
    expect(HtType.titleDefault.fontWeight, FontWeight.w700);
    expect(HtType.titleLarge.fontSize, 24);
    expect(HtType.bodySmall.fontWeight, FontWeight.w400);
    expect(HtType.titleExtraSmall.fontWeight, FontWeight.w600);
    expect(HtType.footnote.fontSize, 12);
    expect(HtType.bodySmall.fontFamily, 'Inter');
  });
}

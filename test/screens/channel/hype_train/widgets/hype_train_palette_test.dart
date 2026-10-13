import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_palette.dart';

void main() {
  final light = ColorScheme.fromSeed(seedColor: const Color(0xff9146ff));
  final dark = ColorScheme.fromSeed(
    seedColor: const Color(0xff9146ff),
    brightness: Brightness.dark,
  );

  test('every style has its own icon and name', () {
    final palettes = [for (final s in HtStyle.values) HtPalette.of(s, light)];

    expect(
      palettes.map((p) => p.icon).toSet(),
      hasLength(HtStyle.values.length),
    );
    expect(
      palettes.map((p) => p.a11yName).toSet(),
      hasLength(HtStyle.values.length),
    );
  });

  test('the creator colour only tints the regular fill', () {
    const creator = 0xFFBD0078;

    expect(
      HtPalette.of(HtStyle.regular, light, creatorColor: creator).fill,
      const Color(creator),
    );
    expect(
      HtPalette.of(HtStyle.goldenKappa, light, creatorColor: creator).fill,
      isNot(const Color(creator)),
    );
  });

  test('text reads at 4.5:1 or better in light and dark', () {
    for (final scheme in [light, dark]) {
      for (final style in HtStyle.values) {
        final palette = HtPalette.of(style, scheme);

        expect(
          HtPalette.contrast(palette.onBackground, palette.background),
          greaterThanOrEqualTo(4.5),
          reason: '$style ${scheme.brightness}',
        );
      }
    }
  });
}

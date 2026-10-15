import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_palette.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_tokens.dart';

void main() {
  // The app's scheme is seeded from anything; only its brightness counts.
  final light = ColorScheme.fromSeed(seedColor: const Color(0xff9146ff));
  final dark = ColorScheme.fromSeed(
    seedColor: const Color(0xff9146ff),
    brightness: Brightness.dark,
  );

  /// Every palette: each style in both themes, the treasure both ways.
  List<(String, HtPalette)> all() => [
    for (final scheme in [light, dark]) ...[
      for (final style in HtStyle.values)
        ('$style ${scheme.brightness}', HtPalette.of(style, scheme)),
      (
        'unlocked treasure ${scheme.brightness}',
        HtPalette.of(HtStyle.treasure, scheme, treasureUnlocked: true),
      ),
    ],
  ];

  /// What the text sits on: the track, or the gradient covering it all.
  List<Color> backgrounds(HtPalette p) =>
      p.fillCoversAll ? p.fillColors! : [p.track];

  /// What the filled part looks like, alpha composited on the track.
  List<Color> fills(HtPalette p) => [
    for (final c in p.fillColors ?? [p.fill]) Color.alphaBlend(c, p.track),
  ];

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

  test('the regular fill is green: #12A87A light, #0C6D4F dark', () {
    final l = HtPalette.of(HtStyle.regular, light);
    final d = HtPalette.of(HtStyle.regular, dark);

    expect(l.fill, const Color(0xFF12A87A));
    expect(d.fill, const Color(0xFF0C6D4F));
    expect(l.track, HtNeutrals.light.backgroundFloat);
    expect(d.track, HtNeutrals.dark.backgroundFloat);
    expect(l.text, HtNeutrals.light.textBase);
    expect(l.pill, const Color(0xCC000000));
    expect(l.pillText, Colors.white);
    expect(l.link, HtGreen.g7);
    expect(d.link, HtGreen.g11);
    expect(l.fillColors, isNull);
  });

  test('golden, community and Mythic keep their own hues', () {
    final golden = HtPalette.of(HtStyle.goldenKappa, light);
    expect(golden.track, const Color(0xFFFFB31A));
    expect(golden.fill, const Color(0xFFFFDF9E));
    expect(golden.text, Colors.black);
    expect(golden.pill, const Color(0x99000000));

    final community = HtPalette.of(HtStyle.community, dark);
    expect(community.track, const Color(0xFF071A40));
    expect(community.fill, const Color(0xFF1756D3));
    expect(community.text, Colors.white);

    final mythic = HtPalette.of(HtStyle.mythic, light);
    expect(mythic.track, const Color(0xFF403520));
    expect(mythic.fillColors, const [
      Color(0x80976700),
      Color(0x80FFF9EB),
      Color(0x80FFD760),
    ]);
    expect(mythic.text, Colors.white);
    expect(mythic.textShadow, isNotNull);
  });

  test('the record fills green to azure, with the trophy', () {
    final l = HtPalette.of(HtStyle.athReached, light);
    final d = HtPalette.of(HtStyle.athReached, dark);

    expect(l.fillColors, const [Color(0xFF12A87A), Color(0xFF069DE9)]);
    expect(d.fillColors, const [Color(0xFF0E8661), Color(0xFF057DB8)]);
    expect(l.track, HtNeutrals.light.backgroundBase);
    expect(d.track, HtNeutrals.dark.backgroundBase);
    expect(l.trophy, isTrue);
    expect(HtPalette.of(HtStyle.athApproaching, light).fillColors, [
      ...l.fillColors!,
    ]);
    expect(HtPalette.of(HtStyle.regular, light).trophy, isFalse);
  });

  test('an unlocked treasure covers the banner blue to green', () {
    final locked = HtPalette.of(HtStyle.treasure, light);
    final unlocked = HtPalette.of(
      HtStyle.treasure,
      light,
      treasureUnlocked: true,
    );

    expect(locked.fillCoversAll, isFalse);
    expect(locked.fill, HtGreen.g10);
    expect(unlocked.fillCoversAll, isTrue);
    expect(unlocked.fillColors, const [Color(0xFF1345AA), Color(0xFF0E8661)]);
    expect(unlocked.text, Colors.white);
  });

  test('a Twitch-purple creator colour falls back to green', () {
    expect(
      HtPalette.of(HtStyle.regular, light, creatorColor: 0xFF9147FF).fill,
      HtGreen.g10,
    );
    expect(
      HtPalette.of(HtStyle.regular, dark, creatorColor: 0xFF9146FF).fill,
      HtGreen.g8,
    );
    for (final legacy in [0xFF6441A5, 0xFF451093]) {
      expect(
        HtPalette.of(HtStyle.regular, light, creatorColor: legacy).fill,
        HtGreen.g10,
        reason: legacy.toRadixString(16),
      );
    }
    expect(
      HtPalette.of(HtStyle.regular, light, creatorColor: 0xFFBD0078).fill,
      const Color(0xFFBD0078),
    );
  });

  test('another creator colour tints the regular fill only', () {
    const creator = 0xFFBD0078;

    expect(
      HtPalette.of(HtStyle.regular, light, creatorColor: creator).fill,
      const Color(creator),
    );
    expect(
      HtPalette.of(HtStyle.regular, light, creatorColor: creator).checkPill,
      const Color(creator),
    );
    for (final style in HtStyle.values) {
      if (style == HtStyle.regular) continue;
      expect(
        HtPalette.of(style, light, creatorColor: creator).fill,
        isNot(const Color(creator)),
        reason: '$style',
      );
    }
  });

  test('no Twitch purple anywhere, in light or dark', () {
    for (final (name, p) in all()) {
      final colours = [
        p.track,
        p.fill,
        ...?p.fillColors,
        p.text,
        p.pill,
        p.pillText,
        p.checkPill,
        p.barTrack,
        p.link,
        ?p.textShadow?.color,
      ];
      for (final colour in colours) {
        final hsl = HSLColor.fromColor(Color.alphaBlend(colour, p.track));
        expect(
          hsl.hue >= 255 && hsl.hue <= 290 && hsl.saturation > 0.4,
          isFalse,
          reason: '$name: $colour',
        );
      }
    }
  });

  test('text reads at 4.5:1 on the track', () {
    for (final (name, p) in all()) {
      for (final background in backgrounds(p)) {
        expect(
          HtPalette.contrast(p.text, background),
          greaterThanOrEqualTo(4.5),
          reason: '$name on $background',
        );
      }
    }
  });

  test('text reads at 3:1 on the fill; Mythic has a shadow instead', () {
    for (final (name, p) in all()) {
      if (p.fillCoversAll) continue;
      if (name.startsWith('${HtStyle.mythic}')) {
        expect(p.textShadow, isNotNull, reason: name);
        continue;
      }
      for (final fill in fills(p)) {
        expect(
          HtPalette.contrast(p.text, fill),
          greaterThanOrEqualTo(3),
          reason: '$name on $fill',
        );
      }
    }
  });

  test('the level pill text reads on the pill', () {
    for (final (name, p) in all()) {
      expect(
        HtPalette.contrast(p.pillText, Color.alphaBlend(p.pill, p.track)),
        greaterThanOrEqualTo(4.5),
        reason: name,
      );
    }
  });
}

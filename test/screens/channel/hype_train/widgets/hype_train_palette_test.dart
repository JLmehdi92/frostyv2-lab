import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_palette.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_tokens.dart';

void main() {
  // The app's scheme is seeded from anything; only its brightness counts.
  final light = ColorScheme.fromSeed(seedColor: const Color(0xff9146ff));
  final dark = ColorScheme.fromSeed(
    seedColor: const Color(0xff9146ff),
    brightness: Brightness.dark,
  );

  /// Every palette: each style in both themes, the regular and shared
  /// trains at every level, the treasure both ways, before a train.
  List<(String, HtPalette)> all() => [
    for (final scheme in [light, dark]) ...[
      for (final style in HtStyle.values)
        for (var level = 1; level <= 7; level++)
          (
            '$style L$level ${scheme.brightness}',
            HtPalette.of(style, scheme, level: level),
          ),
      ('approaching ${scheme.brightness}', HtPalette.approaching(scheme)),
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

  group('ONSET level colours', () {
    const fills = {
      1: Color(0xFF12A87A),
      2: Color(0xFF14B8A6),
      3: Color(0xFF3DDBA6),
      4: Color(0xFFC8FF3D),
      5: Color(0xFFFF7A45),
      6: Color(0xFFC8FF3D),
      9: Color(0xFFC8FF3D),
    };

    test('the regular train climbs from green to lime and orange', () {
      for (final MapEntry(key: level, value: fill) in fills.entries) {
        for (final scheme in [light, dark]) {
          final p = HtPalette.of(HtStyle.regular, scheme, level: level);
          expect(p.fill, fill, reason: 'L$level');
          expect(p.pillText, fill, reason: 'L$level pill');
          expect(p.text, const Color(0xFFF5F5F5));
          expect(p.textOnFill, const Color(0xFF0A0A0A));
          expect(p.pill, const Color(0xDB0A0A0A));
          expect(p.radius, 12);
          expect(p.hairline, isNotNull);
        }
      }
      expect(
        HtPalette.of(HtStyle.regular, dark).track,
        const Color(0xFF142C24),
      );
      expect(
        HtPalette.of(HtStyle.regular, dark, level: 4).track,
        const Color(0xFF313A1B),
      );
      expect(
        HtPalette.of(HtStyle.regular, dark, level: 5).track,
        const Color(0xFF3A241C),
      );
    });

    test('level 3 is a mint to cyan gradient; 6 and up flow lime-orange', () {
      expect(HtPalette.of(HtStyle.regular, dark, level: 3).fillColors, const [
        Color(0xFF3DDBA6),
        Color(0xFF7CF0FF),
        Color(0xFF3DDBA6),
      ]);
      expect(HtPalette.of(HtStyle.regular, dark, level: 3).fillSheen, isFalse);
      for (final level in [6, 7, 12]) {
        final p = HtPalette.of(HtStyle.regular, dark, level: level);
        expect(p.fillColors, const [
          Color(0xFFC8FF3D),
          Color(0xFFFF7A45),
          Color(0xFFC8FF3D),
        ]);
        expect(p.fillSheen, isTrue);
      }
      for (final level in [1, 2, 4, 5]) {
        expect(
          HtPalette.of(HtStyle.regular, dark, level: level).fillColors,
          isNull,
        );
      }
    });

    test('a shared train takes the level colour and keeps its speedlines', () {
      final shared = HtPalette.of(HtStyle.shared, dark, level: 5);
      expect(shared.fill, const Color(0xFFFF7A45));
      expect(shared.speedlines, isTrue);
      expect(shared.pillFillColors, const [
        Color(0xFFFF7A45),
        Color(0xFFFF7A45),
      ]);
    });

    test('dark text reads on every fill, light text on every track', () {
      for (var level = 1; level <= 6; level++) {
        final p = HtPalette.of(HtStyle.regular, dark, level: level);
        for (final fill in p.fillColors ?? [p.fill]) {
          expect(
            HtPalette.contrast(p.textOnFill!, fill),
            greaterThanOrEqualTo(4.5),
            reason: 'L$level on $fill',
          );
          // White on the fill is what the board refuses.
          expect(HtPalette.contrast(Colors.white, fill), lessThan(4.5));
        }
        expect(
          HtPalette.contrast(p.text, p.track),
          greaterThanOrEqualTo(4.5),
          reason: 'L$level track',
        );
      }
    });

    test('the sheet icon stays visible on the light theme', () {
      for (var level = 1; level <= 6; level++) {
        final p = HtPalette.of(HtStyle.regular, light, level: level);
        expect(
          HtPalette.contrast(p.checkPill, HtNeutrals.light.backgroundAlt),
          greaterThanOrEqualTo(4.5),
          reason: 'L$level',
        );
      }
    });

    test('before a train: the float card, green', () {
      final l = HtPalette.approaching(light);
      final d = HtPalette.approaching(dark);
      expect(l.fill, const Color(0xFF12A87A));
      expect(d.fill, const Color(0xFF0C6D4F));
      expect(l.track, HtNeutrals.light.backgroundFloat);
      expect(l.text, HtNeutrals.light.textBase);
      expect(l.link, HtGreen.ink);
      expect(d.link, HtGreen.light);
      expect(l.textOnFill, isNull);
    });
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
    expect(locked.fill, HtGreen.base);
    expect(unlocked.fillCoversAll, isTrue);
    expect(unlocked.fillColors, const [Color(0xFF1345AA), Color(0xFF0E8661)]);
    expect(unlocked.text, Colors.white);
  });

  test('the special trains keep their own pill and text', () {
    for (final style in [
      HtStyle.treasure,
      HtStyle.community,
      HtStyle.mythic,
      HtStyle.goldenKappa,
      HtStyle.athReached,
      HtStyle.athApproaching,
    ]) {
      final p = HtPalette.of(style, dark, level: 4);
      expect(p.textOnFill, isNull, reason: '$style');
      expect(p.fill, isNot(const Color(0xFFC8FF3D)), reason: '$style');
      expect(p.radius, HtDims.radius, reason: '$style');
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
        ...?p.pillFillColors,
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
      // The level colours turn their text dark over the fill (tested above).
      if (p.textOnFill != null) continue;
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

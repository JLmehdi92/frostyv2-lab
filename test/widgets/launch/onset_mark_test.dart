import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/widgets/launch/onset_mark.dart';

/// The tile sizes the app draws the mark at, and the asset family each one
/// must load: the smallest at least as large as the tile.
final _families = {28.0: 30, 30.0: 30, 52.0: 52, 72.0: 72};

/// Flutter's resolution variants beside each family's 1.0x file.
final _ratios = {
  1.0: '',
  1.5: '1.5x/',
  2.0: '2.0x/',
  3.0: '3.0x/',
  4.0: '4.0x/',
};

/// The Android density buckets of the splash tile, and their ratio.
final _densities = {
  1.0: 'mdpi',
  1.5: 'hdpi',
  2.0: 'xhdpi',
  3.0: 'xxhdpi',
  4.0: 'xxxhdpi',
};

const _res = 'android/app/src/main/res';

String _flutterAsset(int family, double ratio) =>
    'assets/icons/${_ratios[ratio]}onset_logo_$family.png';

String _splashTile(double ratio) =>
    '$_res/drawable-${_densities[ratio]}/launch_tile.png';

/// A PNG's width, height and colour type, from its IHDR chunk.
(int, int, int) _header(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  // The signature (8 bytes), the chunk length and type (8), then IHDR.
  expect(String.fromCharCodes(bytes.sublist(12, 16)), 'IHDR', reason: path);
  return (data.getUint32(16), data.getUint32(20), bytes[25]);
}

class _Pixels {
  final int width;
  final int height;
  final ByteData rgba;

  _Pixels(this.width, this.height, this.rgba);

  int at(int x, int y, int channel) =>
      rgba.getUint8((y * width + x) * 4 + channel);
}

/// The decoded, unpremultiplied pixels of the PNG at [path].
Future<_Pixels> _decode(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  final image = (await codec.getNextFrame()).image;
  final rgba = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  final pixels = _Pixels(image.width, image.height, rgba!);
  image.dispose();
  codec.dispose();
  return pixels;
}

class _Metrics with WidgetsBindingObserver {
  int changes = 0;

  @override
  void didChangeMetrics() => changes++;
}

class _FailingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw FlutterError('no asset $key');
}

class _SilentBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => Completer<ByteData>().future;
}

Widget _tile(Widget tile) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: tile),
);

Finder _inTile(Type type) => find.descendant(
  of: find.byType(OnsetMarkTile),
  matching: find.byType(type),
);

void main() {
  group('the mark image', () {
    test('every family has its five variants at their pixel size', () {
      for (final family in _families.values.toSet()) {
        for (final ratio in _ratios.keys) {
          final path = _flutterAsset(family, ratio);
          expect(File(path).existsSync(), isTrue, reason: path);
          final (width, height, colorType) = _header(path);
          final side = (family * ratio).round();
          expect((width, height), (side, side), reason: path);
          // Opaque RGB: the tile's corners are clipped in Flutter.
          expect(colorType, 2, reason: path);
        }
      }
    });

    test('is bundled: pubspec lists each family', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final family in _families.values.toSet()) {
        expect(pubspec, contains('- assets/icons/onset_logo_$family.png'));
      }
    });

    test('the tile ground is the icon\'s own edge', () async {
      final pixels = await _decode(_flutterAsset(72, 4.0));
      final last = pixels.width - 1;
      for (final (x, y) in [
        (0, 0),
        (last, 0),
        (0, last),
        (last, last),
        (last ~/ 2, 0),
        (0, last ~/ 2),
      ]) {
        final ground = [
          (OnsetMark.ground.r * 255).round(),
          (OnsetMark.ground.g * 255).round(),
          (OnsetMark.ground.b * 255).round(),
        ];
        for (var c = 0; c < 3; c++) {
          expect(
            pixels.at(x, y, c),
            closeTo(ground[c], 4),
            reason: 'channel $c at ($x, $y)',
          );
        }
      }
    });
  });

  group('the Android splash', () {
    test('the drawn vector is gone: the tile is the bitmap', () {
      expect(File('$_res/drawable/launch_tile.xml').existsSync(), isFalse);
    });

    test('draws the very pixels of the Flutter 72 dp tile, at each density, '
        'with its 20 dp corners cut out', () async {
      for (final ratio in _densities.keys) {
        final path = _splashTile(ratio);
        expect(File(path).existsSync(), isTrue, reason: path);
        final (width, height, colorType) = _header(path);
        final side = (OnsetMark.designSize * ratio).round();
        expect((width, height), (side, side), reason: path);
        expect(colorType, 6, reason: '$path: RGBA');

        final splash = await _decode(path);
        final flutter = await _decode(_flutterAsset(72, ratio));
        var opaque = 0;
        for (var y = 0; y < side; y++) {
          for (var x = 0; x < side; x++) {
            if (splash.at(x, y, 3) != 255) continue;
            opaque++;
            for (var c = 0; c < 3; c++) {
              if (splash.at(x, y, c) != flutter.at(x, y, c)) {
                fail('$path differs from the Flutter tile at ($x, $y)');
              }
            }
          }
        }
        // All but the four corners: (4 - pi) r² of the tile, 6.6 %, and
        // the arcs' antialiased pixels.
        expect(opaque / (side * side), greaterThan(0.9), reason: path);

        // The corners: transparent at the very corner, opaque along the
        // edges, and the arc of a 20 dp radius on the diagonal.
        final radius = OnsetMark.designRadius * ratio;
        expect(splash.at(0, 0, 3), 0, reason: path);
        expect(splash.at(side - 1, side - 1, 3), 0, reason: path);
        expect(splash.at(0, side ~/ 2, 3), 255, reason: path);
        expect(splash.at(side ~/ 2, 0, 3), 255, reason: path);
        // Along the top row, the arc leaves the edge where the circle of
        // that radius crosses the row's middle.
        final firstOpaque = List.generate(
          side,
          (x) => x,
        ).firstWhere((x) => splash.at(x, 0, 3) >= 128);
        final arc =
            radius - math.sqrt(radius * radius - math.pow(radius - 0.5, 2));
        expect(firstOpaque, closeTo(arc, 1), reason: path);
      }
    });

    test('centres the 72 dp tile in its splash icon, before and from '
        'Android 12', () {
      final background = File(
        '$_res/drawable/launch_background.xml',
      ).readAsStringSync();
      expect(background, contains('android:drawable="@drawable/launch_tile"'));
      expect(background, contains('android:gravity="center"'));

      // Android 12+: a 288 dp icon, masked to a 192 dp circle; the 72 dp
      // tile in its middle stays well inside the mask.
      final icon = File('$_res/drawable/splash_icon.xml').readAsStringSync();
      expect(icon, contains('android:drawable="@drawable/launch_tile"'));
      expect(icon, contains('android:inset="108dp"'));
      expect(OnsetMark.designSize + 2 * 108, 288);
      expect(OnsetMark.designSize * math.sqrt2 / 2, lessThan(192 / 2));
      for (final styles in ['values-v31', 'values-night-v31']) {
        expect(
          File('$_res/$styles/styles.xml').readAsStringSync(),
          contains(
            '<item name="android:windowSplashScreenAnimatedIcon">'
            '@drawable/splash_icon</item>',
          ),
        );
      }
      // The activity tells Flutter the tile's size from that same ratio.
      expect(
        File(
          'android/app/src/main/kotlin/app/onset/MainActivity.kt',
        ).readAsStringSync(),
        contains('icon.width * 72f / 288f'),
      );
    });
  });

  group('the variant', () {
    test('never smaller than the screen needs: the smallest at or above the '
        'pixel ratio, as Android picks its density bucket', () {
      for (final (dpr, variant) in [
        (0.75, ''),
        (1.0, ''),
        (1.2, '1.5x/'),
        (1.5, '1.5x/'),
        (1.75, '2.0x/'),
        (2.0, '2.0x/'),
        (2.5, '3.0x/'),
        (2.625, '3.0x/'),
        (2.75, '3.0x/'),
        (3.0, '3.0x/'),
        (3.5, '4.0x/'),
        (4.0, '4.0x/'),
        (5.0, '4.0x/'),
      ]) {
        final image = OnsetMark.imageFor(30, devicePixelRatio: dpr);
        expect(
          image.assetName,
          'assets/icons/${variant}onset_logo_30.png',
          reason: 'at $dpr',
        );
        final scale = variant.isEmpty
            ? 1.0
            : double.parse(variant.substring(0, variant.length - 2));
        expect(image.scale, scale, reason: 'at $dpr');
      }
    });

    test('at each Android density, the 72 dp tile is the splash bitmap\'s '
        'twin', () {
      for (final ratio in _densities.keys) {
        expect(
          OnsetMark.imageFor(72, devicePixelRatio: ratio).assetName,
          _flutterAsset(72, ratio),
        );
      }
    });
  });

  group('precacheFor', () {
    setUp(() {
      imageCache
        ..clear()
        ..clearLiveImages();
    });

    AssetBundleImageKey key(String name, double scale) =>
        AssetBundleImageKey(bundle: rootBundle, name: name, scale: scale);

    testWidgets('a sized view: the intro\'s tile and the header\'s, at its '
        'pixel ratio', (tester) async {
      tester.view
        ..physicalSize = const Size(1170, 2532)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.runAsync(() => OnsetMark.precacheFor(tester.view));
      expect(
        imageCache.containsKey(key('assets/icons/3.0x/onset_logo_72.png', 3)),
        isTrue,
      );
      expect(
        imageCache.containsKey(key('assets/icons/3.0x/onset_logo_30.png', 3)),
        isTrue,
      );
    });

    testWidgets('before the first metrics: waits for them, then caches the '
        'variant of the real pixel ratio', (tester) async {
      // What the engine reports at the very start of main(): no size yet,
      // and the default ratio of 1.
      tester.view
        ..physicalSize = Size.zero
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        final done = OnsetMark.precacheFor(tester.view);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        // The ratio first (still no size: it keeps waiting), then the size.
        tester.view.devicePixelRatio = 3;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        tester.view.physicalSize = const Size(1170, 2532);
        await done;
      });
      expect(
        imageCache.containsKey(key('assets/icons/3.0x/onset_logo_72.png', 3)),
        isTrue,
      );
      expect(
        imageCache.containsKey(key('assets/icons/3.0x/onset_logo_30.png', 3)),
        isTrue,
      );
      expect(
        imageCache.containsKey(key('assets/icons/onset_logo_72.png', 1)),
        isFalse,
      );
    });

    testWidgets('metrics that never come: it gives up within its cap, and '
        'later metrics still reach the app', (tester) async {
      tester.view
        ..physicalSize = Size.zero
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final watch = Stopwatch()..start();
      await tester.runAsync(
        () => OnsetMark.precacheFor(
          tester.view,
          timeout: const Duration(milliseconds: 100),
        ),
      );
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      final observer = _Metrics();
      tester.binding.addObserver(observer);
      addTearDown(() => tester.binding.removeObserver(observer));
      tester.view.physicalSize = const Size(390, 844);
      expect(observer.changes, greaterThan(0));
      expect(tester.takeException(), isNull);
    });
  });

  group('OnsetMarkTile', () {
    for (final MapEntry(key: size, value: family) in _families.entries) {
      testWidgets('at ${size.toInt()} dp: the icon from the $family dp family '
          'on its ground', (tester) async {
        await tester.pumpWidget(_tile(OnsetMarkTile(size: size, radius: 8)));
        expect(tester.getSize(find.byType(OnsetMarkTile)), Size(size, size));

        final image = tester.widget<Image>(_inTile(Image));
        expect(
          (image.image as ExactAssetImage).assetName,
          // This test's pixel ratio is 3: the 3.0x variant.
          'assets/icons/3.0x/onset_logo_$family.png',
        );
        expect(image.filterQuality, FilterQuality.medium);
        expect(image.gaplessPlayback, isTrue);
        expect(image.excludeFromSemantics, isTrue);
        expect(image.fit, BoxFit.cover);
        expect(tester.getSize(_inTile(Image)), Size(size, size));

        final clip = tester.widget<ClipRRect>(_inTile(ClipRRect));
        expect(clip.borderRadius, BorderRadius.circular(8));
        final box = tester.widget<DecoratedBox>(_inTile(DecoratedBox));
        final decoration = box.decoration as BoxDecoration;
        expect(decoration.color, OnsetMark.ground);
        expect(decoration.borderRadius, BorderRadius.circular(8));
      });
    }

    testWidgets('scaled by a transform, it shows the image for the size it '
        'is drawn at', (tester) async {
      for (final (drawn, family) in [
        (72.0, 72),
        (60.0, 72),
        (52.0, 52),
        (40.0, 52),
        (30.000001, 30),
        (28.0, 30),
      ]) {
        await tester.pumpWidget(_tile(OnsetMarkTile(drawnSize: drawn)));
        final image = tester.widget<Image>(_inTile(Image));
        expect(
          (image.image as ExactAssetImage).assetName,
          // This test's pixel ratio is 3: the 3.0x variant.
          'assets/icons/3.0x/onset_logo_$family.png',
          reason: 'drawn at $drawn',
        );
        // Laid out at its own size all the same.
        expect(tester.getSize(find.byType(OnsetMarkTile)), const Size(72, 72));
      }
    });

    testWidgets('corners scale with the tile: 20 at 72', (tester) async {
      await tester.pumpWidget(_tile(const OnsetMarkTile(size: 28)));
      final clip = tester.widget<ClipRRect>(_inTile(ClipRRect));
      expect(clip.borderRadius, BorderRadius.circular(20 * 28 / 72));
    });

    testWidgets(
      'the launch intro fades and grows the icon in over the ground',
      (tester) async {
        await tester.pumpWidget(
          _tile(const OnsetMarkTile(markOpacity: 0, markScale: 0.6)),
        );
        // A plain tile of the icon's ground (the intro's dot growing).
        expect(_inTile(Image), findsNothing);
        expect(
          (tester.widget<DecoratedBox>(_inTile(DecoratedBox)).decoration
                  as BoxDecoration)
              .color,
          OnsetMark.ground,
        );

        await tester.pumpWidget(
          _tile(const OnsetMarkTile(markOpacity: 0.5, markScale: 0.8)),
        );
        final image = tester.widget<Image>(_inTile(Image));
        expect(image.opacity!.value, 0.5);
        final scale = tester.widget<Transform>(
          find.ancestor(of: _inTile(Image), matching: find.byType(Transform)),
        );
        expect(scale.transform.entry(0, 0), closeTo(0.8, 1e-6));
        expect(scale.transform.entry(1, 1), closeTo(0.8, 1e-6));

        await tester.pumpWidget(_tile(const OnsetMarkTile()));
        expect(tester.widget<Image>(_inTile(Image)).opacity, isNull);
      },
    );

    testWidgets('one image node for screen readers: "ONSET"', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_tile(const OnsetMarkTile()));
      expect(find.bySemanticsLabel('ONSET'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(OnsetMarkTile)),
        matchesSemantics(label: 'ONSET', isImage: true),
      );
      semantics.dispose();
    });

    testWidgets('precache: decoded before the first frame that shows it', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final key = AssetBundleImageKey(
        bundle: rootBundle,
        name: 'assets/icons/3.0x/onset_logo_72.png',
        scale: 3,
      );
      imageCache
        ..clear()
        ..clearLiveImages();
      expect(imageCache.containsKey(key), isFalse);
      await tester.runAsync(() => OnsetMark.precache(devicePixelRatio: 3));
      expect(imageCache.containsKey(key), isTrue);

      // The widget then resolves that very entry.
      await tester.pumpWidget(_tile(const OnsetMarkTile()));
      final image = tester.widget<Image>(_inTile(Image));
      final resolved = await tester.runAsync(
        () => (image.image as ExactAssetImage).obtainKey(
          ImageConfiguration(bundle: rootBundle, devicePixelRatio: 3),
        ),
      );
      expect(resolved, key);
    });

    testWidgets('precache never throws nor holds the launch', (tester) async {
      // An asset that cannot load: it completes, quietly.
      await tester.runAsync(
        () => OnsetMark.precache(devicePixelRatio: 1, bundle: _FailingBundle()),
      );
      // An asset that never answers: it gives up after its timeout.
      final watch = Stopwatch()..start();
      await tester.runAsync(
        () => OnsetMark.precache(
          devicePixelRatio: 1,
          bundle: _SilentBundle(),
          timeout: const Duration(milliseconds: 50),
        ),
      );
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });
  });
}

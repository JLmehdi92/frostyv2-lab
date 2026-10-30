import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/celebration.dart';
import 'package:onset/screens/channel/celebrations/particles/celebration_sprites.dart';
import 'package:onset/screens/channel/celebrations/particles/celebration_view.dart';

/// Renders every preset, with the real sparks and the real font, at three
/// instants, and checks each instant draws something.
///
/// Set `CELEBRATION_PREVIEW_DIR` to also write one PNG per preset there (the
/// three instants side by side) to look at them; nothing is written
/// otherwise.
void main() {
  const background = Color(0xFF0A0A0A);
  const side = 300.0;
  const instants = [0.15, 0.45, 0.75];

  setUpAll(() async {
    final inter = FontLoader('Inter');
    inter.addFont(rootBundle.load('assets/fonts/Inter-ExtraBold.ttf'));
    await inter.load();
  });

  testWidgets('every preset draws something with the real sparks', (
    tester,
  ) async {
    CelebrationSprites.reset();
    await tester.runAsync(CelebrationSprites.load);
    expect(CelebrationSprites.images, hasLength(4));

    tester.view
      ..physicalSize = const Size(side * 3 + 16, side)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final out = Platform.environment['CELEBRATION_PREVIEW_DIR'];
    if (out != null) Directory(out).createSync(recursive: true);

    for (final preset in CelebrationPreset.values) {
      final boundary = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: boundary,
            child: ColoredBox(
              color: background,
              child: Row(
                children: [
                  for (final (i, t) in instants.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    SizedBox.square(
                      dimension: side,
                      child: CelebrationParticles(
                        preset: preset,
                        progress: AlwaysStoppedAnimation(t),
                        duration: const Duration(seconds: 4),
                        seed: 42,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final (rgba, png) = (await tester.runAsync(() async {
        final image = await render.toImage();
        final rgba = await image.toByteData();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return (rgba!, png!);
      }))!;

      // Each instant has pixels other than the background.
      final width = (side * 3 + 16).toInt();
      for (final (i, _) in instants.indexed) {
        final x0 = (i * (side + 8)).toInt();
        var lit = 0;
        for (var y = 0; y < side; y += 2) {
          for (var x = x0; x < x0 + side; x += 2) {
            final o = (y * width + x) * 4;
            final r = rgba.getUint8(o);
            final g = rgba.getUint8(o + 1);
            final b = rgba.getUint8(o + 2);
            if (r + g + b > 3 * 0x0A + 24) lit++;
          }
        }
        expect(
          lit,
          greaterThan(20),
          reason: '${preset.name} at ${instants[i]}',
        );
      }

      if (out != null) {
        File(
          '$out/${preset.name}.png',
        ).writeAsBytesSync(png.buffer.asUint8List());
      }
    }
  });
}

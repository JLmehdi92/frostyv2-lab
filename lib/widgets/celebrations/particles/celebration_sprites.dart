import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:onset/widgets/celebrations/particles/celebration_particles.dart';

/// The spark images, decoded once for the whole app.
///
/// The files are 128 px; a spark is never drawn much bigger than 30 dp, so
/// they are decoded at [decodeWidth] px — about 64 KB for all four, kept for
/// the app's lifetime rather than decoded again for every celebration.
abstract final class CelebrationSprites {
  static const decodeWidth = 64;

  static Map<CelebrationSprite, ui.Image>? _images;
  static Future<void>? _loading;

  /// The decoded sparks, or null until they are (the particles are drawn as
  /// plain vector sparks meanwhile, or if the files cannot be read).
  static Map<CelebrationSprite, ui.Image>? get images => _images;

  static ui.Image? _glow;

  /// A soft white disc fading to nothing at its edge, tinted per particle for
  /// glows and embers: one image drawn in a batch instead of a gradient
  /// shader built for every particle on every frame.
  static ui.Image get glow => _glow ??= _paintGlow();

  static ui.Image _paintGlow() {
    const size = decodeWidth;
    const center = Offset(size / 2, size / 2);
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawCircle(
      center,
      size / 2,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          size / 2,
          const [Color(0xFFFFFFFF), Color(0x66FFFFFF), Color(0x00FFFFFF)],
          const [0, 0.35, 1],
        ),
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(size, size);
    picture.dispose();
    return image;
  }

  /// Starts decoding the sparks, once. Never throws.
  static Future<void> load([AssetBundle? bundle]) =>
      _loading ??= _decode(bundle ?? rootBundle).then((decoded) {
        // Failed: the next celebration tries again.
        if (!decoded) _loading = null;
      });

  /// Whether every spark was decoded.
  static Future<bool> _decode(AssetBundle bundle) async {
    final images = <CelebrationSprite, ui.Image>{};
    try {
      for (final sprite in CelebrationSprite.values) {
        final data = await bundle.load(sprite.asset);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          targetWidth: decodeWidth,
        );
        try {
          images[sprite] = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      }
      _images = images;
      return true;
    } catch (error) {
      // A missing or corrupt spark must not take the channel down: the
      // vector sparks stand in meanwhile.
      debugPrint('Celebration sparks unavailable: $error');
      for (final image in images.values) {
        image.dispose();
      }
      return false;
    }
  }

  /// Forgets the decoded sparks (tests only).
  @visibleForTesting
  static void reset() {
    for (final image in _images?.values ?? const <ui.Image>[]) {
      image.dispose();
    }
    _images = null;
    _loading = null;
    _glow?.dispose();
    _glow = null;
  }
}

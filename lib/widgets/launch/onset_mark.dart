import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:onset/theme.dart';

/// The ONSET mark: the app icon (`assets/icons/icon_onset.png`, "ON" with
/// its rays and dot on the lime halftone) in a rounded tile, as the launch
/// intro, the headers, the onboarding, the release notes and the update
/// prompt show it.
///
/// The icon is bundled downscaled, one family per tile size (30, 52 and
/// 72 dp, each with its 1.5x–4.0x variants), written by
/// `tool/onset_logo_assets.py`. The Android splash draws the 72 dp family's
/// very pixels with the same 20 dp corners
/// (`res/drawable-*dpi/launch_tile.png`, checked by a test), so the native
/// splash hands over to the Flutter intro without a visible change.
abstract final class OnsetMark {
  /// Side of the launch boards' tile, the size the intro draws it at.
  static const designSize = 72.0;

  /// Corner radius of the tile at [designSize].
  static const designRadius = 20.0;

  /// The icon's own ground (the mean of its outer band, printed by the
  /// tool): the tile's fill behind the image, so the intro's dot grows in
  /// the icon's lime and the icon comes in over it without an edge.
  static const ground = Color(0xFFD6F427);

  /// The bundled families, by the tile side they are sized for.
  static const _families = [30, 52, 72];

  /// The icon for a [size] dp tile: the smallest family at least that
  /// large (the largest beyond it). Flutter picks the variant for the
  /// device's pixel ratio.
  static AssetImage imageFor(double size) {
    // A scaled size is rarely exact: 30.000001 is still the 30 dp tile.
    final family = _families.firstWhere(
      (side) => side >= size - 0.01,
      orElse: () => _families.last,
    );
    return AssetImage('assets/icons/onset_logo_$family.png');
  }

  /// Decodes the icon for a [size] dp tile at [devicePixelRatio] into the
  /// image cache, so the first frame that shows it already has it: the
  /// launch intro's first frame replaces the Android splash's tile.
  ///
  /// Never throws, and gives up after [timeout]: it must never hold the
  /// launch. [bundle] is for tests.
  static Future<void> precache({
    required double devicePixelRatio,
    double size = designSize,
    AssetBundle? bundle,
    Duration timeout = const Duration(milliseconds: 300),
  }) {
    final done = Completer<void>();
    ImageStream? stream;
    late final ImageStreamListener listener;
    void finish() {
      if (done.isCompleted) return;
      stream?.removeListener(listener);
      done.complete();
    }

    listener = ImageStreamListener(
      (_, _) => finish(),
      onError: (error, _) {
        debugPrint('ONSET mark not precached: ${error.runtimeType}');
        finish();
      },
    );
    try {
      stream = imageFor(size).resolve(
        ImageConfiguration(
          bundle: bundle ?? rootBundle,
          devicePixelRatio: devicePixelRatio,
        ),
      );
      // Called at once when already cached: [stream] is set by then.
      stream.addListener(listener);
    } catch (e) {
      debugPrint('ONSET mark not precached: ${e.runtimeType}');
      finish();
    }
    return done.future.timeout(timeout, onTimeout: finish);
  }
}

/// The mark at [size] (72 on the launch boards, 52 in the release notes and
/// the update prompt, 28 in the phone header, 30 in the tablet's): the
/// icon, clipped to the tile's corners, over the icon's ground.
///
/// [radius], [markOpacity], [markScale] and [glow] let the launch intro
/// animate it: the ground grows from a dot, then the icon fades and grows
/// in over it. At rest it is the plain icon.
class OnsetMarkTile extends StatelessWidget {
  final double size;

  /// Corner radius; defaults to the board's 20 at 72, scaled to [size].
  final double? radius;

  /// The icon fades and grows in over the ground on the launch boards.
  final double markOpacity;
  final double markScale;

  /// The soft accent halo around the tile on the launch boards.
  final List<BoxShadow>? glow;

  /// The side the tile ends up on screen when a transform scales it (the
  /// launch intro lays it out at 72 and scales it): the image is picked for
  /// that size, so the tile landing on the header shows the header's very
  /// pixels. [size] when null.
  final double? drawnSize;

  const OnsetMarkTile({
    super.key,
    this.size = OnsetMark.designSize,
    this.radius,
    this.markOpacity = 1,
    this.markScale = 1,
    this.glow,
    this.drawnSize,
  });

  @override
  Widget build(BuildContext context) {
    final corners = BorderRadius.circular(
      radius ?? OnsetMark.designRadius * size / OnsetMark.designSize,
    );
    final opacity = markOpacity.clamp(0.0, 1.0);
    return Semantics(
      label: 'ONSET',
      image: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: OnsetMark.ground,
            borderRadius: corners,
            boxShadow: glow,
          ),
          child: opacity <= 0
              ? null
              : ClipRRect(
                  borderRadius: corners,
                  child: Transform.scale(
                    scale: markScale,
                    child: Image(
                      image: OnsetMark.imageFor(drawnSize ?? size),
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      // Downscaled from a variant at least the tile's size:
                      // the default FilterQuality.medium (mipmapped
                      // bilinear) is the right filter for that.
                      // A tile changing size (the intro's flight) changes
                      // family: the last image stays until the next one
                      // is decoded.
                      gaplessPlayback: true,
                      // Announced once, by the tile.
                      excludeFromSemantics: true,
                      opacity: opacity >= 1
                          ? null
                          : AlwaysStoppedAnimation(opacity),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// The "ONSET" name of the launch boards: five letters (Inter 800, 34 sp on
/// a phone, 40 on a tablet) over the signal underline (120 / 140 × 2 dp,
/// 12 dp below).
///
/// The launch intro raises it letter by letter ([letters], one progress per
/// letter) and draws the underline in ([underline]); the onboarding shows it
/// at rest, at the very same place, so the first frame of the onboarding is
/// the last frame of the intro. Drawn one letter per [Text], as the intro
/// animates them, so both lay out the same.
class OnsetWordmark extends StatelessWidget {
  const OnsetWordmark({
    super.key,
    required this.tablet,
    this.letters = const [1, 1, 1, 1, 1],
    this.underline = 1,
    this.opacity = 1,
    this.underlineColor = OnsetTokens.accent,
  });

  final bool tablet;

  /// Each letter's rise, 0 (hidden, [rise] below) to 1 (in place).
  final List<double> letters;
  final double underline;
  final double opacity;
  final Color underlineColor;

  static const name = 'ONSET';

  /// Space between the tile's bottom edge and the name's top.
  static double gapBelowTile({required bool tablet}) => tablet ? 31 : 30;

  /// Letter size.
  static double letterSize({required bool tablet}) => tablet ? 40 : 34;

  @override
  Widget build(BuildContext context) {
    final size = letterSize(tablet: tablet);
    final rise = tablet ? 22.0 : 20.0;
    return Semantics(
      header: true,
      label: name,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, letter) in name.split('').indexed)
                _Letter(
                  letter: letter,
                  size: size,
                  progress: letters[i],
                  rise: rise,
                  opacity: opacity,
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: tablet ? 140 : 120,
            height: 2,
            child: Transform.scale(
              scaleX: underline,
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: underlineColor.withValues(
                    alpha: underlineColor.a * opacity,
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One letter of the wordmark rising into place.
class _Letter extends StatelessWidget {
  final String letter;
  final double size;
  final double progress;
  final double rise;
  final double opacity;

  const _Letter({
    required this.letter,
    required this.size,
    required this.progress,
    required this.rise,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, rise * (1 - progress)),
      child: Text(
        letter,
        style: TextStyle(
          fontFamily: OnsetTokens.displayFamily,
          fontSize: size,
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
          letterSpacing: -0.035 * size,
          height: 1.2,
          color: OnsetTokens.textPrimaryDark.withValues(
            alpha: (progress * opacity).clamp(0.0, 1.0),
          ),
        ),
      ),
    );
  }
}

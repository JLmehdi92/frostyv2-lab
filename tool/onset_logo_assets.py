"""The ONSET mark's bitmaps, derived from the app icon, for provenance.

Everywhere the app shows its mark (the home header, the launch intro, the
onboarding, the release notes, the update prompt) and the Android launch
splash, it shows the app icon itself (assets/icons/icon_onset.png, 1024 x
1024). Decoding the 1024 px icon for a 28-72 dp tile would cost a 4 MB
bitmap each time, so this script writes what each place needs:

Flutter, resolution-aware, one family per tile size (OnsetMark.imageFor in
lib/widgets/launch/onset_mark.dart picks the smallest family at least as
large as the tile; Flutter picks the variant for the pixel ratio):

    assets/icons/onset_logo_30.png  the headers (28 dp phone, 30 dp tablet)
    assets/icons/onset_logo_52.png  release notes, update prompt (52 dp)
    assets/icons/onset_logo_72.png  launch intro, onboarding (72 dp)
    each with 1.5x/, 2.0x/, 3.0x/ and 4.0x/ variants beside it.

Android, the launch tile of the splash (res/drawable/launch_background.xml
before Android 12, res/drawable/splash_icon.xml from 12): the 72 dp family
again, one bitmap per density bucket, with the tile's 20 dp corners cut out
as transparency (a bitmap drawable cannot be clipped in XML):

    android/app/src/main/res/drawable-{m,h,xh,xxh,xxx}dpi/launch_tile.png

The splash's pixels are the very pixels of the Flutter 72 dp variant of the
same ratio (only the corners differ), so the first Flutter frame of the
launch intro, which draws that variant clipped to the same corners, matches
the splash it replaces.

Each size is resampled straight from the 1024 px source with a Lanczos
filter in linear light (sRGB decoded first, re-encoded after), so the
halftone dots average to the right lime instead of a darker one. The
corners are antialiased from 16 x 16 samples per pixel. PNGs are written
without metadata, so a re-run on the same icon rewrites the same bytes.

The script also prints the icon's ground, the mean of its outer band, which
lib/widgets/launch/onset_mark.dart uses as the tile's fill behind the image
(OnsetMark.ground; a test checks they agree).

Usage (needs Pillow and NumPy), from the repository root:
    python3 -I tool/onset_logo_assets.py
"""
import os

import numpy as np
from PIL import Image

SOURCE = os.path.join('assets', 'icons', 'icon_onset.png')
FLUTTER_DIR = os.path.join('assets', 'icons')
ANDROID_RES = os.path.join('android', 'app', 'src', 'main', 'res')

FAMILIES = [30, 52, 72]  # dp
RATIOS = [(1.0, ''), (1.5, '1.5x'), (2.0, '2.0x'), (3.0, '3.0x'), (4.0, '4.0x')]

SPLASH_TILE = 72  # dp, OnsetMark.designSize
SPLASH_RADIUS = 20  # dp, OnsetMark.designRadius
DENSITIES = [
    (1.0, 'drawable-mdpi'),
    (1.5, 'drawable-hdpi'),
    (2.0, 'drawable-xhdpi'),
    (3.0, 'drawable-xxhdpi'),
    (4.0, 'drawable-xxxhdpi'),
]
SAMPLES = 16


def to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def downscale(linear, side):
    channels = []
    for i in range(3):
        band = Image.fromarray(linear[:, :, i].astype(np.float32), mode='F')
        channels.append(
            np.asarray(band.resize((side, side), Image.Resampling.LANCZOS)),
        )
    srgb = to_srgb(np.stack(channels, axis=-1).astype(np.float64))
    return np.round(srgb * 255.0).astype(np.uint8)


def corner_coverage(side, radius):
    """Share of each pixel inside a rounded square of [side] px."""
    offsets = (np.arange(SAMPLES) + 0.5) / SAMPLES
    pixel = np.arange(side)
    xs = (pixel[:, None] + offsets[None, :]).reshape(-1)
    # Distance outside the straight edges, towards the nearest corner centre.
    dx = np.maximum(np.maximum(radius - xs, xs - (side - radius)), 0.0)
    inside = (dx[:, None] ** 2 + dx[None, :] ** 2) <= radius ** 2
    inside = inside.reshape(side, SAMPLES, side, SAMPLES)
    return inside.mean(axis=(1, 3))


def save(pixels, path, mode):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(pixels, mode=mode).save(path, format='PNG', optimize=True)
    print(path, pixels.shape[1], os.path.getsize(path))


def main():
    source = Image.open(SOURCE).convert('RGB')
    if source.width != source.height:
        raise SystemExit('the icon must be square')
    srgb = np.asarray(source, dtype=np.float64) / 255.0
    linear = to_linear(srgb)

    band = np.concatenate([
        srgb[:16, :].reshape(-1, 3),
        srgb[-16:, :].reshape(-1, 3),
        srgb[:, :16].reshape(-1, 3),
        srgb[:, -16:].reshape(-1, 3),
    ])
    ground = np.round(band.mean(axis=0) * 255.0).astype(int)
    print('ground #%02X%02X%02X' % tuple(ground))

    for family in FAMILIES:
        for ratio, folder in RATIOS:
            side = round(family * ratio)
            name = 'onset_logo_%d.png' % family
            path = os.path.join(FLUTTER_DIR, folder, name)
            save(downscale(linear, side), path, 'RGB')

    for ratio, folder in DENSITIES:
        side = round(SPLASH_TILE * ratio)
        rgb = downscale(linear, side)
        alpha = np.round(
            corner_coverage(side, SPLASH_RADIUS * ratio) * 255.0,
        ).astype(np.uint8)
        rgba = np.dstack([rgb, alpha])
        save(rgba, os.path.join(ANDROID_RES, folder, 'launch_tile.png'), 'RGBA')


if __name__ == '__main__':
    main()

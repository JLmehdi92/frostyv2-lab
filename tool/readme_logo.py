"""Animated ONSET logo for the README, rebuilt from the launcher icon.

Reads assets/icons/icon_onset.png and writes, in .github/assets/:
  onset-logo.svg  the animated vector logo (CSS animations, no script, no
                  external resource): the source of the animation
  onset-logo.gif  the README hero, rendered frame by frame from the SVG
  onset-logo.png  the static logo, the animation's resting frame

Nothing is drawn by hand: every shape is measured from the icon.
  - The rays are capsules: each one is fitted with its principal axis, so it
    becomes a line with round caps (stroke width and end points measured).
  - The bottom dot is a circle (centroid and area).
  - The "ON" letters are traced with potrace, one path per letter.
  - The halftone is a square grid whose pitch and phase come from a Fourier
    fit of the dot pattern; dot sizes follow a smooth radial falloff fitted
    on every dot the letters do not cover (they hide about a third), so the
    dots under the letters get their true size too.

The animation is one loop of PERIOD seconds that replays the whole "signal
going ON" sequence, so a reader who scrolls to the logo late still sees it:
  hold        the resting logo (the loop's first frame is the static logo)
  power-down  the rays retract into the letters, the dot and the letters
              fade, the halftone shrinks ring by ring back to the centre
  build-up    the halftone ripples in from the centre, the "ON" lands with a
              short italic snap, the dot drops in with a bounce and the rays
              draw out one by one
  hold        the resting logo, with one gentle pulse (the rays ping outward
              and the dot beats); the halftone stays still, since a wave
              through it repaints the whole tile and would triple the GIF
The SVG shows the resting logo to viewers who ask for reduced motion; the
README GIF animates for everyone, by choice.

Why a GIF in the README: an SVG shown through <img> is animated by desktop
browsers, but not reliably on every GitHub surface (mobile Safari through
GitHub's image proxy, the GitHub apps). A GIF plays everywhere. The GIF is
rendered from the SVG in Chromium (Playwright), each frame frozen at its
time, at twice the README's display width; ffmpeg maps the whole loop to one
palette and Pillow writes each frame as the rectangle that changed. GIF
transparency is 1 bit, so the rounded corners are cut with a hard edge: no
matte colour to fringe on GitHub's light or dark page.

Why the SVG is written the way it is (WebKit, i.e. every iOS browser, is the
strictest engine that still animates SVG-as-image):
  - every element's timing lives in its own infinite @keyframes, expressed in
    percentages of the shared period: animation-delay only applies once, and
    with no delay at all every animation shares the same iteration boundary;
  - only the transform property is animated, never the individual
    scale/translate properties (iOS 14.5+ only);
  - transform-box: fill-box with an explicit transform-origin, and transform
    function lists that match between keyframes, so no engine falls back to
    matrix interpolation;
  - the rays are drawn with a dash measured in user units (px) instead of
    pathLength, whose effect on dashes WebKit has long applied unevenly;
  - scale(.001) instead of scale(0), so no transform is ever singular.

Usage (needs Pillow, numpy and potracer: pip install pillow numpy potracer;
the GIF also needs Playwright with Chromium and ffmpeg):
    python3 tool/readme_logo.py
    python3 tool/readme_logo.py --no-gif
    python3 tool/readme_logo.py --icon <png> --out <dir>
"""
import argparse
import io
import math
import os
import subprocess
import tempfile
from collections import deque

import numpy as np
import potrace
from PIL import Image, ImageDraw, ImageFilter

TILE = 1024          # the icon's size, and the SVG's view box
RADIUS = 228         # corner radius of the README tile (an app-icon squircle)
STATIC_SIZE = 512    # size of the static PNG
SUPERSAMPLE = 4      # anti-aliasing of the static PNG
UP = 2               # upsampling of the letters before tracing
# Green level that separates ink from the rest: lime is 244, the halftone
# dots about 170, but the dots that touch a letter are shaded down to ~105.
INK_LEVEL = 60

# Animation timing, in seconds within one loop of PERIOD.
PERIOD = 6.4         # the whole loop: hold, power-down, build-up, hold
OFF_AT = 0.40        # power-down starts (the loop opens on the resting logo)
OFF_EASE = 'cubic-bezier(.5,0,.9,.5)'
RING_STEP_OFF = 0.014  # power-down: delay between rings, outermost first
RING_OFF = 0.16      # power-down: time for one ring to shrink away
BUILD_AT = 0.85      # build-up starts; the offsets below count from here
INTRO_TONE = 0.10    # first halftone ring starts appearing
RING_STEP_IN = 0.032  # delay between rings while they appear
LAND_O = 0.20        # "O" lands
LAND_N = 0.30        # "N" lands
RAYS_AT = (0.78, 0.90, 1.02)  # left, middle, right ray draw out
DROP_AT = 0.52       # dot drops in
PULSE_AT = 3.9       # the hold's pulse (from the loop's start)
PING = 14            # ray ping distance, in px of the view box
BEAT = 1.06          # dot size at the pulse's beat

# The README GIF: drawn at 2x its display width (the README shows it at
# 160 px), rendered at RENDER_SCALE times that and downsampled for clean
# edges on the small halftone dots.
GIF_SIZE = 320
GIF_FPS = 25         # 4 cs per frame, an exact GIF delay; 160 frames a loop
GIF_COLORS = 256     # palette size, transparency included
RENDER_SCALE = 2

# --------------------------------------------------------------- measuring --

def load(path):
    rgb = np.asarray(Image.open(path).convert('RGB')).astype(np.float64)
    if rgb.shape[:2] != (TILE, TILE):
        raise SystemExit(f'expected a {TILE}x{TILE} icon, got {rgb.shape}')
    return rgb


def components(mask):
    """4-connected components of a boolean mask, largest first."""
    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    found = []
    for y0, x0 in zip(*np.nonzero(mask)):
        if seen[y0, x0]:
            continue
        seen[y0, x0] = True
        queue = deque([(y0, x0)])
        pts = []
        while queue:
            y, x = queue.popleft()
            pts.append((y, x))
            for yy, xx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= yy < h and 0 <= xx < w and mask[yy, xx] and not seen[yy, xx]:
                    seen[yy, xx] = True
                    queue.append((yy, xx))
        found.append(np.array(pts))
    found.sort(key=len, reverse=True)
    return found


def grow(mask, steps):
    """The mask dilated by `steps` pixels (square neighbourhood)."""
    out = mask.copy()
    for _ in range(steps):
        out[1:] |= out[:-1].copy()
        out[:-1] |= out[1:].copy()
        out[:, 1:] |= out[:, :-1].copy()
        out[:, :-1] |= out[:, 1:].copy()
    return out


def fit_ray(pts):
    """A capsule as (inner end, outer end, stroke width), ends on the axis."""
    p = np.stack([pts[:, 1], pts[:, 0]], 1).astype(np.float64) + 0.5
    c = p.mean(0)
    _, _, vt = np.linalg.svd(p - c, full_matrices=False)
    axis, normal = vt[0], vt[1]
    t = (p - c) @ axis
    width = 2 * np.percentile(np.abs((p - c) @ normal), 99.7)
    half = (t.max() - t.min()) / 2 - width / 2
    mid = c + axis * (t.max() + t.min()) / 2
    a, b = mid - axis * half, mid + axis * half
    # Inner end first: the one closer to the letters (lower on the tile).
    if a[1] < b[1]:
        a, b = b, a
    return a, b, width


def fit_grid(dark):
    """Pitch and phase of the halftone along x and y (Fourier fit)."""
    out = []
    for axis in (0, 1):
        s = dark.sum(axis)
        x = np.arange(len(s))
        best = None
        for p in np.arange(30.0, 48.0, 0.01):
            c = (s * np.exp(-2j * np.pi * x / p)).sum()
            if best is None or abs(c) > best[0]:
                best = (abs(c), p, (-np.angle(c) / (2 * np.pi) * p) % p)
        out.append(best[1:])
    return out  # [(pitch_x, phase_x), (pitch_y, phase_y)]


def falloff(params, x, y):
    cx, cy, sx, sy, k, amp, floor = params
    u = np.sqrt(((x - cx) / sx) ** 2 + ((y - cy) / sy) ** 2)
    return floor + amp * np.exp(-u ** k)


def fit_falloff(x, y, d):
    """Diameter = floor + amp * exp(-u^k), u an elliptic distance."""
    rng = np.random.default_rng(7)
    p = np.array([TILE / 2, TILE / 2, 420.0, 400.0, 2.0, d.max(), 1.0])
    loss = ((falloff(p, x, y) - d) ** 2).mean()
    step = np.array([10, 10, 30, 30, 0.3, 3, 0.5])
    for i in range(20000):
        q = p + rng.normal(0, 1, 7) * step * (0.3 if i > 10000 else 1.0)
        lq = ((falloff(q, x, y) - d) ** 2).mean()
        if lq < loss:
            p, loss = q, lq
    return p, math.sqrt(loss)


def trace(green, mask, paper):
    """Potrace outline of one letter, as SVG path data and polygons.

    The letter is traced on the icon's own anti-aliased edge (its green
    channel, upsampled UP times), limited to the letter's neighbourhood so
    neither the other letter nor the halftone leaks in.
    """
    near = grow(mask, 4)
    level = Image.fromarray(np.where(near, green, paper).astype(np.uint8))
    # A light blur first: the icon's edges carry compression noise, which
    # potrace would otherwise follow pixel by pixel.
    big = np.asarray(
        level.filter(ImageFilter.GaussianBlur(1.2)).resize(
            (TILE * UP, TILE * UP), Image.BICUBIC,
        ),
    ) < INK_LEVEL
    # potracer traces the False pixels of a boolean array.
    curves = potrace.Bitmap(~big).trace(
        turdsize=40 * UP * UP, alphamax=1.0, opticurve=True, opttolerance=1.0,
    )

    def v(p):
        return np.array([p.x, p.y]) / UP

    def pt(p):
        return f1(p.x / UP) + ',' + f1(p.y / UP)

    d = []
    polys = []
    for curve in curves:
        d.append('M' + pt(curve.start_point))
        poly = [v(curve.start_point)]
        last = v(curve.start_point)
        for seg in curve.segments:
            if seg.is_corner:
                d.append('L' + pt(seg.c) + 'L' + pt(seg.end_point))
                poly += [v(seg.c), v(seg.end_point)]
                last = v(seg.end_point)
            else:
                d.append(
                    'C' + pt(seg.c1) + ' ' + pt(seg.c2) + ' ' + pt(seg.end_point),
                )
                c1, c2, e = v(seg.c1), v(seg.c2), v(seg.end_point)
                for t in np.linspace(0, 1, 17)[1:]:
                    poly.append(
                        (1 - t) ** 3 * last + 3 * (1 - t) ** 2 * t * c1
                        + 3 * (1 - t) * t ** 2 * c2 + t ** 3 * e,
                    )
                last = e
        d.append('Z')
        polys.append(poly)
    return ''.join(d), polys


def measure(path):
    rgb = load(path)
    g = rgb[:, :, 1]
    ink = g < INK_LEVEL
    shapes = [c for c in components(ink) if len(c) > 1000]
    letters = sorted(shapes[:2], key=lambda c: c[:, 1].mean())
    rest = shapes[2:]
    rays = sorted(
        [c for c in rest if c[:, 0].mean() < 400], key=lambda c: c[:, 1].mean(),
    )
    drops = [c for c in rest if c[:, 0].mean() > 700]
    if len(rays) != 3 or len(drops) != 1:
        raise SystemExit('could not find the three rays and the dot')
    dot = drops[0]
    dot_c = (dot[:, 1].mean() + 0.5, dot[:, 0].mean() + 0.5)
    dot_r = math.sqrt(len(dot) / math.pi)

    lum = rgb.sum(2)
    paper = ~ink & (g > 236)
    bg = np.median(rgb[paper], 0)
    tone_mask = ~ink & (g < (bg[1] + 170) / 2)
    tone = np.median(rgb[tone_mask], 0)
    dark = np.clip((bg.sum() - lum) / (bg.sum() - tone.sum()), 0, 1)
    dark[ink] = 0

    (px, ox), (py, oy) = fit_grid(dark)
    # Grow the ink mask so a cell touching a letter counts as covered.
    covered = grow(ink, 3)
    xs, ys, ds = [], [], []
    half = int(min(px, py) / 2)
    for j in range(int(TILE / py) + 1):
        for i in range(int(TILE / px) + 1):
            cx, cy = ox + px * i, oy + py * j
            x0, x1 = int(cx) - half, int(cx) + half
            y0, y1 = int(cy) - half, int(cy) + half
            if x0 < 0 or y0 < 0 or x1 > TILE or y1 > TILE:
                continue
            if covered[y0:y1, x0:x1].any():
                continue
            xs.append(cx)
            ys.append(cy)
            ds.append(2 * math.sqrt(dark[y0:y1, x0:x1].sum() / math.pi))
    params, rmse = fit_falloff(np.array(xs), np.array(ys), np.array(ds))

    dots = []
    i0 = -int(ox // px) - 1
    j0 = -int(oy // py) - 1
    for j in range(j0, int(TILE / py) + 2):
        for i in range(i0, int(TILE / px) + 2):
            cx, cy = ox + px * i, oy + py * j
            d = float(falloff(params, cx, cy))
            if d < 0.8 or cx + d < 0 or cy + d < 0 or cx - d > TILE or cy - d > TILE:
                continue
            dots.append((cx, cy, d / 2))

    o_path, o_poly = trace(g, _mask(letters[0]), bg[1])
    n_path, n_poly = trace(g, _mask(letters[1]), bg[1])
    return {
        'bg': bg, 'tone': tone, 'ink': np.median(rgb[ink & (g < 30)], 0),
        'rays': [fit_ray(r) for r in rays],
        'dot': (dot_c, dot_r),
        'letters': [(o_path, o_poly), (n_path, n_poly)],
        'dots': dots, 'centre': (params[0], params[1]),
        'pitch': (px + py) / 2, 'rmse': rmse, 'grid': (px, ox, py, oy),
    }


def _mask(pts):
    m = np.zeros((TILE, TILE), dtype=bool)
    m[pts[:, 0], pts[:, 1]] = True
    return m


# ------------------------------------------------------------------ output --

def hexcol(c):
    return '#%02X%02X%02X' % tuple(int(round(v)) for v in c)


def shade(c, f):
    return [min(255, max(0, v * f)) for v in c]


def f1(v):
    s = f'{v:.1f}'
    return s[:-2] if s.endswith('.0') else s


def pct(t):
    s = f'{100 * t / PERIOD:.3f}'.rstrip('0').rstrip('.')
    return s + '%'


def keyframes(name, frames):
    """One @keyframes rule from (seconds, declarations, easing) triples.

    The easing of a keyframe is the timing function of the interval that
    starts there (for the properties that keyframe sets); None keeps the
    animation's own linear timing.
    """
    times = [t for t, _, _ in frames]
    if times[0] != 0 or times[-1] != PERIOD or any(
            b - a < 0.005 for a, b in zip(times, times[1:])):
        raise SystemExit(f'{name}: keyframes overlap or leave the loop: {times}')
    body = []
    for t, decl, ease in frames:
        if ease:
            decl += ';animation-timing-function:' + ease
        body.append(f'{pct(t)}{{{decl}}}')
    return f'@keyframes {name}{{' + ''.join(body) + '}'


def svg(m):
    bg, tone, ink = hexcol(m['bg']), m['tone'], hexcol(m['ink'])
    cx, cy = m['centre']
    pitch = m['pitch']
    rings = {}
    for x, y, r in m['dots']:
        k = int(math.hypot(x - cx, y - cy) / pitch)
        rings.setdefault(k, []).append((x, y, r))
    last = max(rings)
    loop = f'{PERIOD}s linear infinite'
    css = [
        '.t circle{transform-box:fill-box;transform-origin:50% 50%}'
        '.l,.d{transform-box:fill-box;transform-origin:50% 100%}'
        '@media (prefers-reduced-motion:reduce){*{animation:none!important}}',
    ]

    # Halftone: each ring shrinks away (outermost first, so the dots fall
    # back to the centre), then ripples back in from the centre.
    rest = 'transform:scale(1)'
    gone = 'transform:scale(.001)'
    for k in sorted(rings):
        off = OFF_AT + (last - k) * RING_STEP_OFF
        grow = BUILD_AT + INTRO_TONE + k * RING_STEP_IN
        css.append(f'.w{k} circle{{animation:h{k} {loop}}}' + keyframes(f'h{k}', [
            (0, rest, None),
            (off, rest, OFF_EASE),
            (off + RING_OFF, gone, None),
            (grow, gone, 'cubic-bezier(.2,.9,.3,1.25)'),
            (grow + 0.62, rest, None),
            (PERIOD, rest, None),
        ]))

    # Letters: fade down on power-down, then land with the italic snap.
    rest = 'opacity:1;transform:translateY(0px) skewX(0deg) scale(1)'
    for i, (land, off) in enumerate(((LAND_O, 0.18), (LAND_N, 0.14))):
        land += BUILD_AT
        off += OFF_AT
        css.append(f'.l{i + 1}{{animation:l{i + 1} {loop}}}' + keyframes(f'l{i + 1}', [
            (0, rest, None),
            (off, rest, OFF_EASE),
            (off + 0.2, 'opacity:0;transform:translateY(12px) skewX(0deg) scale(.9)', None),
            (land, 'opacity:0;transform:translateY(-34px) skewX(14deg) scale(1.08)',
             'cubic-bezier(.3,1.5,.5,1)'),
            (land + 0.45 * 0.58, 'opacity:1', None),
            (land + 0.58, rest, None),
            (PERIOD, rest, None),
        ]))

    # Dot: shrinks away, drops in with a bounce, beats with the pulse.
    rest = 'opacity:1;transform:translateY(0px) scale(1,1)'
    off = OFF_AT + 0.08
    drop = BUILD_AT + DROP_AT
    css.append(f'.d{{animation:d {loop}}}' + keyframes('d', [
        (0, rest, None),
        (off, rest, OFF_EASE),
        (off + 0.22, 'opacity:0;transform:translateY(0px) scale(.2,.2)', None),
        (drop, 'opacity:0;transform:translateY(-110px) scale(1,1)',
         'cubic-bezier(.5,0,1,.6)'),
        (drop + 0.18 * 0.9, 'opacity:1', None),
        (drop + 0.42 * 0.9, 'transform:translateY(0px) scale(1.14,.86)',
         'cubic-bezier(0,.5,.5,1)'),
        (drop + 0.62 * 0.9, 'transform:translateY(-34px) scale(.97,1.03)',
         'cubic-bezier(.5,0,1,.5)'),
        (drop + 0.80 * 0.9, 'transform:translateY(0px) scale(1.05,.95)', 'ease-out'),
        (drop + 0.9, rest, None),
        (PULSE_AT, rest, 'ease-in-out'),
        (PULSE_AT + 0.208, f'transform:translateY(0px) scale({BEAT},{BEAT})',
         'ease-in-out'),
        (PULSE_AT + 0.468, rest, None),
        (PERIOD, rest, None),
    ]))

    # Rays: a dash as long as the ray slides back into the letters (right
    # ray first), draws out again (left ray first), then pings outward.
    rays = []
    for i, (a, b, w) in enumerate(m['rays']):
        a = np.array([float(f1(v)) for v in a])
        b = np.array([float(f1(v)) for v in b])
        length = float(f1(np.linalg.norm(b - a)))
        ux, uy = (b - a) / np.linalg.norm(b - a)
        dash = f'stroke-dashoffset:{f1(length)}px'
        rest = 'opacity:1;stroke-dashoffset:0px;transform:translate(0px,0px)'
        off = OFF_AT + (2 - i) * 0.03
        draw = BUILD_AT + RAYS_AT[i]
        ping = PULSE_AT - 0.25 + i * 0.09
        css.append(f'.r{i}{{animation:r{i} {loop}}}' + keyframes(f'r{i}', [
            (0, rest, None),
            (off, rest, OFF_EASE),
            (off + 0.16, 'opacity:1', None),
            (off + 0.22, f'opacity:0;{dash};transform:translate(0px,0px)', None),
            (draw, f'opacity:0;{dash}', 'cubic-bezier(.3,.7,.3,1)'),
            (draw + 0.2 * 0.34, 'opacity:1', None),
            (draw + 0.34, rest, None),
            (ping, rest, 'ease-in-out'),
            (ping + 0.26, f'transform:translate({f1(ux * PING)}px,{f1(uy * PING)}px)',
             'ease-in-out'),
            (ping + 0.728, rest, None),
            (PERIOD, rest, None),
        ]))
        rays.append((a, b, w, length))

    out = []
    out.append(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {TILE} {TILE}" '
        f'width="{TILE}" height="{TILE}" role="img" aria-label="ONSET">',
    )
    out.append('<title>ONSET</title>')
    out.append('<defs>')
    out.append(
        f'<clipPath id="tile"><rect width="{TILE}" height="{TILE}" '
        f'rx="{RADIUS}"/></clipPath>',
    )
    out.append(
        '<radialGradient id="dot" cx=".56" cy=".58" r=".62">'
        f'<stop offset=".55" stop-color="{hexcol(shade(tone, 1.03))}"/>'
        f'<stop offset="1" stop-color="{hexcol(shade(tone, 0.93))}"/>'
        '</radialGradient>',
    )
    out.append('</defs>')
    out.append('<style>' + ''.join(css) + '</style>')
    out.append('<g clip-path="url(#tile)">')
    out.append(f'<rect width="{TILE}" height="{TILE}" fill="{bg}"/>')
    out.append('<g class="t" fill="url(#dot)">')
    for k in sorted(rings):
        out.append(f'<g class="w{k}">')
        out.append(''.join(
            f'<circle cx="{f1(x)}" cy="{f1(y)}" r="{f1(r)}"/>'
            for x, y, r in rings[k]
        ))
        out.append('</g>')
    out.append('</g>')
    out.append(f'<g stroke="{ink}" stroke-linecap="round" fill="none">')
    for i, (a, b, w, length) in enumerate(rays):
        # The gap is twice the dash, so a dash pushed one length along
        # leaves the ray empty.
        out.append(
            f'<line class="r{i}" x1="{f1(a[0])}" y1="{f1(a[1])}" '
            f'x2="{f1(b[0])}" y2="{f1(b[1])}" stroke-width="{f1(w)}" '
            f'stroke-dasharray="{f1(length)} {f1(2 * length)}"/>',
        )
    out.append('</g>')
    out.append(f'<g fill="{ink}">')
    for i, (d, _) in enumerate(m['letters']):
        out.append(f'<path class="l l{i + 1}" d="{d}"/>')
    (dx, dy), dr = m['dot']
    out.append(
        f'<circle class="d" cx="{f1(dx)}" cy="{f1(dy)}" r="{f1(dr)}"/>',
    )
    out.append('</g></g></svg>')
    return '\n'.join(out) + '\n'


def png(m, size):
    s = SUPERSAMPLE * size / TILE
    big = SUPERSAMPLE * size
    img = Image.new('RGB', (big, big), tuple(int(round(v)) for v in m['bg']))
    draw = ImageDraw.Draw(img)
    tone = tuple(int(round(v)) for v in m['tone'])
    for x, y, r in m['dots']:
        draw.ellipse([(x - r) * s, (y - r) * s, (x + r) * s, (y + r) * s], fill=tone)
    ink = tuple(int(round(v)) for v in m['ink'])
    for a, b, w in m['rays']:
        draw.line([tuple(a * s), tuple(b * s)], fill=ink, width=int(round(w * s)))
        for p in (a, b):
            draw.ellipse([(p[0] - w / 2) * s, (p[1] - w / 2) * s,
                          (p[0] + w / 2) * s, (p[1] + w / 2) * s], fill=ink)
    (dx, dy), dr = m['dot']
    draw.ellipse([(dx - dr) * s, (dy - dr) * s, (dx + dr) * s, (dy + dr) * s], fill=ink)
    # Letters: even-odd fill, so the counter of the "O" stays open.
    letters = Image.new('1', (big, big), 0)
    for _, polys in m['letters']:
        for poly in polys:
            layer = Image.new('1', (big, big), 0)
            ImageDraw.Draw(layer).polygon([tuple(p * s) for p in poly], fill=1)
            letters = Image.fromarray(np.asarray(letters) ^ np.asarray(layer))
    img.paste(ink, mask=letters)
    tile = Image.new('L', (big, big), 0)
    ImageDraw.Draw(tile).rounded_rectangle(
        [0, 0, big - 1, big - 1], radius=RADIUS * s, fill=255,
    )
    out = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    out.paste(img, mask=tile)
    return out.resize((size, size), Image.LANCZOS)


# Moves every animation of the page to `t` ms and freezes it there: the
# animated values are written as inline styles and the animations switched
# off, so Chromium draws the frame as a still SVG. A paused but live
# animation is rasterised differently (softer edges), and would not match
# the static logo pixel for pixel.
FREEZE_JS = """async t => {
  const freeze = document.getElementById('freeze');
  freeze.disabled = true;
  document.querySelectorAll('svg [style]').forEach(e => e.removeAttribute('style'));
  const all = document.getAnimations();
  all.forEach(a => { a.pause(); a.currentTime = t; });
  all.forEach(a => a.commitStyles());
  freeze.disabled = false;
  await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)));
  return all.length;
}"""


def render(svg_text, size, times, background='transparent', clip=True):
    """Frames of the SVG animation at the given times (seconds), as RGB images.

    The SVG is inlined in a page in Chromium and each frame is frozen at its
    time (FREEZE_JS), then captured. With clip=False the tile's rounded
    corners are left uncut, for the caller to cut.
    """
    from playwright.sync_api import sync_playwright

    css = f'html,body{{margin:0;background:{background}}}svg{{display:block}}'
    if not clip:
        css += 'svg g[clip-path]{clip-path:none}'
    # Sized by its own attributes, so nothing is resampled.
    svg_text = svg_text.replace(
        f'width="{TILE}" height="{TILE}"', f'width="{size}" height="{size}"', 1,
    )
    html = (
        f'<!doctype html><html><head><style>{css}</style>'
        '<style id="freeze">*{animation:none!important}</style></head>'
        f'<body>{svg_text}</body></html>'
    )
    frames = []
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(
            viewport={'width': size, 'height': size}, device_scale_factor=1,
            reduced_motion='no-preference',
        )
        page.set_content(html)
        # The first frozen capture is drawn slightly differently (the corner
        # clip's anti-aliasing); take one and drop it, so every frame comes
        # from the same path.
        page.evaluate(FREEZE_JS, 0)
        page.screenshot()
        for t in times:
            if page.evaluate(FREEZE_JS, t * 1000) == 0:
                raise SystemExit('the SVG has no animation to render')
            png_bytes = page.screenshot(
                clip={'x': 0, 'y': 0, 'width': size, 'height': size},
            )
            frames.append(Image.open(io.BytesIO(png_bytes)).convert('RGB'))
        browser.close()
    return frames


def corner_mask(size):
    """The tile's rounded square at `size`, as a hard 1-bit mask.

    GIF transparency is all or nothing, so a pixel belongs to the tile when
    the tile covers at least half of it (measured on a 4x supersample): an
    anti-aliased edge would need a matte colour, which fringes on either
    GitHub's light or dark page.
    """
    big = size * SUPERSAMPLE
    m = Image.new('L', (big, big), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        [0, 0, big - 1, big - 1], radius=RADIUS * big / TILE, fill=255,
    )
    m = m.resize((size, size), Image.BOX)
    return m.point(lambda v: 255 if v >= 128 else 0)


def gif(svg_text, path):
    """The README GIF: one seamless loop of the SVG animation, looping forever."""
    frames_n = round(PERIOD * GIF_FPS)
    if abs(frames_n - PERIOD * GIF_FPS) > 1e-9:
        raise SystemExit('PERIOD must be a whole number of GIF frames')
    times = [i / GIF_FPS for i in range(frames_n)]
    big = render(svg_text, GIF_SIZE * RENDER_SCALE, times, clip=False)
    mask = corner_mask(GIF_SIZE)
    with tempfile.TemporaryDirectory() as tmp:
        for i, frame in enumerate(big):
            small = frame.resize((GIF_SIZE, GIF_SIZE), Image.LANCZOS).convert('RGBA')
            small.putalpha(mask)
            small.save(os.path.join(tmp, f'f{i:04d}.png'))
        # ffmpeg picks one palette for the whole loop and maps every frame to
        # it. No dithering: the logo is a few flat colours and their
        # anti-aliased blends, so a dither would only add noise to the flat
        # lime, shimmer from frame to frame and defeat the frame differences.
        subprocess.run([
            'ffmpeg', '-v', 'error', '-y', '-i', os.path.join(tmp, 'f%04d.png'),
            '-filter_complex',
            '[0:v]split[a][b];'
            f'[a]palettegen=max_colors={GIF_COLORS}:reserve_transparent=1:'
            'stats_mode=full[p];'
            '[b][p]paletteuse=dither=none:alpha_threshold=128',
            '-pix_fmt', 'pal8', '-start_number', '0',
            os.path.join(tmp, 'q%04d.png'),
        ], check=True)
        frames = [
            Image.open(os.path.join(tmp, f'q{i:04d}.png')) for i in range(frames_n)
        ]
        for f in frames:
            f.load()
        # Pillow writes the GIF rather than ffmpeg: with a transparent colour
        # ffmpeg repaints every frame in full, while Pillow keeps each frame
        # to the rectangle that changed (disposal 1, nothing cleared) and
        # merges identical frames into one longer frame.
        frames[0].save(
            path, save_all=True, append_images=frames[1:],
            duration=round(1000 / GIF_FPS), loop=0, disposal=1, optimize=False,
            transparency=frames[0].info['transparency'],
        )


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--icon', default=os.path.join(root, 'assets/icons/icon_onset.png'))
    ap.add_argument('--out', default=os.path.join(root, '.github/assets'))
    ap.add_argument(
        '--no-gif', action='store_true',
        help='skip the README GIF (needs Playwright with Chromium and ffmpeg)',
    )
    args = ap.parse_args()
    m = measure(args.icon)
    os.makedirs(args.out, exist_ok=True)
    vector = svg(m)
    with open(os.path.join(args.out, 'onset-logo.svg'), 'w', newline='\n') as f:
        f.write(vector)
    # A 64-colour palette keeps the PNG small; the logo has three colours
    # plus their anti-aliased edges.
    png(m, STATIC_SIZE).quantize(64, method=Image.Quantize.FASTOCTREE).save(
        os.path.join(args.out, 'onset-logo.png'), optimize=True,
    )
    if not args.no_gif:
        gif(vector, os.path.join(args.out, 'onset-logo.gif'))
    px, ox, py, oy = m['grid']
    print(f'background {hexcol(m["bg"])}, halftone {hexcol(m["tone"])}, ink {hexcol(m["ink"])}')
    print(f'grid pitch {px:.2f} x {py:.2f}, phase {ox:.1f}, {oy:.1f}; '
          f'{len(m["dots"])} dots, size fit rmse {m["rmse"]:.2f} px')
    for a, b, w in m['rays']:
        print(f'ray {a.round(1)} -> {b.round(1)}, width {w:.1f}')
    print(f'dot {np.round(m["dot"][0], 1)}, radius {m["dot"][1]:.1f}')


if __name__ == '__main__':
    main()

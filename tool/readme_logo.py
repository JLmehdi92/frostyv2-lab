"""Animated ONSET logo for the README, rebuilt from the launcher icon.

Reads assets/icons/icon_onset.png and writes, in .github/assets/:
  onset-logo.svg  the animated logo (CSS animations, no script, no external
                  resource, so GitHub renders it in an <img> tag)
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

The animation: the halftone ripples in from the centre, the "ON" lands with
a short italic snap, the rays light up one by one and the dot drops in with
a bounce. Then, every few seconds, the rays ping outward and a broadcast
wave runs through the halftone. Its resting state is the static logo, which
is also what viewers who ask for reduced motion get.

Usage (needs Pillow, numpy and potracer: pip install pillow numpy potracer):
    python3 -I tool/readme_logo.py
    python3 -I tool/readme_logo.py --icon <png> --out <dir>
"""
import argparse
import math
import os
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

# Animation timing, in seconds.
INTRO_TONE = 0.10    # first halftone ring starts appearing
RING_STEP_IN = 0.032  # delay between rings while they appear
LAND_O = 0.20        # "O" lands
LAND_N = 0.30        # "N" lands
RAYS_AT = (0.78, 0.90, 1.02)  # left, middle, right ray light up
DROP_AT = 0.52       # dot drops in
PERIOD = 5.2         # ambient loop period
LOOP_AT = 2.2        # first ambient beat
RING_STEP_WAVE = 0.075  # wave travel time per ring


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


def svg(m):
    bg, tone, ink = hexcol(m['bg']), m['tone'], hexcol(m['ink'])
    cx, cy = m['centre']
    pitch = m['pitch']
    rings = {}
    for x, y, r in m['dots']:
        k = int(math.hypot(x - cx, y - cy) / pitch)
        rings.setdefault(k, []).append((x, y, r))
    css = []
    css.append(f"""
.t circle{{transform-box:fill-box;transform-origin:center;
animation:in .62s cubic-bezier(.2,.9,.3,1.25) both,wave {PERIOD}s ease-in-out infinite}}
@keyframes in{{from{{scale:0}}to{{scale:1}}}}
@keyframes wave{{0%,22%,100%{{transform:none}}7%{{transform:scale(1.38)}}}}
.l{{transform-box:fill-box;transform-origin:50% 100%;
animation:land .58s cubic-bezier(.3,1.5,.5,1) both}}
.l1{{animation-delay:{LAND_O}s}}.l2{{animation-delay:{LAND_N}s}}
@keyframes land{{0%{{opacity:0;transform:translateY(-34px) skewX(14deg) scale(1.08)}}
45%{{opacity:1}}100%{{opacity:1;transform:none}}}}
.r line{{stroke-dasharray:1 2;stroke-dashoffset:0;
animation:ray .34s cubic-bezier(.3,.7,.3,1) both}}
@keyframes ray{{0%{{stroke-dashoffset:1;opacity:0}}20%{{opacity:1}}100%{{stroke-dashoffset:0;opacity:1}}}}
.d{{transform-box:fill-box;transform-origin:50% 100%;
animation:drop .9s linear {DROP_AT}s both,beat {PERIOD}s ease-in-out {LOOP_AT}s infinite}}
@keyframes drop{{0%{{opacity:0;transform:translateY(-110px);animation-timing-function:cubic-bezier(.5,0,1,.6)}}
18%{{opacity:1}}
42%{{transform:translateY(0) scale(1.14,.86);animation-timing-function:cubic-bezier(0,.5,.5,1)}}
62%{{transform:translateY(-34px) scale(.97,1.03);animation-timing-function:cubic-bezier(.5,0,1,.5)}}
80%{{transform:translateY(0) scale(1.05,.95);animation-timing-function:ease-out}}
100%{{opacity:1;transform:none}}}}
@keyframes beat{{0%,9%,100%{{scale:1}}4%{{scale:1.07}}}}
@media (prefers-reduced-motion:reduce){{*{{animation:none!important}}}}
""".strip())
    # Rays: drawn from the letters outward, then a ping every period.
    rays = []
    for i, ((a, b, w), at) in enumerate(zip(m['rays'], RAYS_AT)):
        ux, uy = (b - a) / np.linalg.norm(b - a)
        css.append(
            f'.r{i} line{{animation-delay:{at}s}}'
            f'.r{i}{{animation:p{i} {PERIOD}s ease-in-out '
            f'{LOOP_AT - 0.25 + i * 0.09:.2f}s infinite}}'
            f'@keyframes p{i}{{0%,14%,100%{{translate:0 0}}'
            f'5%{{translate:{ux * 18:.1f}px {uy * 18:.1f}px}}}}',
        )
        rays.append((a, b, w))
    for k in sorted(rings):
        css.append(
            f'.w{k} circle{{animation-delay:'
            f'{INTRO_TONE + k * RING_STEP_IN:.3f}s,'
            f'{LOOP_AT + k * RING_STEP_WAVE:.3f}s}}',
        )
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
    out.append('<style>' + ''.join(css).replace('\n', '') + '</style>')
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
    for i, (a, b, w) in enumerate(rays):
        out.append(
            f'<g class="r r{i}"><line x1="{f1(a[0])}" y1="{f1(a[1])}" '
            f'x2="{f1(b[0])}" y2="{f1(b[1])}" stroke-width="{f1(w)}" '
            'pathLength="1"/></g>',
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


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--icon', default=os.path.join(root, 'assets/icons/icon_onset.png'))
    ap.add_argument('--out', default=os.path.join(root, '.github/assets'))
    args = ap.parse_args()
    m = measure(args.icon)
    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(args.out, 'onset-logo.svg'), 'w', newline='\n') as f:
        f.write(svg(m))
    # A 64-colour palette keeps the PNG small; the logo has three colours
    # plus their anti-aliased edges.
    png(m, STATIC_SIZE).quantize(64, method=Image.Quantize.FASTOCTREE).save(
        os.path.join(args.out, 'onset-logo.png'), optimize=True,
    )
    px, ox, py, oy = m['grid']
    print(f'background {hexcol(m["bg"])}, halftone {hexcol(m["tone"])}, ink {hexcol(m["ink"])}')
    print(f'grid pitch {px:.2f} x {py:.2f}, phase {ox:.1f}, {oy:.1f}; '
          f'{len(m["dots"])} dots, size fit rmse {m["rmse"]:.2f} px')
    for a, b, w in m['rays']:
        print(f'ray {a.round(1)} -> {b.round(1)}, width {w:.1f}')
    print(f'dot {np.round(m["dot"][0], 1)}, radius {m["dot"][1]:.1f}')


if __name__ == '__main__':
    main()

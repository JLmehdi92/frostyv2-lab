"""Outlines of the "ON" in the ONSET launch tile, for provenance.

The tile's "ON" is Inter Bold Italic (bundled, SIL Open Font License) at
32 px with -0.05 em tracking, centred in a 72 x 72 box, as on the launch
boards. Flutter (lib/widgets/launch/onset_mark.dart) and the Android splash
(android/app/src/main/res/drawable/launch_tile.xml) draw the same outline, so
the native splash hands over to the Flutter intro without a visible change;
test/widgets/launch/onset_mark_test.dart checks they agree.

Usage (needs fontTools):
    python3 -I scripts/onset_mark_glyphs.py assets/fonts/Inter-BoldItalic.ttf
Prints the SVG path (OnsetMark.glyphsSvg and the vector's pathData).
"""
import sys
from fontTools.ttLib import TTFont
from fontTools.pens.basePen import BasePen
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.transformPen import TransformPen

font = TTFont(sys.argv[1])
gs = font.getGlyphSet(); cmap = font.getBestCmap()
upm = font['head'].unitsPerEm
SIZE = 32.0; TILE = 72.0; LS = -0.05 * SIZE
s = SIZE / upm

class Rec(BasePen):
    def __init__(self, gs):
        super().__init__(gs); self.ops = []
    def _moveTo(self, p): self.ops.append(('M', p))
    def _lineTo(self, p): self.ops.append(('L', p))
    def _qCurveToOne(self, c, p): self.ops.append(('Q', c, p))
    def _curveToOne(self, c1, c2, p): self.ops.append(('C', c1, c2, p))
    def _closePath(self): self.ops.append(('Z',))
    def _endPath(self): self.ops.append(('Z',))

# Lay out O then N with the letter spacing, in px, y down.
x = 0.0; placed = []
for ch in 'ON':
    g = cmap[ord(ch)]
    placed.append((g, x))
    x += gs[g].width * s + LS
bp = BoundsPen(gs)
for g, ox in placed:
    gs[g].draw(TransformPen(bp, (s, 0, 0, -s, ox, 0)))
xmin, ymin, xmax, ymax = bp.bounds
dx = TILE / 2 - (xmin + xmax) / 2
dy = TILE / 2 - (ymin + ymax) / 2
rec = Rec(gs)
for g, ox in placed:
    gs[g].draw(TransformPen(rec, (s, 0, 0, -s, ox + dx, dy)))

def f(v): return ('%.2f' % v).rstrip('0').rstrip('.')
def pt(p): return f(p[0]) + ',' + f(p[1])
svg = []
for op in rec.ops:
    k = op[0]
    if k == 'M': svg.append('M' + pt(op[1]))
    elif k == 'L': svg.append('L' + pt(op[1]))
    elif k == 'Q': svg.append('Q' + pt(op[1]) + ' ' + pt(op[2]))
    elif k == 'C': svg.append('C' + pt(op[1]) + ' ' + pt(op[2]) + ' ' + pt(op[3]))
    else: svg.append('Z')
print(''.join(svg))

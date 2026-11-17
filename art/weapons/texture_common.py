"""Shared helpers for painting weapon textures (numpy and Pillow, ordinary Python).

A weapon's make_texture.py makes a Canvas from its build script's SIZE and RECTS, paints
each rectangle with a function of (a, b, h, w), and saves. a runs 0..1 across a rectangle
and b down it; the function returns the colours. Everything is painted four times too big
and scaled down, which gives the soft, hand-painted look vanilla's small weapon textures
have, and each part is painted a pixel past its rectangle so nothing dark creeps in at
its edges.

The colours and the common materials (wood, duct tape, steel) are here so the weapons
match each other. The hockey stick cleaver was painted before this file and keeps its own
copy of the same code.
"""
import numpy as np
from PIL import Image

WOOD = np.array([208, 164, 102]) / 255.0
WOOD_PALE = np.array([222, 190, 138]) / 255.0
WALNUT = np.array([90, 57, 36]) / 255.0
STEEL = np.array([170, 174, 181]) / 255.0
STEEL_BRIGHT = np.array([226, 229, 233]) / 255.0
STEEL_DARK = np.array([112, 116, 124]) / 255.0
DUCT = np.array([158, 161, 166]) / 255.0
RUST = np.array([122, 82, 54]) / 255.0
BLACK = np.array([30, 30, 34]) / 255.0
WHITE = np.array([232, 230, 222]) / 255.0
RED = np.array([168, 30, 36]) / 255.0
BLUE = np.array([38, 62, 138]) / 255.0


def mix(base, colour, mask):
    m = np.clip(mask, 0.0, 1.0)[..., None]
    return base * (1.0 - m) + np.asarray(colour) * m


def band(x, lo, hi, soft=0.0):
    """1 between lo and hi, with soft shoulders."""
    if soft <= 0:
        return ((x >= lo) & (x < hi)).astype(np.float32)
    return np.clip((x - lo) / soft, 0, 1) * np.clip((hi - x) / soft, 0, 1)


class Canvas:
    def __init__(self, size, rects, seed=1993, ss=4):
        self.size, self.rects, self.ss = size, rects, ss
        self.n = size * ss
        self.rng = np.random.default_rng(seed)
        self.img = np.zeros((self.n, self.n, 3), np.float32)

    def smooth(self, h, w, cells_y, cells_x):
        """Soft noise, about -1..1: random cells stretched to h x w."""
        small = self.rng.normal(0.0, 1.0, (max(2, int(cells_y)), max(2, int(cells_x)))).astype(np.float32)
        lo, hi = small.min(), small.max()
        im = Image.fromarray(((small - lo) / (hi - lo) * 255).astype(np.uint8))
        big = np.asarray(im.resize((w, h), Image.BICUBIC), np.float32) / 255.0
        return big * 2.0 - 1.0

    def grain(self, h, w, along, fine=1.6, coarse=18.0):
        """Wood grain or brushed metal: streaks running `along` "v" (down) or "u" (across)."""
        ss = self.ss
        if along == "v":
            return self.smooth(h, w, int(h / (coarse * ss)) + 2, int(w / (fine * ss)) + 2)
        return self.smooth(h, w, int(h / (fine * ss)) + 2, int(w / (coarse * ss)) + 2)

    def paint(self, name, fn):
        """Call fn(a, b, h, w) for a part: a runs 0..1 across its rectangle and b down it
        (a little past both ends, for the bleed); it returns the colours."""
        ss, n = self.ss, self.n
        x0, y0, x1, y1 = self.rects[name]
        px0, py0 = max(0, x0 * ss - ss), max(0, y0 * ss - ss)
        px1, py1 = min(n, x1 * ss + ss), min(n, y1 * ss + ss)
        xs = (np.arange(px0, px1) + 0.5 - x0 * ss) / ((x1 - x0) * ss)
        ys = (np.arange(py0, py1) + 0.5 - y0 * ss) / ((y1 - y0) * ss)
        a, b = np.meshgrid(xs, ys)
        self.img[py0:py1, px0:px1] = np.clip(fn(a, b, py1 - py0, px1 - px0), 0.0, 1.0)

    def save(self, path, empty=WOOD * 0.8):
        """What is left empty takes a mid colour, so scaled-down copies have no black fringes."""
        self.img[self.img.sum(axis=2) == 0] = empty
        out = Image.fromarray((np.clip(self.img, 0, 1) * 255 + 0.5).astype(np.uint8))
        out = out.resize((self.size, self.size), Image.LANCZOS)
        out.save(path)
        print("wrote", path, out.size)

    # Materials ------------------------------------------------------------------------------
    def wood(self, a, b, h, w, colour=WOOD, along="v", round_a=0.0, round_b=0.0):
        """Grain running `along`; round_a / round_b shade towards the rectangle's a or b
        edges, for a part whose rectangle is one flat face of something rounded."""
        col = colour * (1.0 + 0.09 * self.grain(h, w, along) + 0.04 * self.smooth(h, w, 12, 12))[..., None]
        if round_a:
            col = col * (1.0 - round_a * np.abs(2.0 * a - 1.0) ** 2.5)[..., None]
        if round_b:
            col = col * (1.0 - round_b * np.abs(2.0 * b - 1.0) ** 2.5)[..., None]
        return col

    def end_grain(self, a, b, h, w, colour=WOOD):
        r = np.sqrt((a - 0.5) ** 2 + (b - 0.5) ** 2)
        rings = 0.5 + 0.5 * np.sin(r * 34.0)
        return colour * 0.80 * (1.0 - 0.14 * rings + 0.05 * self.smooth(h, w, 6, 6))[..., None]

    def duct(self, a, b, h, w, across="a"):
        """Duct tape: one turn's face, wrinkled; the band's two free edges are along the
        `across` coordinate's ends ("a": left and right, "b": top and bottom)."""
        col = DUCT * (1.0 + 0.05 * self.smooth(h, w, 6, 14) + 0.03 * self.grain(h, w, "u", fine=0.8, coarse=3.0)
                      + 0.03 * self.grain(h, w, "v", fine=0.8, coarse=3.0))[..., None]
        crease = np.abs(((a * 3.1 + b * 0.8) % 1.0) - 0.5)
        col = mix(col, DUCT * 1.22, band(crease, 0.0, 0.035, 0.012))     # wrinkles catch the light
        col = mix(col, DUCT * 0.74, band(crease, 0.045, 0.085, 0.012))
        e = b if across == "b" else a
        col = mix(col, DUCT * 0.70, band(e, 0.47, 0.50))                 # where one turn laps the last
        return col * (1.0 - 0.30 * np.abs(2.0 * e - 1.0) ** 6)[..., None]

    def tape_edge(self, a, b, h, w):
        return DUCT * 0.62 * (1.0 + 0.05 * self.smooth(h, w, 4, 8))[..., None]

    def steel(self, a, b, h, w, along="u", colour=STEEL):
        return colour * (1.0 + 0.055 * self.grain(h, w, along, fine=1.2, coarse=30.0))[..., None]

"""Paint the texture the lock in a sock and the sock flail share: LockInASock.png, 256x256.

  python make_texture.py

The layout and measurements come from build_sock.py; the materials from
../texture_common.py.
"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import build_sock as sk  # noqa: E402
import texture_common as tc  # noqa: E402
from texture_common import band, mix  # noqa: E402

c = tc.Canvas(sk.SIZE, sk.RECTS, seed=1996)
COTTON = np.array([226, 222, 210]) / 255.0
GRIME = np.array([128, 120, 104]) / 255.0


# The sock: once round it across the strip (the two flat sides of the toe are at a = 0
# and a = 0.5), the cuff at the top
def sock(a, b, h, w):
    col = COTTON * (1.0 + 0.04 * c.smooth(h, w, 60, 16))[..., None]
    rib = np.abs(((a * 22.0) % 1.0) - 0.5) * 2.0                     # ribbing, along the sock
    col = col * (0.90 + 0.10 * rib)[..., None]
    # the cuff: tighter ribbing and the two bands a tube sock has
    cuff = b < 0.10
    col = np.where(cuff[..., None], col * (0.93 + 0.07 * (np.abs(((a * 44.0) % 1.0) - 0.5) * 2.0))[..., None], col)
    for (lo, hi), colour in zip(sk.CUFF_STRIPES, (tc.RED, tc.BLUE)):
        col = mix(col, colour * (0.9 + 0.1 * rib)[..., None], band(b, lo, hi, 0.003))
    # wrung and twisted from the fist to the knot: creases on a slant
    twist = band(b, 0.13, 0.66, 0.04)
    crease = np.abs((((a * 3.0 + b * 9.0) % 1.0) - 0.5) * 2.0)
    col = mix(col, COTTON * 0.62, 0.55 * twist * band(crease, 0.0, 0.22, 0.10))
    col = mix(col, COTTON * 1.06, 0.5 * twist * band(crease, 0.55, 0.80, 0.10))
    # the knot: a dark fold either side of it
    for kb in (0.575, 0.635):
        col = mix(col, COTTON * 0.50, band(b, kb - 0.012, kb + 0.012, 0.008))
    # the toe: stretched thin over the padlock, its body and shackle showing through on
    # both flat sides, and grey with wear
    side = np.minimum(np.minimum(a, 1.0 - a), np.abs(a - 0.5)) / 0.25     # 0 mid flat side, 1 at the thin edges
    t = (b - sk.LOCK_B0) / (sk.LOCK_B1 - sk.LOCK_B0)                      # 0 where the lock starts, 1 at its far end
    on = band(t, 0.0, 1.0, 0.04)
    body = band(t, 0.42, 0.96, 0.03) * band(side, -1.0, 0.72, 0.05)
    col = mix(col, COTTON * 0.80, 0.55 * on * (1.0 - body))                # slack round it, in shade
    col = mix(col, COTTON * 1.04, 0.6 * body)                              # tight over the body
    rim = band(t, 0.40, 0.98, 0.02) * band(side, 0.62, 0.78, 0.04) + band(t, 0.40, 0.46, 0.02) * band(side, -1.0, 0.75, 0.04)
    col = mix(col, COTTON * 0.55, 0.6 * rim)                               # the body's edges
    r = np.sqrt((side / 0.50) ** 2 + ((t - 0.40) / 0.30) ** 2)
    col = mix(col, COTTON * 0.60, 0.6 * band(r, 0.82, 1.0, 0.06) * (t < 0.41))   # the shackle's arc
    col = mix(col, STEEL_SHOW, 0.22 * body * (c.smooth(h, w, 40, 10) > 0.1))     # metal through the weave
    col = mix(col, GRIME, 0.50 * band(b, 0.86, 1.2, 0.08) * (0.6 + 0.4 * c.smooth(h, w, 30, 8)))
    # grubby all over, more where it is held
    col = mix(col, GRIME, 0.16 * (c.smooth(h, w, 24, 6) > 0.1))
    return mix(col, GRIME, 0.30 * band(b, 0.10, 0.30, 0.06))


STEEL_SHOW = np.array([150, 150, 150]) / 255.0


def wood(a, b, h, w):
    col = tc.WOOD * (1.0 + 0.08 * c.grain(h, w, "v") + 0.04 * c.smooth(h, w, 30, 4))[..., None]
    col = mix(col, tc.WOOD * 0.64, 0.6 * band(b, 0.14, 0.72, 0.06) * (0.7 + 0.3 * c.smooth(h, w, 20, 5)))
    col = mix(col, tc.WOOD * 0.45, band(b, 0.065, 0.085, 0.006))           # a turned groove at the pommel
    face = (a * sk.HANDLE_N) % 1.0
    return col * (1.0 - 0.12 * np.abs(2.0 * face - 1.0) ** 2)[..., None]


def toe(a, b, h, w):
    col = COTTON * 0.74 * (1.0 + 0.06 * c.smooth(h, w, 8, 8))[..., None]
    col = mix(col, GRIME, 0.5)
    return mix(col, COTTON * 0.45, band(b, 0.44, 0.56, 0.03))              # the seam


def inside(a, b, h, w):
    r = np.sqrt((a - 0.5) ** 2 + (b - 0.5) ** 2)
    col = np.broadcast_to(COTTON * 0.20, (h, w, 3)).copy()
    return mix(col, COTTON * 0.55, band(r, 0.36, 0.9, 0.08))               # the cuff's rim round a dark hole


c.paint("sock", sock)
c.paint("wood", wood)
c.paint("tape", lambda a, b, h, w: c.duct(a * 2.0 % 1.0, b, h, w, across="b"))
c.paint("tape_edge", c.tape_edge)
c.paint("end", c.end_grain)
c.paint("toe", toe)
c.paint("inside", inside)
c.save(os.path.join(HERE, sk.TEXTURE), empty=COTTON * 0.8)

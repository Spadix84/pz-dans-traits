"""Paint the bread knife glaive's texture: BreadKnifeGlaive.png, 256x256.

  python make_texture.py

The layout and measurements come from build_glaive.py; the materials from
../texture_common.py.
"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import build_glaive as g  # noqa: E402
import texture_common as tc  # noqa: E402
from texture_common import band, mix  # noqa: E402

c = tc.Canvas(g.SIZE, g.RECTS, seed=1994)
HANDLE = np.array([112, 68, 40]) / 255.0         # the knife's wooden handle, as vanilla's bread knife has
POLE = np.array([156, 104, 62]) / 255.0          # a broom handle: vanilla's is this brown


# The pole: once round it across the strip, the butt at the top
def pole(a, b, h, w):
    y = g.POLE_Y0 + b * (g.POLE_Y1 - g.POLE_Y0)
    col = POLE * (1.0 + 0.08 * c.grain(h, w, "v") + 0.04 * c.smooth(h, w, 40, 4))[..., None]
    # old varnish, worn through in patches
    col = mix(col, POLE * np.array([1.12, 1.04, 0.86]), 0.45 * (c.smooth(h, w, 26, 5) > 0.15))
    # hands: a darker, greyer stretch where it is held
    grip = band(y, g.GRIP_Y0, g.GRIP_Y1, 0.03)
    col = mix(col, POLE * 0.70, 0.6 * grip * (0.7 + 0.3 * c.smooth(h, w, 30, 5)))
    # the broom end: the thread and a ring of old glue where the head came off
    col = mix(col, POLE * 0.72, band(y, g.POLE_Y1 - 0.030, g.POLE_Y1 + 0.01) * (((y * 420.0) % 1.0) < 0.45))
    # each of the six faces shades off towards its corners
    face = (a * g.POLE_N) % 1.0
    return col * (1.0 - 0.10 * np.abs(2.0 * face - 1.0) ** 2)[..., None]


# The blade: handle end left, the spine along the top, the serrated edge along the bottom
def blade(a, b, h, w):
    y = g.BL_Y[0] + a * (g.BL_Y[-1] - g.BL_Y[0])
    z = g.BL_ZTOP - b * g.BL_DEPTH
    col = c.steel(a, b, h, w)
    col = col * (0.92 + 0.12 * np.clip(b, 0, 1))[..., None]
    col = mix(col, tc.RUST, 0.30 * np.exp(-((a - 0.03) / 0.10) ** 2) * (0.5 + 0.5 * c.smooth(h, w, 6, 30)))
    col = mix(col, tc.STEEL_DARK, 0.45 * (c.smooth(h, w, 20, 90) > 0.80))
    # the grind, scalloped: a bread knife's teeth
    zedge = np.interp(y, g.BL_Y, g.BL_ZE)
    tooth = np.abs(((y * 1000.0 / 7.0) % 1.0) - 0.5) * 2.0          # 0 at a point, 1 mid scallop
    grind = zedge + g.BL_BEVEL * (0.55 + 0.45 * tooth)
    col = np.where((z < grind)[..., None], tc.STEEL_BRIGHT * (0.92 + 0.10 * tooth)[..., None], col)
    col = mix(col, tc.STEEL_DARK, band(z, grind - 0.0004, grind + 0.0011, 0.0004))
    col = mix(col, np.array([1.0, 1.0, 1.0]), 0.6 * band(z, zedge - 0.004, zedge + 0.0016, 0.0008))
    # a maker's mark near the handle
    col = mix(col, tc.STEEL_DARK * 0.9, band(a, 0.10, 0.22) * band(b, 0.16, 0.24) * (((a * 60.0) % 1.0) < 0.6))
    return col


def steel_end(a, b, h, w):
    return tc.STEEL_DARK * (1.1 + 0.08 * c.grain(h, w, "v"))[..., None]


# The knife's handle: butt on the left, the side against the pole up
def handle(a, b, h, w):
    col = HANDLE * (1.0 + 0.16 * c.grain(h, w, "u", fine=1.3, coarse=26.0))[..., None]
    col = col * (1.14 - 0.34 * np.clip(b, 0, 1))[..., None]                 # lit from the top
    aspect = (g.KH_Y1 - g.KH_Y0) / g.KH_H
    for cx in g.KH_RIVETS:
        r = np.sqrt(((a - cx) * aspect) ** 2 + (b - 0.5) ** 2)
        col = mix(col, HANDLE * 0.45, band(r, 0.0, 0.26, 0.03))
        col = mix(col, np.array([0.72, 0.73, 0.72]), band(r, -1.0, 0.19, 0.03))
        col = mix(col, np.array([0.95, 0.95, 0.94]), band(r + (b - 0.5) * 0.25 + (a - cx) * 0.6, -1.0, 0.07, 0.03))
    return col


def handle_under(a, b, h, w):
    col = HANDLE * 0.9 * (1.0 + 0.25 * c.smooth(h, w, 4, 30))[..., None]
    return mix(col, tc.STEEL * 0.8, band(b, 0.38, 0.62, 0.05))              # the tang between the scales


def handle_end(a, b, h, w):
    col = HANDLE * 1.1 * (1.0 + 0.2 * c.smooth(h, w, 6, 6))[..., None]
    return mix(col, tc.STEEL * 0.8, band(a, 0.38, 0.62, 0.05))


c.paint("pole", pole)
c.paint("blade", blade)
c.paint("steel", steel_end)
c.paint("handle", handle)
c.paint("handle_under", handle_under)
c.paint("handle_end", handle_end)
c.paint("tape", c.duct)
c.paint("tape_edge", c.tape_edge)
c.paint("end", lambda a, b, h, w: c.end_grain(a, b, h, w, POLE * 1.15))
c.save(os.path.join(HERE, g.TEXTURE), empty=POLE * 0.9)

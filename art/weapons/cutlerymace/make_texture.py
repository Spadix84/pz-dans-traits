"""Paint the cutlery mace's texture: CutleryMace.png, 256x256.

  python make_texture.py

The layout and measurements come from build_cutlerymace.py; the materials from
../texture_common.py.
"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import build_cutlerymace as cm  # noqa: E402
import texture_common as tc  # noqa: E402
from texture_common import band, mix  # noqa: E402

c = tc.Canvas(cm.SIZE, cm.RECTS, seed=1995)
STAINLESS = np.array([196, 200, 205]) / 255.0


# The club: once round it across the strip, the pommel at the top
def core(a, b, h, w):
    y = cm.CORE_Y0 + b * (cm.CORE_Y1 - cm.CORE_Y0)
    col = tc.WOOD * (1.0 + 0.08 * c.grain(h, w, "v") + 0.04 * c.smooth(h, w, 40, 4))[..., None]
    # hands: darker where it is held
    grip = band(y, cm.GRIP_Y0, cm.GRIP_Y1, 0.025)
    col = mix(col, tc.WOOD * 0.62, 0.65 * grip * (0.7 + 0.3 * c.smooth(h, w, 30, 5)))
    # turned grooves: two at the pommel, one where the head begins
    for gy in (-0.022, -0.012, 0.158):
        col = mix(col, tc.WOOD * 0.45, band(y, gy - 0.0022, gy + 0.0022, 0.0012))
    # the head: knocks, and dark between the stems where the tape's glue has spread
    head = band(y, 0.172, 0.36, 0.01)
    col = mix(col, tc.WOOD * 0.70, 0.5 * head * (c.smooth(h, w, 50, 8) > 0.25))
    # each of the six faces shades off towards its corners
    face = (a * cm.N) % 1.0
    return col * (1.0 - 0.12 * np.abs(2.0 * face - 1.0) ** 2)[..., None]


def stainless(a, b, h, w):
    col = STAINLESS * (1.0 + 0.05 * c.grain(h, w, "v", fine=1.0, coarse=40.0))[..., None]
    shine = np.exp(-((a - 0.38) / 0.10) ** 2)                        # a long highlight down the piece
    col = mix(col, np.array([1.0, 1.0, 1.0]), 0.55 * shine)
    return mix(col, tc.STEEL_DARK, 0.35 * (c.smooth(h, w, 70, 8) > 0.72))    # tarnish


# One fork: the stem's end at the top, the tines at the bottom
def fork(a, b, h, w):
    s = b * cm.FORK_LEN - cm.STEM                                    # along the bent part
    col = stainless(a, b, h, w)
    # a pressed pattern on the stem's end, a dark rim round the palm
    col = mix(col, tc.STEEL_DARK, 0.55 * band(b, 0.03, 0.20) * band(np.abs(a - 0.5), 0.04, 0.075))
    col = mix(col, tc.STEEL_DARK, 0.5 * band(s, cm.FORK_NECK - 0.004, cm.FORK_NECK + 0.001, 0.002))
    # the tines darken towards their roots, where food and rust sit
    col = mix(col, tc.RUST, 0.35 * band(s, cm.FORK_PALM - 0.006, cm.FORK_PALM + 0.012, 0.006))
    return col


# One butter knife: the stem's end at the top, the tip at the bottom
def knife(a, b, h, w):
    s = b * cm.KNIFE_LEN - cm.STEM
    col = stainless(a, b, h, w)
    col = mix(col, tc.STEEL_DARK, 0.55 * band(b, 0.03, 0.20) * band(np.abs(a - 0.5), 0.05, 0.10))
    blade = (s > 0.010).astype(np.float32)
    col = mix(col, tc.STEEL_BRIGHT, 0.8 * blade * band(a, 0.74, 1.2, 0.05))            # the edge side
    col = mix(col, tc.STEEL_DARK, 0.6 * blade * band(a, 0.69, 0.75, 0.02))
    return mix(col, tc.RUST, 0.30 * band(s, 0.0, 0.02, 0.008))


c.paint("core", core)
c.paint("fork", fork)
c.paint("knife", knife)
c.paint("tape", lambda a, b, h, w: c.duct(a * 2.0 % 1.0, b, h, w, across="b"))
c.paint("tape_edge", c.tape_edge)
c.paint("end", c.end_grain)
c.save(os.path.join(HERE, cm.TEXTURE))

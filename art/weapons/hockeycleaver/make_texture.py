"""Paint the hockey stick cleaver's texture: HockeyStickCleaver.png, 256x256.

  python make_texture.py

Ordinary Python (numpy and Pillow). The layout and the model's measurements come from
build_hockeycleaver.py, so paint and geometry cannot drift apart: the grip tape ends
where the script says, the grind's highlight follows the edge the mesh has.

Everything is painted four times too big and scaled down, which gives the soft,
hand-painted look vanilla's small weapon textures have. Each part is painted a pixel
past its rectangle so nothing dark creeps in at its edges.
"""
import os

import numpy as np
from PIL import Image

import build_hockeycleaver as hc

SS = 4                      # paint at this many times the final size
N = hc.SIZE * SS
rng = np.random.default_rng(1993)
img = np.zeros((N, N, 3), np.float32)

WOOD = np.array([208, 164, 102]) / 255.0
WOOD_BLADE = np.array([214, 174, 116]) / 255.0
RED = np.array([168, 30, 36]) / 255.0
WHITE = np.array([232, 230, 222]) / 255.0
BLACK_TAPE = np.array([30, 30, 34]) / 255.0
STEEL = np.array([170, 174, 181]) / 255.0
STEEL_BRIGHT = np.array([226, 229, 233]) / 255.0
STEEL_DARK = np.array([112, 116, 124]) / 255.0
WALNUT = np.array([90, 57, 36]) / 255.0
DUCT = np.array([158, 161, 166]) / 255.0
WIRE = np.array([66, 68, 73]) / 255.0
RUST = np.array([122, 82, 54]) / 255.0


def smooth(h, w, cells_y, cells_x):
    """Soft noise, about -1..1: random cells stretched to h x w."""
    small = rng.normal(0.0, 1.0, (max(2, cells_y), max(2, cells_x))).astype(np.float32)
    lo, hi = small.min(), small.max()
    im = Image.fromarray(((small - lo) / (hi - lo) * 255).astype(np.uint8))
    big = np.asarray(im.resize((w, h), Image.BICUBIC), np.float32) / 255.0
    return big * 2.0 - 1.0


def grain(h, w, along, fine=1.6, coarse=18.0):
    """Wood grain or brushed metal: streaks running `along` "v" (down) or "u" (across)."""
    if along == "v":
        return smooth(h, w, int(h / (coarse * SS)) + 2, int(w / (fine * SS)) + 2)
    return smooth(h, w, int(h / (fine * SS)) + 2, int(w / (coarse * SS)) + 2)


def paint(name, fn):
    """Call fn(a, b, h, w) for a part: a runs 0..1 across its rectangle and b down it
    (a little past both ends, for the bleed); it returns the colours."""
    x0, y0, x1, y1 = hc.RECTS[name]
    px0, py0 = max(0, x0 * SS - SS), max(0, y0 * SS - SS)
    px1, py1 = min(N, x1 * SS + SS), min(N, y1 * SS + SS)
    xs = (np.arange(px0, px1) + 0.5 - x0 * SS) / ((x1 - x0) * SS)
    ys = (np.arange(py0, py1) + 0.5 - y0 * SS) / ((y1 - y0) * SS)
    a, b = np.meshgrid(xs, ys)
    img[py0:py1, px0:px1] = np.clip(fn(a, b, py1 - py0, px1 - px0), 0.0, 1.0)


def mix(base, colour, mask):
    m = np.clip(mask, 0.0, 1.0)[..., None]
    return base * (1.0 - m) + np.asarray(colour) * m


def band(x, lo, hi, soft=0.0):
    """1 between lo and hi, with soft shoulders."""
    if soft <= 0:
        return ((x >= lo) & (x < hi)).astype(np.float32)
    return np.clip((x - lo) / soft, 0, 1) * np.clip((hi - x) / soft, 0, 1)


# The shaft: down the strip is along the stick, knob end at the top -------------------------
def shaft(a, b, h, w):
    y = hc.STRIP_Y0 + b * (hc.STRIP_Y1 - hc.STRIP_Y0)
    col = WOOD * (1.0 + 0.09 * grain(h, w, "v") + 0.04 * smooth(h, w, 40, 3))[..., None]
    # wear and dirt towards the heel
    col = col * (1.0 - 0.16 * np.clip((y - 0.47) / 0.13, 0, 1) * (0.6 + 0.4 * smooth(h, w, 30, 4)))[..., None]
    # the red band: pinstripes at both ends and a column of white blocks for lettering
    red = RED * (1.0 + 0.05 * smooth(h, w, 60, 4))[..., None]
    col = np.where(band(y, hc.BAND_Y0, hc.BAND_Y1)[..., None] > 0, red, col)
    for lo in (hc.BAND_Y0 + 0.006, hc.BAND_Y1 - 0.012):
        col = mix(col, WHITE, band(y, lo, lo + 0.006))
    for lo in (0.186, 0.207, 0.228, 0.249, 0.270):
        col = mix(col, WHITE, band(y, lo, lo + 0.013) * band(a, 0.24, 0.76))
    # chips in the paint
    col = mix(col, WOOD * 0.92, band(y, hc.BAND_Y0, hc.BAND_Y1) * (smooth(h, w, 90, 9) > 0.62))
    # the taped grip: black cloth tape wound on a slant
    turn = (y * 1000.0 / 9.0 + a * 0.9) % 1.0
    tape = BLACK_TAPE * (1.0 + 0.25 * smooth(h, w, 80, 6))[..., None]
    tape = mix(tape, BLACK_TAPE * 2.1, band(turn, 0.0, 0.14))
    col = np.where((y < hc.GRIP_TAPE_Y + 0.004 * (a - 0.5))[..., None], tape, col)
    # the long edges are in shade: the shaft's corners are rounded
    return col * (1.0 - 0.22 * np.abs(2.0 * a - 1.0) ** 2.5)[..., None]


paint("shaft_wide", shaft)
paint("shaft_narrow", shaft)


# The stick's blade: heel on the left, toe on the right, top edge up -------------------------
def hockey_blade(a, b, h, w):
    col = WOOD_BLADE * (1.0 + 0.08 * grain(h, w, "u") + 0.03 * smooth(h, w, 5, 30))[..., None]
    # the bottom edge is scuffed grey from the ground
    col = mix(col, WOOD_BLADE * 0.62, np.clip((b - 0.80) / 0.2, 0, 1) * (0.5 + 0.5 * smooth(h, w, 6, 40)))
    # black tape, turn by turn, worn pale along the bottom
    seam = (a * 21.0 + b * 0.35) % 1.0
    tape = BLACK_TAPE * (1.0 + 0.3 * smooth(h, w, 10, 60))[..., None]
    tape = mix(tape, BLACK_TAPE * 2.0, band(seam, 0.0, 0.11))
    tape = mix(tape, np.array([0.42, 0.42, 0.44]), np.clip((b - 0.74) / 0.26, 0, 1) * (smooth(h, w, 8, 50) > -0.2) * 0.8)
    col = np.where((a > hc.HB_TAPE_T + 0.03 * (b - 0.5))[..., None], tape, col)
    return col * (1.0 - 0.16 * np.abs(2.0 * b - 1.0) ** 3)[..., None]


def hockey_rim(a, b, h, w):
    col = WOOD_BLADE * 0.78 * (1.0 + 0.06 * grain(h, w, "u"))[..., None]
    tape = BLACK_TAPE * (1.35 + 0.3 * smooth(h, w, 3, 60))[..., None]
    return np.where((a > hc.HB_TAPE_T)[..., None], tape, col)


paint("hblade", hockey_blade)
paint("hrim", hockey_rim)


# The cleaver's blade: handle end on the left, spine up, the edge along the bottom -----------
def cleaver_blade(a, b, h, w):
    y = hc.CL_Y[0] + a * (hc.CL_Y[-1] - hc.CL_Y[0])
    z = hc.CL_ZTOP - b * hc.CL_DEPTH
    col = STEEL * (1.0 + 0.055 * grain(h, w, "u", fine=1.2, coarse=30.0))[..., None]
    col = col * (0.90 + 0.14 * np.clip(b, 0, 1))[..., None]                 # darker under the spine
    # age: brown bloom near the handle and along the spine, a few pits
    bloom = np.exp(-(((a - 0.06) / 0.20) ** 2 + ((b - 0.35) / 0.55) ** 2)) + 0.7 * np.exp(-((b - 0.02) / 0.09) ** 2)
    col = mix(col, RUST, 0.42 * bloom * (0.55 + 0.45 * smooth(h, w, 14, 22)))
    col = mix(col, STEEL_DARK, 0.5 * (smooth(h, w, 40, 64) > 0.78))
    # the grind: a bright band up from the edge, a dark line where it starts
    zedge = np.interp(y, hc.CL_Y, hc.CL_ZEDGE)
    grind = zedge + hc.CL_BEVEL
    bright = STEEL_BRIGHT * (1.0 + 0.04 * grain(h, w, "v", fine=1.0, coarse=6.0))[..., None]
    col = np.where((z < grind)[..., None], bright, col)
    col = mix(col, STEEL_DARK, band(z, grind - 0.0006, grind + 0.0016, 0.0006))
    col = mix(col, np.array([1.0, 1.0, 1.0]), 0.6 * band(z, zedge - 0.004, zedge + 0.0022, 0.001))
    # the hanging hole, in the top corner away from the handle
    r = np.sqrt((y - hc.CL_HOLE_Y) ** 2 + (z - hc.CL_HOLE_Z) ** 2)
    col = mix(col, STEEL_BRIGHT, band(r, hc.CL_HOLE_R, hc.CL_HOLE_R + 0.0016, 0.0005))
    col = mix(col, np.array([0.10, 0.10, 0.11]), (r < hc.CL_HOLE_R).astype(np.float32))
    return col


def steel_end(a, b, h, w):
    return STEEL_DARK * (1.1 + 0.08 * grain(h, w, "v"))[..., None]


paint("cblade", cleaver_blade)
paint("steel", steel_end)


# The cleaver's handle: butt on the left, the side against the shaft up ----------------------
def handle(a, b, h, w):
    col = WALNUT * (1.0 + 0.16 * grain(h, w, "u", fine=1.3, coarse=26.0))[..., None]
    col = col * (1.12 - 0.34 * np.clip(b, 0, 1))[..., None]                 # lit from the top
    aspect = (hc.CL_HANDLE_Y1 - hc.CL_HANDLE_Y0) / hc.CL_HANDLE_H
    for cx in hc.CL_RIVETS:
        r = np.sqrt(((a - cx) * aspect) ** 2 + (b - 0.5) ** 2)
        col = mix(col, WALNUT * 0.45, band(r, 0.0, 0.26, 0.03))
        col = mix(col, np.array([0.72, 0.73, 0.72]), band(r, -1.0, 0.19, 0.03))
        col = mix(col, np.array([0.95, 0.95, 0.94]), band(r + (b - 0.5) * 0.25 + (a - cx) * 0.6, -1.0, 0.07, 0.03))
    return col


def handle_under(a, b, h, w):
    col = WALNUT * 0.72 * (1.0 + 0.14 * grain(h, w, "u", fine=1.3, coarse=26.0))[..., None]
    return mix(col, STEEL * 0.8, band(b, 0.36, 0.64, 0.05))                 # the tang between the scales


def handle_end(a, b, h, w):
    col = WALNUT * 0.8 * (1.0 + 0.12 * smooth(h, w, 6, 6))[..., None]
    return mix(col, STEEL * 0.8, band(a, 0.36, 0.64, 0.05))


paint("handle", handle)
paint("handle_under", handle_under)
paint("handle_end", handle_end)


# Bindings and ends ------------------------------------------------------------------------
def duct(a, b, h, w):
    col = DUCT * (1.0 + 0.05 * smooth(h, w, 6, 14) + 0.03 * grain(h, w, "u", fine=0.8, coarse=3.0)
                  + 0.03 * grain(h, w, "v", fine=0.8, coarse=3.0))[..., None]
    crease = np.abs(((a * 3.1 + b * 0.8) % 1.0) - 0.5)
    col = mix(col, DUCT * 1.22, band(crease, 0.0, 0.035, 0.012))             # wrinkles catch the light
    col = mix(col, DUCT * 0.74, band(crease, 0.045, 0.085, 0.012))
    overlap = band(b, 0.47, 0.50)                                            # where one turn laps the last
    col = mix(col, DUCT * 0.70, overlap)
    return col * (1.0 - 0.30 * np.abs(2.0 * b - 1.0) ** 6)[..., None]


def tape_edge(a, b, h, w):
    return DUCT * 0.62 * (1.0 + 0.05 * smooth(h, w, 4, 8))[..., None]


def wire(a, b, h, w):
    turn = (b * 3.0) % 1.0
    col = np.broadcast_to(WIRE * 0.55, (h, w, 3)).copy()
    col = mix(col, WIRE * 1.5, band(turn, 0.12, 0.88, 0.14))
    col = mix(col, np.array([0.70, 0.71, 0.74]), band(turn, 0.34, 0.52, 0.06))
    twist = ((a * 9.0 + b * 1.5) % 1.0) < 0.5
    return col * (1.0 - 0.10 * twist)[..., None]


def knob(a, b, h, w):
    col = WHITE * (0.93 + 0.05 * smooth(h, w, 8, 8))[..., None]
    turn = (b * 4.0 + a * 0.5) % 1.0
    col = mix(col, WHITE * 0.70, band(turn, 0.0, 0.10))
    col = mix(col, np.array([0.55, 0.50, 0.42]), 0.35 * (smooth(h, w, 10, 10) > 0.35))   # grubby
    return col


def end_grain(a, b, h, w):
    r = np.sqrt((a - 0.5) ** 2 + (b - 0.5) ** 2 * 2.2)
    rings = 0.5 + 0.5 * np.sin(r * 34.0)
    return WOOD * 0.80 * (1.0 - 0.14 * rings + 0.05 * smooth(h, w, 6, 6))[..., None]


paint("tape", duct)
paint("tape_edge", tape_edge)
paint("wire", wire)
paint("knob", knob)
paint("end", end_grain)

# What is left empty takes a mid wood colour, so scaled-down copies have no black fringes.
empty = img.sum(axis=2) == 0
img[empty] = WOOD * 0.8

out = Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)).resize((hc.SIZE, hc.SIZE), Image.LANCZOS)
path = os.path.join(os.path.dirname(os.path.abspath(__file__)), hc.TEXTURE)
out.save(path)
print("wrote", path, out.size)

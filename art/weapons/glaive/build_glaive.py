"""Build the bread knife glaive: a bread knife taped along the end of a broom handle,
its blade running on past the end of the pole.

  python make_texture.py
  blender --background --factory-startup --python build_glaive.py -- [--game <the game's media folder>]

Writes BreadKnifeGlaive.X, breadknifeglaive.blend and preview_*.png next to this file.

In the game's weapon space (see ../weapon_common.py): +Y along the pole away from the
hand, the grip at the origin, the knife's edge towards -Z. Sizes from vanilla's broom
(y -0.083 to 0.665) and bread knife (0.33 long, a blade 0.03 deep).

The parts, from the hand out:
  pole    a broom handle, six-sided, 0.025 across
  handle  the knife's, brown wood with three rivets, flat against the pole's -Z face
  tape    two bands of duct tape round pole and handle
  blade   long and narrow, a rounded tip, a serrated edge (painted)

No Blender imports at the top, so make_texture.py can read the layout.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import weapon_common as wc  # noqa: E402

NAME = "BreadKnifeGlaive"
TEXTURE = NAME + ".png"
SIZE = 256

RECTS = {
    "pole":         (0, 0, 40, 256),      # once round the pole across, butt at the top
    "blade":        (44, 0, 244, 44),     # both faces: handle end left, spine up
    "handle":       (44, 48, 164, 72),    # the knife's handle, both sides: butt left, pole side up
    "handle_under": (44, 74, 164, 84),
    "handle_end":   (168, 48, 188, 72),
    "steel":        (192, 48, 204, 72),   # the blade's spine and ends
    "tape":         (44, 88, 108, 120),
    "tape_edge":    (112, 88, 144, 100),
    "end":          (148, 104, 168, 124), # end grain
}

POLE_Y0, POLE_Y1 = -0.090, 0.470
POLE_R, POLE_N = 0.0125, 6
POLE_FLAT = POLE_R * math.cos(math.pi / POLE_N)   # centre to a flat face (two of them face +Z and -Z)
GRIP_Y0, GRIP_Y1 = -0.030, 0.130                  # darkened by hands (painted)

ZTOP = -POLE_FLAT                                 # the knife's handle lies on the pole's -Z face
KH_Y0, KH_Y1 = 0.345, 0.465
KH_HX, KH_H = 0.0075, 0.024
KH_RIVETS = (0.22, 0.50, 0.78)

BL_Y = [0.462, 0.490, 0.590, 0.670, 0.705, 0.722]             # stations along the blade
BL_ZS = [-0.0140, -0.0140, -0.0140, -0.0155, -0.0205, -0.0300]   # the spine at each: down to a rounded tip
BL_ZE = [-0.0390, -0.0460, -0.0470, -0.0460, -0.0430, -0.0360]   # the edge at each
BL_HT = 0.0024                                    # half the blade's thickness
BL_BEVEL = 0.010                                  # the grind, back from the edge
BL_ZTOP, BL_DEPTH = -0.0140, 0.0340               # what the blade's rectangle covers

TAPE_BANDS = [(0.352, 0.378), (0.432, 0.460)]
TAPE_HX = 0.0145
TAPE_Z0, TAPE_Z1 = ZTOP - KH_H - 0.002, POLE_FLAT + 0.002


def pole_b(y):
    return (y - POLE_Y0) / (POLE_Y1 - POLE_Y0)


def build():
    at = wc.Atlas(SIZE)
    m = wc.Mesh()

    # The pole
    ys = [POLE_Y0, POLE_Y1]
    rings = [wc.ring((0, y, 0), (1, 0, 0), (0, 0, 1), POLE_R, POLE_R, POLE_N) for y in ys]
    end = at.mapper(RECTS["end"])
    m.loft(rings, [pole_b(y) for y in ys], at.mapper(RECTS["pole"]), caps=(end, end))

    # The knife's handle (its top lies on the pole and is never seen)
    side = at.mapper(RECTS["handle"], along="u", a_range=(1.0, 0.0))
    m.box(-KH_HX, KH_HX, KH_Y0, KH_Y1, ZTOP - KH_H, ZTOP,
          {"+x": side, "-x": side, "-z": at.mapper(RECTS["handle_under"], along="u"),
           "ends": at.mapper(RECTS["handle_end"])}, skip=("+z",))

    # The blade: flat from the spine to the grind, then in to the edge
    bl, steel = at.mapper(RECTS["blade"]), at.mapper(RECTS["steel"])

    def uv(y, z):
        return bl((y - BL_Y[0]) / (BL_Y[-1] - BL_Y[0]), (BL_ZTOP - z) / BL_DEPTH)

    zg = [min(ze + BL_BEVEL, zs - 0.0006) for zs, ze in zip(BL_ZS, BL_ZE)]
    for i in range(len(BL_Y) - 1):
        y0, y1 = BL_Y[i], BL_Y[i + 1]
        for s in (1, -1):
            x = s * BL_HT
            m.face([(x, y0, BL_ZS[i]), (x, y1, BL_ZS[i + 1]), (x, y1, zg[i + 1]), (x, y0, zg[i])],
                   [uv(y0, BL_ZS[i]), uv(y1, BL_ZS[i + 1]), uv(y1, zg[i + 1]), uv(y0, zg[i])], (s, 0, 0))
            m.face([(x, y0, zg[i]), (x, y1, zg[i + 1]), (0, y1, BL_ZE[i + 1]), (0, y0, BL_ZE[i])],
                   [uv(y0, zg[i]), uv(y1, zg[i + 1]), uv(y1, BL_ZE[i + 1]), uv(y0, BL_ZE[i])], (s, 0, -0.3))
        # the spine
        t0, t1 = i / (len(BL_Y) - 1.0), (i + 1) / (len(BL_Y) - 1.0)
        m.face([(-BL_HT, y0, BL_ZS[i]), (BL_HT, y0, BL_ZS[i]), (BL_HT, y1, BL_ZS[i + 1]), (-BL_HT, y1, BL_ZS[i + 1])],
               [steel(0, t0), steel(1, t0), steel(1, t1), steel(0, t1)], (0, 0, 1))
    for k, out in ((len(BL_Y) - 1, (0, 1, 0)), (0, (0, -1, 0))):
        y = BL_Y[k]
        m.face([(-BL_HT, y, BL_ZS[k]), (BL_HT, y, BL_ZS[k]), (BL_HT, y, zg[k]), (-BL_HT, y, zg[k])],
               [steel(0, 0), steel(1, 0), steel(1, 0.8), steel(0, 0.8)], out)
        m.face([(-BL_HT, y, zg[k]), (BL_HT, y, zg[k]), (0, y, BL_ZE[k])],
               [steel(0, 0.8), steel(1, 0.8), steel(0.5, 1)], out)

    # Duct tape round pole and handle
    tape = {"sides": at.mapper(RECTS["tape"]), "ends": at.mapper(RECTS["tape_edge"])}
    for y0, y1 in TAPE_BANDS:
        m.box(-TAPE_HX, TAPE_HX, y0, y1, TAPE_Z0, TAPE_Z1, tape)
    return m


def main():
    mid, head = (0.0, 0.316, -0.012), (0.0, 0.56, -0.016)
    shots = [
        ("preview_side.png", mid, (1, 0, 0), (0, 0, 1), 0.90, (1800, 420)),
        ("preview_head.png", head, (1, 0, 0), (0, 0, 1), 0.44, (1500, 620)),
        ("preview_head_34.png", head, (0.8, 0.5, -0.45), (0, 0, 1), 0.44, (1500, 900)),
        ("preview_head_34b.png", head, (-0.7, 0.45, 0.55), (0, 0, 1), 0.44, (1500, 900)),
    ]
    compare = ([("2handed", "Broom", (0.0, 0.0, 0.13), 0.0),
                ("2handed", "SpearKnife", (0.0, 0.0, -0.14), 0.0),
                ("1handed", "BreadKnife", (0.0, 0.25, -0.26), 0.0)],
               ("preview_compare.png", (0.0, 0.316, -0.06), (1, 0, 0), (0, 0, 1), 0.95, (1800, 1000)))
    wc.run(NAME, TEXTURE, build(), HERE, shots, compare)


if __name__ == "__main__":
    main()

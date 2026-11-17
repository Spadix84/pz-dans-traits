"""Build the lock in a sock, and the sock flail (the same sock tied over the end of a
small handle). Two models, one texture.

  python make_texture.py
  blender --background --factory-startup --python build_sock.py -- [--game <the game's media folder>]

Writes LockInASock.X, SockFlail.X, their .blend files and preview_*.png next to this file.

In the game's weapon space (see ../weapon_common.py): +Y away from the hand, the grip at
the origin, -Z the way the swing goes.

A weapon model is one stiff shape: the game cannot let the sock hang and swing. So it is
modelled the way it is in the middle of a swing, pulled out straight by the weight, with
a little sag towards -Z so it does not read as a stick:
  cuff    the open end, behind the fist
  leg     twisted thin where it is gripped and all the way to the knot
  knot    tied just above the weight to keep it in the toe
  toe     stretched round the padlock: flat, wider than it is thick
The flail swaps the cuff for a small six-sided handle with the cuff pulled over its end
under a band of duct tape.

No Blender imports at the top, so make_texture.py can read the layout.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import weapon_common as wc  # noqa: E402

NAME, FLAIL = "LockInASock", "SockFlail"
TEXTURE = NAME + ".png"            # both models
SIZE = 256

RECTS = {
    "sock":      (0, 0, 64, 256),       # once round the sock across, the cuff at the top
    "wood":      (68, 0, 100, 140),     # the flail's handle: once round across, the butt at the top
    "tape":      (104, 0, 232, 30),     # the band, once round across
    "tape_edge": (104, 34, 136, 46),
    "end":       (140, 34, 164, 58),    # end grain
    "toe":       (168, 34, 192, 58),    # the toe's seam
    "inside":    (196, 34, 220, 58),    # looking into the cuff
}

N = 8
# The sock, cuff to toe: (y, z, half width across X, half height in the swing's plane, b down the texture)
SOCK = [
    (-0.045, 0.000, 0.0165, 0.0120, 0.00),   # the cuff's open end, a little flattened
    (-0.022, 0.000, 0.0135, 0.0115, 0.06),
    (0.028, 0.000, 0.0100, 0.0100, 0.19),    # in the fist
    (0.100, -0.003, 0.0085, 0.0085, 0.38),
    (0.165, -0.011, 0.0090, 0.0090, 0.55),
    (0.184, -0.015, 0.0135, 0.0135, 0.60),   # the knot
    (0.200, -0.019, 0.0085, 0.0085, 0.64),
    (0.216, -0.024, 0.0170, 0.0220, 0.69),   # the toe opens round the lock
    (0.245, -0.033, 0.0200, 0.0300, 0.78),
    (0.292, -0.049, 0.0200, 0.0300, 0.92),
    (0.316, -0.058, 0.0150, 0.0200, 0.98),
    (0.325, -0.061, 0.0070, 0.0090, 1.00),   # the toe's seam
]
CUFF_STRIPES = [(0.030, 0.050), (0.062, 0.082)]      # in b: a red band and a blue one (painted)
LOCK_B0, LOCK_B1 = 0.70, 0.97                        # where the lock shows through (painted)

# The flail: a small handle, and the same sock from the fist on, further out
HANDLE = [(-0.035, 0.0150), (-0.025, 0.0125), (0.085, 0.0120), (0.105, 0.0125)]
HANDLE_N = 6
FLAIL_SHIFT = 0.085
FLAIL_CUFF = [
    (0.068, 0.000, 0.0160, 0.0160, 0.00),    # the cuff, pulled over the handle's end
    (0.108, 0.000, 0.0155, 0.0155, 0.10),
    (0.128, -0.001, 0.0095, 0.0095, 0.19),   # and drawn in beyond it
]
FLAIL_SAG = 1.25                              # the longer one sags a little more
BAND_Y0, BAND_Y1, BAND_R = 0.076, 0.100, 0.0180


def flail_sock():
    rest = [(y + FLAIL_SHIFT, z * FLAIL_SAG - 0.001, rx, rv, b) for y, z, rx, rv, b in SOCK[3:]]
    return FLAIL_CUFF + rest


def sock_rings(stations):
    """A ring at each station, square to the way the sock runs there."""
    rings = []
    for i, (y, z, rx, rv, _) in enumerate(stations):
        y0, z0 = stations[max(i - 1, 0)][:2]
        y1, z1 = stations[min(i + 1, len(stations) - 1)][:2]
        ty, tz = wc.unit((0.0, y1 - y0, z1 - z0))[1:]
        rings.append(wc.ring((0.0, y, z), (1, 0, 0), (0.0, -tz, ty), rx, rv, N))
    return rings


def add_sock(m, at, stations, open_cuff):
    caps = (at.mapper(RECTS["inside"]) if open_cuff else None, at.mapper(RECTS["toe"]))
    m.loft(sock_rings(stations), [s[4] for s in stations], at.mapper(RECTS["sock"]), caps=caps)


def build():
    at = wc.Atlas(SIZE)
    m = wc.Mesh()
    add_sock(m, at, SOCK, True)
    return m


def build_flail():
    at = wc.Atlas(SIZE)
    m = wc.Mesh()
    X, Z = (1, 0, 0), (0, 0, 1)
    y0, y1 = HANDLE[0][0], HANDLE[-1][0]
    rings = [wc.ring((0, y, 0), X, Z, r, r, HANDLE_N) for y, r in HANDLE]
    end = at.mapper(RECTS["end"])
    m.loft(rings, [(y - y0) / (y1 - y0) for y, _ in HANDLE], at.mapper(RECTS["wood"]), caps=(end, end))
    add_sock(m, at, flail_sock(), False)
    band = [wc.ring((0, y, 0), X, Z, BAND_R, BAND_R, N) for y in (BAND_Y0, BAND_Y1)]
    edge = at.mapper(RECTS["tape_edge"])
    m.loft(band, [0.0, 1.0], at.mapper(RECTS["tape"]), caps=(edge, edge))
    return m


def main():
    mid, toe = (0.0, 0.14, -0.02), (0.0, 0.25, -0.035)
    shots = [
        ("preview_side.png", mid, (1, 0, 0), (0, 0, 1), 0.46, (1800, 700)),
        ("preview_34.png", mid, (0.7, 0.45, 0.5), (0, 0, 1), 0.44, (1500, 1000)),
        ("preview_top.png", mid, (0.05, 0, 1), (-1, 0, 0), 0.46, (1800, 500)),
        ("preview_toe.png", toe, (0.8, 0.4, -0.3), (0, 0, 1), 0.20, (1200, 1000)),
    ]
    compare = ([("1handed", "RollingPin", (0.0, 0.0, 0.10), 0.0),
                ("1handed", "Hammer", (0.0, 0.0, -0.20), 0.0)],
               ("preview_compare.png", (0.0, 0.14, -0.06), (1, 0, 0), (0, 0, 1), 0.50, (1800, 1300)))
    wc.run(NAME, TEXTURE, build(), HERE, shots, compare)
    fmid = (0.0, 0.19, -0.03)
    shots = [
        ("preview_flail_side.png", fmid, (1, 0, 0), (0, 0, 1), 0.56, (1800, 700)),
        ("preview_flail_34.png", fmid, (0.7, 0.45, 0.5), (0, 0, 1), 0.54, (1500, 1000)),
    ]
    wc.run(FLAIL, TEXTURE, build_flail(), HERE, shots)


if __name__ == "__main__":
    main()

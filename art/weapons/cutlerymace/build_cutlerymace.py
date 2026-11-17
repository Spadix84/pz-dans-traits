"""Build the cutlery mace: a wooden handle (or a rolling pin) with three forks and three
butter knives taped round its head, their business ends bent out past the end.

  python make_texture.py
  blender --background --factory-startup --python build_cutlerymace.py -- [--game <the game's media folder>]

Writes CutleryMace.X, cutlerymace.blend and preview_*.png next to this file.

In the game's weapon space (see ../weapon_common.py): +Y away from the hand, the grip at
the origin. It is the same all the way round, so there is no edge side. Sizes from
vanilla's rolling pin (0.32 long, 0.027 radius) and fork (0.19 long).

The parts, from the hand out:
  core     a turned club, six-sided: a pommel, a slim grip, a thicker head
  cutlery  six pieces on the head's six flats, fork and knife by turns: the stems lie
           along the head under the tape, the tines and blades are bent outwards
  tape     two bands of duct tape over the stems

No Blender imports at the top, so make_texture.py can read the layout.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import weapon_common as wc  # noqa: E402

NAME = "CutleryMace"
TEXTURE = NAME + ".png"
SIZE = 256

RECTS = {
    "core":      (0, 0, 40, 256),       # once round the club across, the pommel at the top
    "fork":      (44, 0, 72, 210),      # one fork: the stem's end at the top, the tines at the bottom
    "knife":     (76, 0, 98, 210),      # one butter knife: the stem's end at the top, the tip at the bottom
    "tape":      (102, 0, 230, 34),     # a band, once round across
    "tape_edge": (102, 38, 134, 50),
    "end":       (140, 38, 164, 62),    # end grain
}

N = 6
CORE = [(-0.030, 0.0155), (-0.018, 0.0135), (0.150, 0.0125), (0.172, 0.0205), (0.332, 0.0220), (0.344, 0.0170)]
CORE_Y0, CORE_Y1 = CORE[0][0], CORE[-1][0]
GRIP_Y0, GRIP_Y1 = -0.015, 0.140                # darkened by hands (painted)

PIECES = 6
BASE_Y = 0.170                                  # where the stems start
PLATE_R = 0.0200                                # the stems' distance from the axis (the head's flats are at 0.019)
STEM = 0.128                                    # straight under the tape, then the bend
BEND = math.radians(22.0)
FORK_STEM_W, FORK_W = 0.0070, 0.0170
FORK_NECK, FORK_PALM, FORK_TINE = 0.018, 0.032, 0.074    # along the bent part: neck ends, palm ends, tine tips
TINE_AT, TINE_W0, TINE_W1 = (-0.0066, 0.0, 0.0066), 0.0038, 0.0010
KNIFE_STEM_W, KNIFE_W = 0.0080, 0.0125
KNIFE_FLAT, KNIFE_TIP = 0.066, 0.085            # along the bent part: where the tip's curve starts, the tip
FORK_LEN, KNIFE_LEN = STEM + FORK_TINE, STEM + KNIFE_TIP

TAPE_R = 0.0240
TAPE_BANDS = [(0.180, 0.212), (0.258, 0.292)]


def core_b(y):
    return (y - CORE_Y0) / (CORE_Y1 - CORE_Y0)


def build():
    at = wc.Atlas(SIZE)
    m = wc.Mesh()
    X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)

    # The club
    rings = [wc.ring((0, y, 0), X, Z, r, r, N) for y, r in CORE]
    end = at.mapper(RECTS["end"])
    m.loft(rings, [core_b(y) for y, _ in CORE], at.mapper(RECTS["core"]), caps=(end, end))

    # The cutlery, one piece on each flat
    fork, knife = at.mapper(RECTS["fork"]), at.mapper(RECTS["knife"])
    for k in range(PIECES):
        th = 2.0 * math.pi * (k + 0.5) / PIECES
        r = (math.cos(th), 0.0, math.sin(th))
        t = (-math.sin(th), 0.0, math.cos(th))
        straight = wc.placer(wc.scale(r, PLATE_R), t, Y, r)            # (across, along y, out)
        d = wc.add(wc.scale(Y, math.cos(BEND)), wc.scale(r, math.sin(BEND)))
        n = wc.add(wc.scale(r, math.cos(BEND)), wc.scale(Y, -math.sin(BEND)))
        bent = wc.placer(straight(0.0, BASE_Y + STEM, 0.0), t, d, n)   # (across, along the bend, out)
        is_fork = k % 2 == 0
        uv, width, length = (fork, FORK_W, FORK_LEN) if is_fork else (knife, KNIFE_W, KNIFE_LEN)
        stem_w = FORK_STEM_W if is_fork else KNIFE_STEM_W

        def tx(w, s):
            return uv(0.5 + w / width, s / length)

        # the stem, flat on the head: seen from outside only
        h = stem_w / 2.0
        m.face([straight(-h, BASE_Y, 0), straight(h, BASE_Y, 0), straight(h, BASE_Y + STEM, 0), straight(-h, BASE_Y + STEM, 0)],
               [tx(-h, 0), tx(h, 0), tx(h, STEM), tx(-h, STEM)], r)

        def sheet(points):
            """A piece of the bent part: (across, along) corners."""
            m.plate([bent(w, s, 0.0) for w, s in points], [tx(w, STEM + s) for w, s in points], n)

        if is_fork:
            hw = FORK_W / 2.0
            sheet([(-h, 0.0), (h, 0.0), (hw, FORK_NECK), (-hw, FORK_NECK)])
            sheet([(-hw, FORK_NECK), (hw, FORK_NECK), (hw, FORK_PALM), (-hw, FORK_PALM)])
            for c in TINE_AT:
                sheet([(c - TINE_W0 / 2, FORK_PALM), (c + TINE_W0 / 2, FORK_PALM),
                       (c + TINE_W1 / 2, FORK_TINE), (c - TINE_W1 / 2, FORK_TINE)])
        else:
            hw = KNIFE_W / 2.0
            sheet([(-h, 0.0), (h, 0.0), (hw, 0.012), (-hw, 0.008)])
            sheet([(-hw, 0.008), (hw, 0.012), (hw, KNIFE_FLAT), (-hw, KNIFE_FLAT)])
            sheet([(-hw, KNIFE_FLAT), (hw, KNIFE_FLAT), (hw * 0.55, KNIFE_TIP - 0.004), (-hw * 0.2, KNIFE_TIP)])

    # Duct tape over the stems
    tape, edge = at.mapper(RECTS["tape"]), at.mapper(RECTS["tape_edge"])
    for y0, y1 in TAPE_BANDS:
        rings = [wc.ring((0, y, 0), X, Z, TAPE_R, TAPE_R, N) for y in (y0, y1)]
        m.loft(rings, [0.0, 1.0], tape, caps=(edge, edge))
    return m


def main():
    mid, head = (0.0, 0.17, 0.0), (0.0, 0.29, 0.0)
    shots = [
        ("preview_side.png", mid, (1, 0, 0.25), (0, 0, 1), 0.50, (1800, 620)),
        ("preview_head.png", head, (1, 0, 0.25), (0, 0, 1), 0.26, (1500, 900)),
        ("preview_head_34.png", head, (0.7, 0.6, 0.4), (0, 0, 1), 0.26, (1500, 1100)),
        ("preview_end.png", head, (0.15, 1, 0.1), (0, 0, 1), 0.20, (1100, 1100)),
    ]
    compare = ([("1handed", "RollingPin", (0.0, 0.0, 0.11), 0.0),
                ("1handed", "Nightstick", (0.0, 0.0, -0.10), 0.0),
                ("1handed", "Fork", (0.0, 0.10, -0.19), math.radians(90))],
               ("preview_compare.png", (0.0, 0.17, -0.04), (1, 0, 0), (0, 0, 1), 0.52, (1800, 1300)))
    wc.run(NAME, TEXTURE, build(), HERE, shots, compare)


if __name__ == "__main__":
    main()

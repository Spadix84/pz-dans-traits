"""Build the hockey stick cleaver: an ice hockey stick with a meat cleaver lashed to
its far end, the cleaver's edge one way and the stick's blade the other.

Run with Blender's Python (no window needed), after make_texture.py has painted the
texture:
  python make_texture.py
  blender --background --factory-startup --python build_hockeycleaver.py -- [--game <the game's media folder>]

It writes, next to this file: HockeyStickCleaver.X (the game's model), hockeycleaver.blend
(to look around) and preview_*.png. With --game it also renders preview_compare.png: this
weapon beside vanilla's ice hockey stick, fire axe and meat cleaver, all at the same scale.

The model is in the game's weapon space (see ../weapon_common.py): +Y along the shaft
away from the hand, the grip at the origin, the cleaver's edge towards -Z and the stick's
blade towards +Z, X the thin way. Sizes are taken from vanilla's ice hockey stick (butt
at y -0.093, 0.77 long) and meat cleaver (0.24 long, a blade 0.09 deep).

The parts, from the hand out:
  knob    a wad of white tape at the butt
  shaft   ash, a taped grip, a red band of graphics; 0.022 wide (Z), 0.014 thick (X)
  handle  the cleaver's, dark wood with three rivets, flat against the shaft's back
  tape    two bands of duct tape round shaft and handle
  cleaver its spine against the shaft, the edge out; a bevel to a sharp edge
  wire    three turns round the shaft and through the hole in the cleaver's corner
  blade   the stick's own, taped black from a third of the way to the toe, a slight curve

This file has no Blender imports at the top, so make_texture.py can read the layout.
"""
import argparse
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import weapon_common as wc  # noqa: E402

NAME = "HockeyStickCleaver"
TEXTURE = NAME + ".png"
SIZE = 256                      # the texture, square

# Where each part sits on the texture: (x0, y0, x1, y1) in pixels from the top left.
RECTS = {
    "shaft_wide":   (0, 0, 28, 256),      # the shaft's two wide faces; down the image is along the shaft
    "shaft_narrow": (30, 0, 48, 256),     # its two narrow faces
    "hblade":       (52, 0, 212, 56),     # the stick's blade, both faces: heel on the left, top edge up
    "cblade":       (52, 60, 196, 150),   # the cleaver's blade, both faces: handle end left, spine up
    "steel":        (200, 60, 212, 150),  # the cleaver's end faces
    "handle":       (52, 154, 172, 178),  # the cleaver's handle, both sides: butt left, shaft side up
    "handle_under": (52, 180, 172, 190),  # its underside, the tang showing
    "handle_end":   (176, 154, 196, 178),
    "tape":         (52, 194, 116, 226),  # duct tape, one face of a band
    "wire":         (120, 194, 152, 210),
    "tape_edge":    (120, 214, 152, 226),
    "knob":         (156, 194, 188, 226),
    "end":          (192, 194, 212, 214),  # end grain
    "hrim":         (52, 228, 212, 236),   # the stick blade's thin edges: heel on the left
}

# Shaft
STRIP_Y0, STRIP_Y1 = -0.093, 0.600      # what the shaft strips on the texture cover
SHAFT_Y0, SHAFT_Y1 = -0.072, 0.600
SHAFT_HX, SHAFT_HZ = 0.007, 0.011       # half thickness, half width
KNOB_Y0, KNOB_Y1 = -0.093, -0.070
KNOB_HX, KNOB_HZ = 0.0096, 0.0136
GRIP_TAPE_Y = 0.045                     # the grip is taped from the knob to here (painted)
BAND_Y0, BAND_Y1 = 0.150, 0.310         # the red band of graphics (painted)

# The stick's own blade: from the heel H along D (58 degrees off the shaft, vanilla's lie),
# HB_H tall towards N (the top edge, on the hand's side)
HB_HEEL_Y, HB_HEEL_Z = 0.618, -0.011
HB_ANGLE = math.radians(58.0)
HB_DY, HB_DZ = math.cos(HB_ANGLE), math.sin(HB_ANGLE)
HB_NY, HB_NZ = -math.sin(HB_ANGLE), math.cos(HB_ANGLE)
HB_LEN, HB_H = 0.165, 0.052
HB_HT0, HB_HT1 = 0.0036, 0.0026         # half thickness at the heel and the toe
HB_CURVE = 0.014                        # how far the toe curls towards +X
HB_T = [0.0, 0.2, 0.4, 0.6, 0.8, 0.93, 1.0]
HB_S0 = [0.0, 0.0, 0.0, 0.0, 0.0, 0.08, 0.30]    # the bottom edge (0) and the top (1): rounded at the toe
HB_S1 = [1.0, 1.0, 1.0, 1.0, 1.0, 0.92, 0.70]
HB_TAPE_T = 0.30                        # taped from here to the toe (painted)
HB_BACK_Y, HB_BACK_Z = 0.560, -0.0105   # the heel: the blade's back end runs up inside the shaft to here

# The cleaver: handle then blade along the shaft's back (-Z) face
CL_ZTOP = -SHAFT_HZ                     # spine and handle top lie on the shaft
CL_HANDLE_Y0, CL_HANDLE_Y1 = 0.340, 0.458
CL_HANDLE_HX, CL_HANDLE_H = 0.0065, 0.022
CL_Y = [0.455, 0.470, 0.525, 0.580, 0.598]            # stations along the blade
CL_ZEDGE = [-0.094, -0.098, -0.101, -0.100, -0.097]   # the edge at each: a slight belly
CL_BEVEL = 0.016                        # the grind, back from the edge
CL_HT = 0.0033                          # half the blade's thickness
CL_DEPTH = 0.090                        # what the blade's texture rectangle covers down from the spine
CL_HOLE_Y, CL_HOLE_Z, CL_HOLE_R = 0.577, -0.027, 0.0045

# Bindings
TAPE_BANDS = [(0.346, 0.368), (0.431, 0.455)]   # the three rivets show between them
CL_RIVETS = (0.30, 0.50, 0.70)                  # along the handle, 0 at its butt (painted)
TAPE_HX = 0.0088
TAPE_Z0, TAPE_Z1 = CL_ZTOP - CL_HANDLE_H - 0.0018, SHAFT_HZ + 0.0018
WIRE_Y0, WIRE_Y1 = 0.571, 0.583
WIRE_HX = 0.0082
WIRE_Z1 = SHAFT_HZ + 0.0012
WIRE_BLADE_HX = CL_HT + 0.0014          # where it runs down the blade's faces to the hole
WIRE_Z0 = CL_HOLE_Z - CL_HOLE_R - 0.001


def strip_b(y):
    return (y - STRIP_Y0) / (STRIP_Y1 - STRIP_Y0)


def hockey_blade_point(t, s, side):
    """A point on the stick's blade: t 0..1 heel to toe, s 0..1 bottom edge to top,
    side -1 or +1 for the face."""
    y = HB_HEEL_Y + t * HB_LEN * HB_DY + s * HB_H * HB_NY
    z = HB_HEEL_Z + t * HB_LEN * HB_DZ + s * HB_H * HB_NZ
    x = HB_CURVE * t * t + side * (HB_HT0 + (HB_HT1 - HB_HT0) * t)
    return (x, y, z)


def build():
    at = wc.Atlas(SIZE)
    m = wc.Mesh()

    # Knob and shaft
    m.box(-KNOB_HX, KNOB_HX, KNOB_Y0, KNOB_Y1, -KNOB_HZ, KNOB_HZ, {"all": at.mapper(RECTS["knob"])})
    rng = (strip_b(SHAFT_Y0), strip_b(SHAFT_Y1))
    wide = at.mapper(RECTS["shaft_wide"], b_range=rng)
    narrow = at.mapper(RECTS["shaft_narrow"], b_range=rng)
    m.box(-SHAFT_HX, SHAFT_HX, SHAFT_Y0, SHAFT_Y1, -SHAFT_HZ, SHAFT_HZ,
          {"+x": wide, "-x": wide, "+z": narrow, "-z": narrow, "ends": at.mapper(RECTS["end"])}, skip=("-y",))

    # The stick's blade
    big, rim = at.mapper(RECTS["hblade"]), at.mapper(RECTS["hrim"])

    def station(k, side):
        """Bottom and top corners of the blade at a station, and where they are painted."""
        t = HB_T[k]
        lo, hi = hockey_blade_point(t, HB_S0[k], side), hockey_blade_point(t, HB_S1[k], side)
        uv_lo, uv_hi = big(t, 1 - HB_S0[k]), big(t, 1 - HB_S1[k])
        if k == 0:   # the heel: the back end goes straight up the shaft's back face, out of sight
            hi = (side * HB_HT0, HB_BACK_Y, HB_BACK_Z)
            uv_hi = big(0.0, 1 - (HB_BACK_Y - HB_HEEL_Y) * HB_NY / HB_H)
        return lo, hi, uv_lo, uv_hi

    for i in range(len(HB_T) - 1):
        t0, t1 = HB_T[i], HB_T[i + 1]
        for side in (1, -1):
            lo0, hi0, ulo0, uhi0 = station(i, side)
            lo1, hi1, ulo1, uhi1 = station(i + 1, side)
            m.face([lo0, lo1, hi1, hi0], [ulo0, ulo1, uhi1, uhi0], (side, 0, 0))
        (lo0a, hi0a, _, _), (lo0b, hi0b, _, _) = station(i, -1), station(i, 1)
        (lo1a, hi1a, _, _), (lo1b, hi1b, _, _) = station(i + 1, -1), station(i + 1, 1)
        ruv = [rim(t0, 0), rim(t1, 0), rim(t1, 1), rim(t0, 1)]
        m.face([lo0a, lo1a, lo1b, lo0b], ruv, (0, -HB_NY, -HB_NZ))
        m.face([hi0a, hi1a, hi1b, hi0b], ruv, (0, HB_NY, HB_NZ))
    for k, out in ((len(HB_T) - 1, (0, HB_DY, HB_DZ)), (0, (0, 0, -1))):
        (loa, hia, _, _), (lob, hib, _, _) = station(k, -1), station(k, 1)
        t = HB_T[k]
        m.face([loa, lob, hib, hia], [rim(t, 0), rim(t, 1), rim(t, 1), rim(t, 0)], out)

    # The cleaver's handle (its top lies on the shaft and is never seen)
    side = at.mapper(RECTS["handle"], along="u", a_range=(1.0, 0.0))
    m.box(-CL_HANDLE_HX, CL_HANDLE_HX, CL_HANDLE_Y0, CL_HANDLE_Y1, CL_ZTOP - CL_HANDLE_H, CL_ZTOP,
          {"+x": side, "-x": side, "-z": at.mapper(RECTS["handle_under"], along="u"),
           "ends": at.mapper(RECTS["handle_end"])}, skip=("+z",))

    # The cleaver's blade: flat from the spine to the grind, then in to the edge
    cb, steel = at.mapper(RECTS["cblade"]), at.mapper(RECTS["steel"])

    def uv(y, z):
        return cb((y - CL_Y[0]) / (CL_Y[-1] - CL_Y[0]), (CL_ZTOP - z) / CL_DEPTH)

    zb = [z + CL_BEVEL for z in CL_ZEDGE]
    for i in range(len(CL_Y) - 1):
        y0, y1 = CL_Y[i], CL_Y[i + 1]
        for s in (1, -1):
            x = s * CL_HT
            m.face([(x, y0, CL_ZTOP), (x, y1, CL_ZTOP), (x, y1, zb[i + 1]), (x, y0, zb[i])],
                   [uv(y0, CL_ZTOP), uv(y1, CL_ZTOP), uv(y1, zb[i + 1]), uv(y0, zb[i])], (s, 0, 0))
            m.face([(x, y0, zb[i]), (x, y1, zb[i + 1]), (0, y1, CL_ZEDGE[i + 1]), (0, y0, CL_ZEDGE[i])],
                   [uv(y0, zb[i]), uv(y1, zb[i + 1]), uv(y1, CL_ZEDGE[i + 1]), uv(y0, CL_ZEDGE[i])], (s, 0, -0.3))
    for k, out in ((len(CL_Y) - 1, (0, 1, 0)), (0, (0, -1, 0))):
        y = CL_Y[k]
        m.face([(-CL_HT, y, CL_ZTOP), (CL_HT, y, CL_ZTOP), (CL_HT, y, zb[k]), (-CL_HT, y, zb[k])],
               [steel(0, 0), steel(1, 0), steel(1, 0.8), steel(0, 0.8)], out)
        m.face([(-CL_HT, y, zb[k]), (CL_HT, y, zb[k]), (0, y, CL_ZEDGE[k])],
               [steel(0, 0.8), steel(1, 0.8), steel(0.5, 1)], out)

    # Duct tape round shaft and handle
    tape = {"sides": at.mapper(RECTS["tape"]), "ends": at.mapper(RECTS["tape_edge"])}
    for y0, y1 in TAPE_BANDS:
        m.box(-TAPE_HX, TAPE_HX, y0, y1, TAPE_Z0, TAPE_Z1, tape)

    # Wire: round the shaft, and down both faces of the cleaver to its hole
    wire = {"all": at.mapper(RECTS["wire"])}
    m.box(-WIRE_HX, WIRE_HX, WIRE_Y0, WIRE_Y1, -SHAFT_HZ - 0.0012, WIRE_Z1, wire)
    m.box(-WIRE_BLADE_HX, WIRE_BLADE_HX, WIRE_Y0, WIRE_Y1, WIRE_Z0, -SHAFT_HZ - 0.0012, wire, skip=("+z",))
    return m


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=HERE)
    ap.add_argument("--game", default=None, help="the game's media folder, for the comparison picture")
    ap.add_argument("--samples", type=int, default=48)
    ap.add_argument("--no-render", action="store_true")
    args = ap.parse_args(argv)

    mesh = build()
    x_path = os.path.join(args.out, NAME + ".X")
    nv, nf = wc.write_x(mesh, x_path, NAME, TEXTURE)
    print("wrote %s: %d vertices, %d triangles" % (x_path, nv, nf))
    print("bounds x, y, z:", [(round(a, 4), round(b, 4)) for a, b in mesh.bounds()])
    print("read back:", wc.check_x(x_path))

    import bpy
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    tex_path = os.path.join(args.out, TEXTURE)
    weapon = wc.mesh_to_blender(mesh, NAME, tex_path)
    rig = wc.setup_scene(args.samples)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(args.out, "hockeycleaver.blend"))
    if args.no_render:
        return

    def out(name):
        return os.path.join(args.out, name).replace("\\", "/")

    mid = (0.0, 0.29, 0.015)
    head = (0.0, 0.50, 0.01)
    wc.shot(rig, out("preview_side.png"), mid, (1, 0, 0), (0, 0, 1), 0.86, (1800, 640))
    wc.shot(rig, out("preview_back.png"), mid, (-1, 0, 0), (0, 0, 1), 0.86, (1800, 640))
    wc.shot(rig, out("preview_head.png"), head, (1, 0, 0), (0, 0, 1), 0.40, (1500, 1000))
    wc.shot(rig, out("preview_head_34.png"), head, (0.8, 0.5, -0.45), (0, 0, 1), 0.42, (1500, 1100))
    wc.shot(rig, out("preview_head_34b.png"), head, (-0.7, 0.45, 0.55), (0, 0, 1), 0.42, (1500, 1100))
    wc.shot(rig, out("preview_edge.png"), mid, (0, 0, -1), (1, 0, 0), 0.86, (1800, 420))

    if args.game:
        models = os.path.join(args.game, "models_X", "weapons")
        textures = os.path.join(args.game, "textures", "weapons")
        rows = [("2handed", "IceHockeyStick", (0.0, 0.0, 0.20), math.radians(90)),   # its blade lies along -X: turn it up
                ("2handed", "FireAxe", (0.0, 0.0, -0.24), 0.0),
                ("1handed", "MeatCleaver", (0.0, 0.25, -0.46), 0.0)]
        for folder, name, where, turn in rows:
            obj = wc.x_to_blender(os.path.join(models, folder, name + ".X"),
                                  os.path.join(textures, folder, name + ".png"), "vanilla_" + name)
            obj.location = where
            obj.rotation_euler = (0.0, turn, 0.0)
        wc.shot(rig, out("preview_compare.png"), (0.0, 0.29, -0.085), (1, 0, 0), (0, 0, 1), 0.95, (1800, 1750))


if __name__ == "__main__":
    main()

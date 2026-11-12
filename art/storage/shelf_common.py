"""What Dan's Storage's shelf scripts share: the steel frame, a few shapes, and rendering a
two-tile shelf as Project Zomboid tile sprites.

Each shelf script (build_waterjugrack.py, build_gascanshelf.py, build_propaneshelf.py)
builds its model with these helpers and hands it to run(). The conventions:

- Units are metres. The shelf is two tiles long along local X, its origin where the two
  tiles meet, on the floor: the left half (x < 0) stands on one tile, the right half
  (x > 0) on the other, each tile's centre 0.5 m out. The front points along -Y; the back
  stands near the tile's back edge (y = +0.5).
- Each half is built separately and anything crossing x = 0 is cut there (clipped_box),
  so each tile's sprite holds only what stands on that tile, as vanilla two-tile
  furniture does.
- What it holds is a dict per half of (level, slot) -> the parts of one item; a state
  ("empty", "half", "full") names which (level, slot) pairs show.
- Each tile is rendered alone with the camera, tile geometry and helpers of the window
  air conditioner (../windowac/build_windowac.py): a 128x256 tile, the floor centre at
  (64, 224), 90.5 px per metre. Facings name the way the front points: S towards the
  bottom left of the screen, E the bottom right.
"""
import argparse
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "windowac"))
import build_windowac as wac  # noqa: E402

srgb, material, link = wac.srgb, wac.material, wac.link

FACINGS = {"S": 0.0, "E": 90.0, "N": 180.0, "W": 270.0}
HALVES = ("L", "R")
STATES = ("empty", "half", "full")

END_X = 0.955             # the outer face of the end uprights, from the middle
POST = 0.036              # square tube uprights
BEAM_W, BEAM_H = 0.03, 0.04
SIDE_BAR = 0.024
DECK_T = 0.012
POSTS_X = (-END_X + POST / 2, 0.0, END_X - POST / 2)


def materials():
    return dict(
        steel=material("Galvanised", srgb(168, 172, 174), rough=0.42, metallic=0.55),
        deck=material("DeckSteel", srgb(150, 154, 156), rough=0.5, metallic=0.45),
        dark=material("FeetAndCaps", srgb(44, 45, 47), rough=0.6),
    )


def clipped_box(name, x0, x1, y0, y1, z0, z1, mat, parent, lo, hi, bevel=0.0):
    """A box cut to the half's own x range [lo, hi]; nothing if none of it is there."""
    x0, x1 = max(x0, lo), min(x1, hi)
    if x1 - x0 < 1e-4:
        return None
    return wac.box(name, x0, x1, y0, y1, z0, z1, mat, parent, bevel=bevel, segments=1)


def half_range(half):
    return (-1.0, 0.0) if half == "L" else (0.0, 1.0)


def frame(half, m, hroot, y_front, y_back, levels, decks=()):
    """The steel frame's share on one tile: uprights at the ends and the middle, feet and
    caps, a front and a back beam at each level (the top of each beam at that height), a
    bar across at every upright, and a sheet deck over the levels listed in decks."""
    lo, hi = half_range(half)
    top = max(levels)
    for px in POSTS_X:
        for py, side in ((y_front, "F"), (y_back, "B")):
            tag = f"{half}{px:+.2f}{side}"
            clipped_box("Post" + tag, px - POST / 2, px + POST / 2, py - POST / 2, py + POST / 2,
                        0.008, top, m["steel"], hroot, lo, hi, bevel=0.003)
            clipped_box("Foot" + tag, px - 0.034, px + 0.034, py - 0.034, py + 0.034,
                        0.0, 0.008, m["dark"], hroot, lo, hi)
            clipped_box("Cap" + tag, px - POST / 2 - 0.002, px + POST / 2 + 0.002,
                        py - POST / 2 - 0.002, py + POST / 2 + 0.002, top, top + 0.006, m["dark"], hroot, lo, hi)
    for t, z_top in enumerate(levels):
        for py, side in ((y_front, "F"), (y_back, "B")):
            clipped_box(f"Beam{half}{t}{side}", -END_X, END_X, py - BEAM_W / 2, py + BEAM_W / 2,
                        z_top - BEAM_H, z_top, m["steel"], hroot, lo, hi, bevel=0.002)
        for px in POSTS_X:
            clipped_box(f"Side{half}{t}{px:+.2f}", px - SIDE_BAR / 2, px + SIDE_BAR / 2,
                        y_front + POST / 2, y_back - POST / 2, z_top - BEAM_H + 0.006, z_top - 0.01,
                        m["steel"], hroot, lo, hi)
        if t in decks:
            clipped_box(f"Deck{half}{t}", -END_X + POST, END_X - POST, y_front - BEAM_W / 2, y_back + BEAM_W / 2,
                        z_top - DECK_T, z_top + 0.002, m["deck"], hroot, lo, hi)


def slot_xs(half, count, width):
    """Where count items of the given width stand between a tile's uprights, evenly
    spaced. Slot 0 is the one nearest the middle of the shelf on both tiles, so a part-full
    look fills from the middle outwards."""
    if half == "R":
        inner0, inner1 = POST / 2, END_X - POST
    else:
        inner0, inner1 = -(END_X - POST), -POST / 2
    gap = ((inner1 - inner0) - count * width) / (count + 1)
    xs = []
    for s in range(count):
        offset = gap * (s + 1) + width * s + width / 2
        xs.append(inner0 + offset if half == "R" else inner1 - offset)
    return xs


def _mesh_obj(name, bm, mat, parent, smooth=True):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat)
    obj = link(bpy.data.objects.new(name, mesh), parent)
    if smooth:
        for p in mesh.polygons:
            p.use_smooth = True
    return obj


def along_y(name, radius0, radius1, y0, y1, x, z, mat, parent, segments=32):
    """A cylinder or cone lying along Y from y0 (radius0) to y1 (radius1)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius0, radius2=radius1,
                          depth=abs(y1 - y0))
    obj = _mesh_obj(name, bm, mat, parent)
    # create_cone runs along Z, radius1 at the bottom: turn it so that end lands on y0
    rot = Matrix.Rotation(math.radians(90 if y1 < y0 else -90), 4, "X")
    obj.matrix_local = Matrix.Translation((x, (y0 + y1) / 2, z)) @ rot
    return obj


def upright(name, radius0, radius1, z0, z1, x, y, mat, parent, segments=32):
    """A cylinder or cone standing along Z from z0 (radius0) to z1 (radius1)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius0, radius2=radius1,
                          depth=z1 - z0)
    obj = _mesh_obj(name, bm, mat, parent)
    obj.matrix_local = Matrix.Translation((x, y, (z0 + z1) / 2))
    return obj


def bevel(obj, width, segments=3):
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    return obj


# -- rendering ------------------------------------------------------------------------------

def tile_centre(facing, half):
    """Where a half's tile centre is once the shelf is turned to a facing, about the origin."""
    c = Vector((-0.5 if half == "L" else 0.5, 0.0, 0.0))
    return Matrix.Rotation(math.radians(FACINGS[facing]), 3, "Z") @ c


def grid_pos(facing, half):
    """The game's SpriteGridPos for that half: x then y, 0 at the west or north tile.
    Blender's +Y is the game's north (-y)."""
    c = tile_centre(facing, half)
    if facing in ("S", "N"):
        return (0 if c.x < 0 else 1, 0)
    return (0, 0 if c.y > 0 else 1)


def sheet_order(facing):
    """The two halves in the order the sheet holds them for a facing, as vanilla's own
    two-tile shelves: S and N west tile then east (0,0 1,0); E and W south then north
    (0,1 0,0)."""
    want = [(0, 0), (1, 0)] if facing in ("S", "N") else [(0, 1), (0, 0)]
    by_pos = {grid_pos(facing, h): h for h in HALVES}
    return [by_pos[p] for p in want]


def place(root, facing, half):
    """Turn the shelf to a facing and move it so that half's tile centre is the origin."""
    root.rotation_euler = (0, 0, math.radians(FACINGS[facing]))
    root.location = -tile_centre(facing, half)


def visible_only(halves, items, shown, half, state):
    """Hide the other half entirely, and the items the state doesn't show."""
    for name, hroot in halves.items():
        for obj in hroot.children_recursive:
            if obj.get("item"):
                continue
            obj.hide_render = half is not None and name != half
    for name, half_items in items.items():
        for key, parts in half_items.items():
            for p in parts:
                p.hide_render = (half is not None and name != half) or key not in shown[state]


def mark_item(parts):
    for p in parts:
        p["item"] = True
    return parts


DEPTH_GREY_AT_CENTRE = 188.2   # a floor object's grey at the tile's floor centre (see ../spaceheater)


def render_depth(scene, root, halves, items, shown, facings, states, out, name):
    samples, depth_bits = scene.cycles.samples, scene.render.image_settings.color_depth
    centre = wac.DEPTH_GREY_AT_CENTRE
    wac.DEPTH_GREY_AT_CENTRE = DEPTH_GREY_AT_CENTRE
    scene.cycles.samples = 8
    scene.render.image_settings.color_depth = "16"
    scene.view_settings.view_transform = "Raw"
    scene.view_layers[0].material_override = wac.depth_override()
    wac.DEPTH_GREY_AT_CENTRE = centre
    for state in states:
        for facing in facings:
            for half in HALVES:
                visible_only(halves, items, shown, half, state)
                place(root, facing, half)
                scene.render.filepath = os.path.join(out, f"{name}_{facing}_{half}_{state}_depthraw.png")
                bpy.ops.render.render(write_still=True)
                print("rendered", scene.render.filepath, flush=True)
    scene.view_layers[0].material_override = None
    scene.view_settings.view_transform = "Standard"
    scene.render.image_settings.color_depth = depth_bits
    scene.cycles.samples = samples


def run(name, build, shown):
    """The command line every shelf script has:
      --out <abs dir> [--facings S,E,N,W] [--states empty,half,full] [--scale 8] [--samples 64]
      [--preview] [--depth] [--save-blend <path>]
    build() returns (root, halves, items); shown maps a state to the (level, slot) pairs
    it shows."""
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--facings", default="S,E,N,W")
    ap.add_argument("--states", default=",".join(STATES))
    ap.add_argument("--scale", type=int, default=8)
    ap.add_argument("--samples", type=int, default=64)
    ap.add_argument("--preview", action="store_true", help="render 3/4 views of the whole shelf instead")
    ap.add_argument("--depth", action="store_true", help="also render the depth pass")
    ap.add_argument("--save-blend")
    args = ap.parse_args(argv)
    os.makedirs(args.out, exist_ok=True)
    facings, states = args.facings.split(","), args.states.split(",")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    cam = wac.setup_scene(args.scale, args.samples)
    scene = bpy.context.scene
    root, halves, items = build()

    if args.preview:
        wac.setup_preview(scene, cam, max(args.samples, 96))
        cam.data.lens = 35
        target = Vector((0.0, 0.25, 0.6))
        cam.location = Vector((1.9, -2.6, 1.8))
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        root.location = (0, 0, 0)
        for state in states:
            visible_only(halves, items, shown, None, state)
            scene.render.filepath = os.path.join(args.out, f"preview_{state}.png")
            bpy.ops.render.render(write_still=True)
            print("rendered", scene.render.filepath, flush=True)
    else:
        for state in states:
            for facing in facings:
                for half in HALVES:
                    visible_only(halves, items, shown, half, state)
                    place(root, facing, half)
                    scene.render.filepath = os.path.join(args.out, f"{name}_{facing}_{half}_{state}_raw.png")
                    bpy.ops.render.render(write_still=True)
                    print("rendered", scene.render.filepath, flush=True)
        if args.depth:
            render_depth(scene, root, halves, items, shown, facings, states, args.out, name)
        for facing in facings:
            print("order", facing, " ".join(f"{h}={grid_pos(facing, h)}" for h in sheet_order(facing)), flush=True)

    if args.save_blend:
        visible_only(halves, items, shown, None, "full")
        root.rotation_euler = (0, 0, 0)
        root.location = (0, 0, 0)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(args.save_blend))
        print("saved", args.save_blend, flush=True)

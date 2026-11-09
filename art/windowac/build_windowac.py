"""Build the window air conditioner model and render Project Zomboid tile sprites.

Run with Blender's Python (no GUI needed):
  blender --background --factory-startup --python build_windowac.py -- \
      --out renders --facings S,E,N,W --states off,on --scale 8 --save-blend windowac.blend
  blender --background --factory-startup --python build_windowac.py -- --out renders --preview

Units are metres. The model's front (the indoor grille) points along -Y, and its origin is
where it crosses the wall: x centred in the window, y = 0 in the wall plane, z = 0 at its
underside. About a third of it is indoors (y < 0), the rest sticks out of the window.

Tile geometry was measured from vanilla sprites (walls_exterior_house_01_8,
fixtures_windows_01_0): a 128x256 tile, 2:1 isometric, the floor diamond centred on
(64, 224), one tile edge 1 m, so 90.5 px per metre. Walls stand 2.46 m, the window opening
is about 0.52 m wide and 0.88 m tall, and its sill is 0.97 m above the floor.

Facings name the way the front grille points, so the room is on that side:
  S  window on the tile's north edge, room to the south
  N  window on the north edge, room to the north
  E  window on the tile's west edge, room to the east
  W  window on the west edge, room to the west
"""
import argparse
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

TILE_W, TILE_H = 128, 256
PX_PER_M = 64.0 / math.sqrt(0.5)    # 90.5: a 1 m tile edge is 64 px across
FLOOR_PX = (64.0, 224.0)            # the tile's floor centre in the 128x256 image
ELEVATION = math.radians(30.0)      # the game's 2:1 floor diamond
SILL_Z = 0.97                       # the unit's underside above the floor: the opening's sill
WALL_H = 2.46
OPENING = (0.26, 0.88)              # the window opening's half-width and height
WALL_T = 0.03                       # wall thickness for the holdout
# Front direction -> (rotation about Z, the wall edge it sits in, as a point on the edge)
FACINGS = {
    "S": (0.0, (0.0, 0.5)),
    "N": (180.0, (0.0, 0.5)),
    "E": (90.0, (-0.5, 0.0)),
    "W": (270.0, (-0.5, 0.0)),
}

# Body dimensions
W = 0.42          # cabinet width
H = 0.31          # cabinet height
D_IN = 0.15       # indoor part, wall plane to front face
D_OUT = 0.27      # outdoor part, wall plane to rear face
GAP = 0.25        # half the width the accordion panels fill out to (the window opening)


def srgb(r, g, b):
    def lin(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (lin(r), lin(g), lin(b), 1.0)


def material(name, colour, rough=0.5, metallic=0.0, specular=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = colour
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metallic
    p.inputs["Specular IOR Level"].default_value = specular
    return m


def link(obj, parent):
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    return obj


def box(name, x0, x1, y0, y1, z0, z1, mat, parent, bevel=0.0, segments=2):
    """An axis-aligned box from corner to corner, with optional rounded edges."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((x0 + (v.co.x + 0.5) * (x1 - x0),
                       y0 + (v.co.y + 0.5) * (y1 - y0),
                       z0 + (v.co.z + 0.5) * (z1 - z0)))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat)
    obj = link(bpy.data.objects.new(name, mesh), parent)
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "NONE"
        for p in mesh.polygons:
            p.use_smooth = True
        obj.modifiers.new("Normals", "WEIGHTED_NORMAL")
    return obj


def slab(name, centre, size, rot_x, mat, parent, bevel=0.0):
    """A box of a given size, tilted about its own X axis, then moved to centre."""
    sx, sy, sz = size
    obj = box(name, -sx / 2, sx / 2, -sy / 2, sy / 2, -sz / 2, sz / 2, mat, parent, bevel=bevel)
    obj.matrix_local = Matrix.Translation(centre) @ Matrix.Rotation(math.radians(rot_x), 4, "X")
    return obj


def cylinder(name, x, y0, y1, z, radius, mat, parent, segments=32, bevel=0.0):
    """A short cylinder along Y (from y0 to y1), for knobs and the lamp."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius,
                          depth=abs(y1 - y0))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat)
    obj = link(bpy.data.objects.new(name, mesh), parent)
    obj.matrix_local = (Matrix.Translation((x, (y0 + y1) / 2, z)) @
                        Matrix.Rotation(math.radians(90), 4, "X"))
    for p in mesh.polygons:
        p.use_smooth = True
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
    return obj


def tube(name, points, radius, mat, parent):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 3
    curve.resolution_u = 12
    curve.use_fill_caps = True
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for bp, co in zip(spline.bezier_points, points):
        bp.co = co
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    curve.materials.append(mat)
    return link(bpy.data.objects.new(name, curve), parent)


def accordion(name, x_inner, x_outer, z0, z1, pleats, depth, mat, parent):
    """A pleated side panel filling the window from the cabinet side out to the frame."""
    n = pleats * 2 + 1
    verts = []
    for i in range(n):
        x = x_inner + (x_outer - x_inner) * i / (n - 1)
        y = depth / 2 if i % 2 else -depth / 2
        verts += [(x, y, z0), (x, y, z1)]
    faces = [(2 * i, 2 * i + 2, 2 * i + 3, 2 * i + 1) for i in range(n - 1)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    mesh.materials.append(mat)
    obj = link(bpy.data.objects.new(name, mesh), parent)
    obj.modifiers.new("Thickness", "SOLIDIFY").thickness = 0.003
    return obj


def build():
    root = bpy.data.objects.new("WindowAC", None)
    bpy.context.scene.collection.objects.link(root)

    m = dict(
        cabinet=material("CabinetPaint", srgb(206, 200, 182), rough=0.45, metallic=0.15),
        fascia=material("FasciaPlastic", srgb(232, 228, 214), rough=0.4),
        panel=material("ControlPanel", srgb(186, 182, 170), rough=0.45),
        dark=material("DarkVoid", srgb(28, 30, 32), rough=0.8),
        louver=material("LouverPlastic", srgb(222, 218, 204), rough=0.42),
        coil=material("CondenserCoil", srgb(96, 92, 84), rough=0.5, metallic=0.6),
        steel=material("BracketSteel", srgb(70, 72, 76), rough=0.55, metallic=0.7),
        knob=material("KnobPlastic", srgb(54, 54, 56), rough=0.35),
        white=material("Index", srgb(240, 240, 236), rough=0.5),
        lamp=material("Lamp", srgb(22, 32, 24), rough=0.25),
        cord=material("Cord", srgb(214, 210, 196), rough=0.5),
    )

    # The cabinet: a painted metal sleeve, most of it outdoors.
    box("Cabinet", -W / 2, W / 2, -0.02, D_OUT, 0.0, H, m["cabinet"], root, bevel=0.008)
    # A seam where the sleeve meets the chassis, a third of the way back outdoors.
    box("Seam", -W / 2 - 0.002, W / 2 + 0.002, D_OUT * 0.42, D_OUT * 0.42 + 0.006, 0.004, H - 0.004,
        m["dark"], root)

    # Side louvres on the outdoor part: dark slots with angled blades.
    for sign in (-1, 1):
        x_face = sign * W / 2
        y0, y1 = D_OUT * 0.48, D_OUT - 0.03
        box(f"SideVent{'LR'[sign > 0]}", x_face - 0.003, x_face + 0.003, y0, y1, 0.13, H - 0.03,
            m["dark"], root)
        for i in range(6):
            z = 0.14 + i * 0.024
            blade = slab(f"SideBlade{'LR'[sign > 0]}{i}", (x_face + sign * 0.005, (y0 + y1) / 2, z),
                         (0.004, y1 - y0 - 0.008, 0.02), 0.0, m["cabinet"], root)
            blade.matrix_local = (Matrix.Translation((x_face + sign * 0.004, (y0 + y1) / 2, z)) @
                                  Matrix.Rotation(math.radians(sign * 35), 4, "Y"))

    # Top vents near the back.
    for i in range(5):
        y = D_OUT * 0.55 + i * 0.022
        box(f"TopVent{i}", -W * 0.36, W * 0.36, y, y + 0.009, H - 0.002, H + 0.002, m["dark"], root)

    # The rear: condenser coil behind a guard of horizontal bars.
    box("Coil", -W / 2 + 0.02, W / 2 - 0.02, D_OUT - 0.004, D_OUT + 0.002, 0.02, H - 0.02, m["coil"], root)
    for i in range(12):
        z = 0.03 + i * (H - 0.06) / 11
        box(f"Guard{i}", -W / 2 + 0.015, W / 2 - 0.015, D_OUT + 0.002, D_OUT + 0.008, z - 0.003, z + 0.003,
            m["cabinet"], root, bevel=0.0015, segments=1)

    # The front fascia, indoors: slightly bigger than the sleeve, plastic.
    fy0, fy1 = -D_IN, -0.02
    box("Fascia", -W / 2 - 0.006, W / 2 + 0.006, fy0, fy1, -0.006, H + 0.006, m["fascia"], root,
        bevel=0.012, segments=3)

    # Outlet: the upper left, a dark recess with louvres angled down into the room.
    ox0, ox1, oz0, oz1 = -W / 2 + 0.015, 0.075, H - 0.105, H - 0.018
    box("OutletRecess", ox0, ox1, fy0 - 0.002, fy0 + 0.012, oz0, oz1, m["dark"], root)
    for i in range(5):
        z = oz0 + 0.012 + i * (oz1 - oz0 - 0.02) / 4
        slab(f"OutletLouvre{i}", ((ox0 + ox1) / 2, fy0 + 0.002, z), (ox1 - ox0 - 0.006, 0.02, 0.004),
             -30.0, m["louver"], root)
    # Intake: the lower left, fine vertical slats.
    iz0, iz1 = 0.022, oz0 - 0.016
    box("IntakeRecess", ox0, ox1, fy0 - 0.002, fy0 + 0.01, iz0, iz1, m["dark"], root)
    slats = 15
    for i in range(slats):
        x = ox0 + 0.006 + i * (ox1 - ox0 - 0.012) / (slats - 1)
        box(f"IntakeSlat{i}", x - 0.0035, x + 0.0035, fy0 - 0.004, fy0 + 0.004, iz0, iz1,
            m["louver"], root)

    # Control panel: the right-hand strip with two dials and the power lamp.
    px0, px1 = 0.092, W / 2 - 0.012
    box("ControlPanel", px0, px1, fy0 - 0.004, fy0 + 0.004, 0.022, H - 0.018, m["panel"], root,
        bevel=0.003)
    pcx = (px0 + px1) / 2
    for name, z in (("DialMode", H * 0.62), ("DialTemp", H * 0.30)):
        cylinder(name + "Skirt", pcx, fy0 - 0.004, fy0 - 0.010, z, 0.026, m["knob"], root, bevel=0.002)
        cylinder(name, pcx, fy0 - 0.010, fy0 - 0.026, z, 0.017, m["knob"], root, bevel=0.003)
        box(name + "Tick", pcx - 0.0025, pcx + 0.0025, fy0 - 0.0275, fy0 - 0.025, z + 0.004, z + 0.015,
            m["white"], root)
    # The power display: a small window that glows green while it runs. Big enough to
    # read as a few pixels at game size, where a pinpoint lamp vanished.
    box("DisplayBezel", pcx - 0.036, pcx + 0.036, fy0 - 0.008, fy0 - 0.003, H - 0.06, H - 0.026,
        m["knob"], root, bevel=0.002)
    box("Lamp", pcx - 0.03, pcx + 0.03, fy0 - 0.010, fy0 - 0.007, H - 0.055, H - 0.031, m["lamp"], root)

    # Accordion panels closing the rest of the window opening, in the wall plane.
    for sign in (-1, 1):
        x_in, x_out = sign * W / 2, sign * GAP
        accordion(f"Accordion{'LR'[sign > 0]}", x_in, x_out, 0.0, H, 4, 0.012, m["fascia"], root)
        box(f"AccordionRail{'LR'[sign > 0]}", min(x_in, x_out), max(x_in, x_out), -0.009, 0.009,
            H - 0.012, H, m["fascia"], root)

    # Support bracket under the outdoor part, braced back to the wall.
    for sign in (-1, 1):
        x = sign * (W / 2 - 0.05)
        box(f"BracketArm{'LR'[sign > 0]}", x - 0.009, x + 0.009, 0.0, D_OUT - 0.02, -0.018, 0.0,
            m["steel"], root)
        brace_len = math.hypot(D_OUT - 0.06, 0.17)
        brace = slab(f"BracketBrace{'LR'[sign > 0]}", (x, (D_OUT - 0.06) / 2 + 0.005, -0.09),
                     (0.016, brace_len, 0.016), math.degrees(math.atan2(0.17, D_OUT - 0.06)),
                     m["steel"], root)
    box("BracketFoot", -W / 2 + 0.03, W / 2 - 0.03, 0.002, 0.016, -0.2, -0.17, m["steel"], root)

    # The power cord hangs down the wall from the bottom right, indoors, to the floor.
    tube("Cord", [(W / 2 - 0.03, -0.05, 0.0), (W / 2 + 0.01, -0.04, -0.18),
                  (W / 2 + 0.05, -0.025, -0.55), (W / 2 + 0.06, -0.02, -SILL_Z + 0.05),
                  (W / 2 + 0.12, -0.04, -SILL_Z + 0.006)],
         0.0075, m["cord"], root)

    return root, m


def holdout_wall(root):
    """The wall around the window, invisible but cutting out what is behind it, so the
    sprite shows the outdoor part only where the window opening lets it through. The
    game draws the real wall. Parented to the unit, in its frame: the unit's origin is
    in the wall plane, its underside on the sill."""
    hw, hh = OPENING
    z0, z1 = -SILL_Z, WALL_H - SILL_Z
    mat = material("Holdout", (0, 0, 0, 1))
    parts = [
        box("WallLeft", -0.5, -hw, -WALL_T / 2, WALL_T / 2, z0, z1, mat, root),
        box("WallRight", hw, 0.5, -WALL_T / 2, WALL_T / 2, z0, z1, mat, root),
        box("WallBelow", -hw, hw, -WALL_T / 2, WALL_T / 2, z0, 0.0, mat, root),
        box("WallAbove", -hw, hw, -WALL_T / 2, WALL_T / 2, hh, z1, mat, root),
    ]
    for p in parts:
        p.is_holdout = True
    return parts


def set_state(mats, state):
    """off: the display is dark. on: it glows green."""
    p = mats["lamp"].node_tree.nodes["Principled BSDF"]
    if state == "on":
        p.inputs["Base Color"].default_value = srgb(70, 230, 90)
        p.inputs["Emission Color"].default_value = srgb(40, 255, 70)
        p.inputs["Emission Strength"].default_value = 2.2
    else:
        p.inputs["Base Color"].default_value = srgb(22, 32, 24)
        p.inputs["Emission Strength"].default_value = 0.0


def face(root, facing):
    """Turn the unit to a facing and put it in that window, its underside on the sill."""
    angle, (ex, ey) = FACINGS[facing]
    root.rotation_euler = (0, 0, math.radians(angle))
    root.location = (ex, ey, SILL_Z)


def setup_scene(scale, samples):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = False
    scene.render.film_transparent = True
    scene.render.resolution_x = TILE_W * scale
    scene.render.resolution_y = TILE_H * scale
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"

    world = bpy.data.worlds.new("Ambient")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.82, 0.84, 0.88, 1.0)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.62
    scene.world = world

    # Point the camera so the tile's floor centre lands on FLOOR_PX.
    horiz = Vector((1.0, -1.0, 0.0)).normalized()
    view_from = horiz * math.cos(ELEVATION) + Vector((0, 0, math.sin(ELEVATION)))
    screen_up = (Vector((0, 0, 1)) - view_from * math.sin(ELEVATION)).normalized()
    screen_right = Vector((1.0, 1.0, 0.0)).normalized()
    dx = (TILE_W / 2.0 - FLOOR_PX[0]) / PX_PER_M
    dy = (FLOOR_PX[1] - TILE_H / 2.0) / PX_PER_M
    target = screen_right * dx + screen_up * dy

    cam_data = bpy.data.cameras.new("IsoCamera")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = TILE_H / PX_PER_M
    cam = bpy.data.objects.new("IsoCamera", cam_data)
    scene.collection.objects.link(cam)
    cam.location = target + view_from * 6.0
    cam.rotation_euler = (-view_from).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    # Top light slightly towards the viewer's left, like vanilla shading.
    sun = bpy.data.lights.new("Key", "SUN")
    sun.energy = 2.4
    sun.angle = math.radians(25)
    sun_obj = bpy.data.objects.new("Key", sun)
    scene.collection.objects.link(sun_obj)
    sun_obj.rotation_euler = Vector((-0.45, -0.75, 1.0)).to_track_quat("Z", "Y").to_euler()
    return cam


def setup_preview(scene, cam, samples):
    """A 3/4 perspective close-up for looking at the model itself."""
    scene.render.resolution_x, scene.render.resolution_y = 1400, 1000
    scene.cycles.samples = samples
    cam.data.type = "PERSP"
    cam.data.lens = 50
    target = Vector((0.0, 0.05, 0.12))
    cam.location = Vector((0.85, -1.15, 0.62))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.film_transparent = False


# The depth map, fitted to vanilla DEPTH_fixtures_windows_01.png (both window edges,
# 31,000 pixels, rms 2.7 grey levels): grey = 177.2 + 103.2 * metres away from the
# camera, measured from the tile's floor centre. So depth is absolute in tile
# coordinates, and the unit sorts against the wall and window it sits in.
DEPTH_GREY_AT_CENTRE = 177.2
DEPTH_GREY_PER_M = 103.2


def depth_override():
    """Emission = vanilla depth grey / 255 from the world position, for a Raw 16-bit render."""
    away = Vector((-math.cos(ELEVATION) / math.sqrt(2), math.cos(ELEVATION) / math.sqrt(2),
                   -math.sin(ELEVATION)))
    m = bpy.data.materials.new("DepthOverride")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    dot = nt.nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    dot.inputs[1].default_value = tuple(away * (DEPTH_GREY_PER_M / 255.0))
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "ADD"
    add.inputs[1].default_value = DEPTH_GREY_AT_CENTRE / 255.0
    em = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(geo.outputs["Position"], dot.inputs[0])
    nt.links.new(dot.outputs["Value"], add.inputs[0])
    nt.links.new(add.outputs[0], em.inputs["Color"])
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return m


def render_depth(scene, root, facings, out):
    samples, depth_bits = scene.cycles.samples, scene.render.image_settings.color_depth
    scene.cycles.samples = 8
    scene.render.image_settings.color_depth = "16"
    scene.view_settings.view_transform = "Raw"
    scene.view_layers[0].material_override = depth_override()
    for facing in facings:
        face(root, facing)
        scene.render.filepath = os.path.join(out, f"windowac_{facing}_depthraw.png")
        bpy.ops.render.render(write_still=True)
        print("rendered", scene.render.filepath, flush=True)
    scene.view_layers[0].material_override = None
    scene.view_settings.view_transform = "Standard"
    scene.render.image_settings.color_depth = depth_bits
    scene.cycles.samples = samples


def render_icon(scene, cam, root, mats, out):
    """The inventory icon: a 3/4 front view on a transparent background."""
    setup_preview(scene, cam, 96)
    scene.render.film_transparent = True
    scene.render.resolution_x = scene.render.resolution_y = 512
    cam.data.lens = 70
    root.location = (0, 0, 0)
    root.rotation_euler = (0, 0, 0)
    for obj in root.children:
        if obj.name.startswith(("Cord", "Bracket")):
            obj.hide_render = True
    set_state(mats, "off")
    scene.render.filepath = os.path.join(out, "icon_raw.png")
    bpy.ops.render.render(write_still=True)
    print("rendered", scene.render.filepath, flush=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--facings", default="S,E,N,W")
    ap.add_argument("--states", default="off,on")
    ap.add_argument("--scale", type=int, default=8)
    ap.add_argument("--samples", type=int, default=64)
    ap.add_argument("--preview", action="store_true", help="render 3/4 close-ups instead of sprites")
    ap.add_argument("--depth", action="store_true", help="also render the depth pass for each facing")
    ap.add_argument("--icon", action="store_true", help="render the inventory icon instead of sprites")
    ap.add_argument("--save-blend")
    args = ap.parse_args(argv)
    os.makedirs(args.out, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    cam = setup_scene(args.scale, args.samples)
    scene = bpy.context.scene
    root, mats = build()

    if args.icon:
        render_icon(scene, cam, root, mats, args.out)
    elif args.preview:
        setup_preview(scene, cam, max(args.samples, 96))
        root.location = (0, 0, 0)
        for state in args.states.split(","):
            set_state(mats, state)
            for name, angle in (("front", 0.0), ("back", 180.0)):
                root.rotation_euler = (0, 0, math.radians(angle))
                scene.render.filepath = os.path.join(args.out, f"preview_{name}_{state}.png")
                bpy.ops.render.render(write_still=True)
                print("rendered", scene.render.filepath, flush=True)
    else:
        holdout_wall(root)
        for state in args.states.split(","):
            set_state(mats, state)
            for facing in args.facings.split(","):
                face(root, facing)
                scene.render.filepath = os.path.join(args.out, f"windowac_{facing}_{state}_raw.png")
                bpy.ops.render.render(write_still=True)
                print("rendered", scene.render.filepath, flush=True)
        if args.depth:
            render_depth(scene, root, args.facings.split(","), args.out)

    if args.save_blend:
        root.rotation_euler = (0, 0, 0)
        root.location = (0, 0, 0)
        set_state(mats, "off")
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(args.save_blend))
        print("saved", args.save_blend, flush=True)


if __name__ == "__main__":
    main()

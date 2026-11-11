"""Build the brick smoker model and render Project Zomboid tile sprites.

Run with Blender's Python (no GUI needed), from art/:
  blender --background --factory-startup --python build_smoker.py -- \
      --out renders --facings E,S,W,N --states off,on --scale 4 --depth \
      --save-blend smoker.blend

Units are metres. The model's front (the doors) points along -Y. Unlike the slow
cooker this is a full-size floor object: one metre spans 128 / sqrt(2) px, which is
what makes a floor tile's diamond 128 px wide, and its base sits on the diamond's
centre at (64, 224) in the 128x256 tile.
"""
import argparse
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

TILE_W, TILE_H = 128, 256
PX_PER_M = 128.0 / math.sqrt(2.0)
BASE_PX = (64.0, 224.0)
ELEVATION = math.radians(30.0)  # the game's 2:1 floor diamond
# Camera looks from (+x, -y): -Y is screen down-left (game south), +X down-right (east).
FACINGS = {"S": 0.0, "E": 90.0, "N": 180.0, "W": 270.0}


def srgb(r, g, b, a=1.0):
    def lin(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (lin(r), lin(g), lin(b), a)


def material(name, colour, rough=0.6, metallic=0.0, specular=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = colour
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metallic
    p.inputs["Specular IOR Level"].default_value = specular
    return m


def brick_material(name, brick_a, brick_b, mortar, width=0.21, row=0.068):
    """Brick bond from the face UVs, which are in metres (see box())."""
    m = material(name, brick_a, rough=0.88, specular=0.3)
    nt = m.node_tree
    tex = nt.nodes.new("ShaderNodeTexBrick")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    tex.offset = 0.5
    tex.inputs["Color1"].default_value = brick_a
    tex.inputs["Color2"].default_value = brick_b
    tex.inputs["Mortar"].default_value = mortar
    tex.inputs["Scale"].default_value = 1.0
    tex.inputs["Mortar Size"].default_value = 0.009
    tex.inputs["Bias"].default_value = 0.0
    tex.inputs["Brick Width"].default_value = width
    tex.inputs["Row Height"].default_value = row
    nt.links.new(coord.outputs["UV"], tex.inputs["Vector"])
    nt.links.new(tex.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    return m


def emissive(name, colour):
    m = material(name, colour, rough=0.5)
    return m


def link(obj, parent):
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    return obj


def box(name, lo, hi, mat, parent):
    """Axis-aligned box. UVs are the face's own coordinates in metres, so brick
    courses line up across faces and stay the same size on every part."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector(tuple(lo[i] + (hi[i] - lo[i]) * (v.co[i] + 0.5) for i in range(3)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    uv = bm.loops.layers.uv.new()
    for f in bm.faces:
        n = f.normal
        axis = max(range(3), key=lambda i: abs(n[i]))
        for loop in f.loops:
            c = loop.vert.co
            loop[uv].uv = {0: (c.y, c.z), 1: (c.x, c.z), 2: (c.x, c.y)}[axis]
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat)
    return link(bpy.data.objects.new(name, mesh), parent)


def disc(name, centre, radius, depth, mat, parent, segments=24):
    """A short cylinder on the front face, pointing along -Y."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=depth)
    for v in bm.verts:
        x, y, z = v.co
        v.co = Vector((centre[0] + x, centre[1] - z, centre[2] + y))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat)
    for p in mesh.polygons:
        p.use_smooth = True
    return link(bpy.data.objects.new(name, mesh), parent)


def puff(name, centre, radius, mat, parent):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=radius)
    for v in bm.verts:
        v.co = Vector(v.co) + Vector(centre)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat)
    for p in mesh.polygons:
        p.use_smooth = True
    return link(bpy.data.objects.new(name, mesh), parent)


def build():
    root = bpy.data.objects.new("Smoker", None)
    bpy.context.scene.collection.objects.link(root)

    m = dict(
        brick=brick_material("Brick", srgb(150, 62, 44), srgb(122, 48, 36), srgb(176, 168, 152)),
        stone=material("Capstone", srgb(150, 146, 138), rough=0.92, specular=0.25),
        iron=material("CastIron", srgb(46, 44, 43), rough=0.55, metallic=0.6),
        steel=material("Steel", srgb(120, 122, 124), rough=0.4, metallic=0.85),
        vent=emissive("Vent", srgb(26, 22, 20)),
        dial=material("Dial", srgb(226, 222, 210), rough=0.4),
        smoke=material("Smoke", srgb(196, 196, 194), rough=1.0, specular=0.0),
    )
    m["smoke"].node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.5

    w = 0.40          # half the body's width and depth
    front = -w
    # Plinth, body, a soldier course between the chambers, and the capstone.
    box("Plinth", (-0.44, -0.44, 0.0), (0.44, 0.44, 0.07), m["stone"], root)
    box("Body", (-w, -w, 0.07), (w, w, 1.24), m["brick"], root)
    box("Course", (-w - 0.012, -w - 0.012, 0.47), (w + 0.012, w + 0.012, 0.52), m["brick"], root)
    box("Capstone", (-0.45, -0.45, 1.24), (0.45, 0.45, 1.31), m["stone"], root)

    # Chimney at the back, with a rain cap on four posts.
    box("Chimney", (-0.12, 0.08, 1.31), (0.12, 0.32, 1.92), m["brick"], root)
    box("ChimneyCap", (-0.15, 0.05, 1.98), (0.15, 0.35, 2.005), m["steel"], root)
    for i, (x, y) in enumerate(((-0.12, 0.08), (0.10, 0.08), (-0.12, 0.30), (0.10, 0.30))):
        box(f"CapPost{i}", (x, y, 1.92), (x + 0.02, y + 0.02, 1.98), m["steel"], root)

    # Firebox door, its air vent and handle.
    box("FireDoor", (-0.17, front - 0.02, 0.17), (0.17, front, 0.42), m["iron"], root)
    box("FireVent", (-0.12, front - 0.026, 0.20), (0.12, front - 0.02, 0.235), m["vent"], root)
    box("FireHandle", (0.09, front - 0.045, 0.31), (0.14, front - 0.02, 0.33), m["steel"], root)

    # Smoke chamber door: hinges on the left, latch bar on the right, thermometer.
    box("ChamberDoor", (-0.27, front - 0.02, 0.57), (0.27, front, 1.10), m["iron"], root)
    box("DoorRim", (-0.25, front - 0.026, 1.06), (0.25, front - 0.02, 1.075), m["steel"], root)
    for z in (0.64, 1.00):
        box(f"Hinge{z}", (-0.30, front - 0.03, z), (-0.25, front - 0.015, z + 0.05), m["steel"], root)
    box("LatchBar", (0.10, front - 0.055, 0.82), (0.24, front - 0.038, 0.84), m["steel"], root)
    for x in (0.11, 0.22):
        box(f"LatchPost{x}", (x, front - 0.04, 0.82), (x + 0.015, front - 0.02, 0.84), m["steel"], root)
    disc("Thermometer", (-0.13, front - 0.02, 0.96), 0.045, 0.02, m["steel"], root)
    disc("ThermoFace", (-0.13, front - 0.031, 0.96), 0.036, 0.004, m["dial"], root)

    # Smoke, shown only when lit: drifting up and away on the wind.
    smoke = []
    for i, (dx, dz, r) in enumerate(((0.0, 2.08, 0.07), (-0.04, 2.17, 0.10), (-0.10, 2.27, 0.12),
                                      (-0.17, 2.36, 0.14), (-0.06, 2.22, 0.08))):
        smoke.append(puff(f"Smoke{i}", (dx, 0.20, dz), r, m["smoke"], root))

    # A warm spill of light from the vent.
    glow = bpy.data.lights.new("FireGlow", "POINT")
    glow.color = (1.0, 0.45, 0.15)
    glow.shadow_soft_size = 0.05
    glow_obj = link(bpy.data.objects.new("FireGlow", glow), root)
    glow_obj.location = (0.0, front - 0.12, 0.22)
    return root, m, smoke, glow


def set_state(mats, smoke, glow, state):
    """off: cold. on: glowing vent, a light spilling from it, smoke from the chimney."""
    vent = mats["vent"].node_tree.nodes["Principled BSDF"]
    lit = state == "on"
    vent.inputs["Base Color"].default_value = srgb(255, 150, 50) if lit else srgb(26, 22, 20)
    vent.inputs["Emission Color"].default_value = srgb(255, 120, 30)
    vent.inputs["Emission Strength"].default_value = 18.0 if lit else 0.0
    glow.energy = 6.0 if lit else 0.0
    for obj in smoke:
        obj.hide_render = not lit


def face(root, facing):
    root.rotation_euler = (0, 0, math.radians(FACINGS[facing]))


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

    # Point the camera so the base centre lands on BASE_PX in the tile.
    horiz = Vector((1.0, -1.0, 0.0)).normalized()
    view_from = horiz * math.cos(ELEVATION) + Vector((0, 0, math.sin(ELEVATION)))
    screen_up = (Vector((0, 0, 1)) - view_from * math.sin(ELEVATION)).normalized()
    screen_right = Vector((1.0, 1.0, 0.0)).normalized()
    dx = (TILE_W / 2.0 - BASE_PX[0]) / PX_PER_M
    dy = (BASE_PX[1] - TILE_H / 2.0) / PX_PER_M
    target = screen_right * dx + screen_up * dy

    cam_data = bpy.data.cameras.new("IsoCamera")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = TILE_H / PX_PER_M
    cam = bpy.data.objects.new("IsoCamera", cam_data)
    scene.collection.objects.link(cam)
    cam.location = target + view_from * 8.0
    cam.rotation_euler = (-view_from).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    # Top light slightly towards the viewer's left, like vanilla tile shading.
    sun = bpy.data.lights.new("Key", "SUN")
    sun.energy = 2.4
    sun.angle = math.radians(25)
    sun_obj = bpy.data.objects.new("Key", sun)
    scene.collection.objects.link(sun_obj)
    sun_obj.rotation_euler = Vector((-0.45, -0.75, 1.0)).to_track_quat("Z", "Y").to_euler()
    return view_from


def depth_override(view_from):
    """Emission = distance towards the camera, 0.5 at the base centre, 1 unit per metre."""
    m = bpy.data.materials.new("DepthOverride")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    dot = nt.nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    dot.inputs[1].default_value = tuple(view_from)
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "ADD"
    add.inputs[1].default_value = 0.5
    em = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(geo.outputs["Position"], dot.inputs[0])
    nt.links.new(dot.outputs["Value"], add.inputs[0])
    nt.links.new(add.outputs[0], em.inputs["Color"])
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return m


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--variant", default="brick")
    ap.add_argument("--facings", default="E,S,W,N")
    ap.add_argument("--states", default="off,on")
    ap.add_argument("--scale", type=int, default=4)
    ap.add_argument("--samples", type=int, default=64)
    ap.add_argument("--depth", action="store_true")
    ap.add_argument("--save-blend")
    args = ap.parse_args(argv)
    os.makedirs(args.out, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    view_from = setup_scene(args.scale, args.samples)
    scene = bpy.context.scene
    root, mats, smoke, glow = build()

    for state in args.states.split(","):
        set_state(mats, smoke, glow, state)
        for facing in args.facings.split(","):
            face(root, facing)
            scene.render.filepath = os.path.join(args.out, f"{args.variant}_{facing}_{state}_raw.png")
            bpy.ops.render.render(write_still=True)
            print("rendered", scene.render.filepath, flush=True)

    if args.depth:
        set_state(mats, smoke, glow, "off")
        scene.cycles.samples = 8
        scene.view_settings.view_transform = "Raw"
        scene.view_layers[0].material_override = depth_override(view_from)
        for facing in args.facings.split(","):
            face(root, facing)
            scene.render.filepath = os.path.join(args.out, f"{args.variant}_{facing}_depthraw.png")
            bpy.ops.render.render(write_still=True)
            print("rendered", scene.render.filepath, flush=True)
        scene.view_layers[0].material_override = None
        scene.view_settings.view_transform = "Standard"
        scene.cycles.samples = args.samples

    if args.save_blend:
        face(root, "S")
        set_state(mats, smoke, glow, "off")
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(args.save_blend))
        print("saved", args.save_blend, flush=True)


if __name__ == "__main__":
    main()

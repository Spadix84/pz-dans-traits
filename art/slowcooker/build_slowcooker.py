"""Build the slow cooker model and render Project Zomboid tile sprites.

Run with Blender's Python (no GUI needed):
  blender --background --factory-startup --python build_slowcooker.py -- \
      --out renders --variants harvest --facings S,E,N,W --states off,on \
      --scale 8 --depth --save-blend slowcooker.blend

Units are metres. The model's front (dial) points along -Y. Sprite geometry is
measured from vanilla appliances: a 128x256 tile, 2:1 isometric, with counter-top
items drawn already raised to counter height (the toaster spans y=119-157).
"""
import argparse
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

TILE_W, TILE_H = 128, 256
PX_PER_M = 128.0            # sits between the toaster (34 px) and microwave (69 px) on screen
BASE_PX = (64.0, 153.0)     # where the base centre lands in the 128x256 tile
ELEVATION = math.radians(30.0)  # gives the game's 2:1 floor diamond
# Rotation of the model for each facing. Camera looks from (+x, -y), so -Y is
# screen down-left (game south) and +X is screen down-right (game east).
FACINGS = {"S": 0.0, "E": 90.0, "N": 180.0, "W": 270.0}
# How far the cooker sits back from the tile centre, towards the wall behind a
# counter, so its back lines up with the vanilla microwave's (about 9 px).
BACK_SHIFT_M = 0.10


def face(root, facing):
    """Turn the model to a facing and push it back on the tile. Its front is -Y."""
    angle = math.radians(FACINGS[facing])
    root.rotation_euler = (0, 0, angle)
    root.location = (-math.sin(angle) * BACK_SHIFT_M, math.cos(angle) * BACK_SHIFT_M, 0.0)


def srgb(r, g, b):
    def lin(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (lin(r), lin(g), lin(b), 1.0)


# Dark: clear glass over an empty crock reads dark, with bright reflections on top.
LID_OFF = srgb(82, 100, 106)

COLOURWAYS = {
    "harvest": dict(body=srgb(208, 190, 150), band=srgb(186, 78, 26), metallic=0.0, rough=0.35),
    "avocado": dict(body=srgb(122, 134, 66), band=srgb(226, 214, 184), metallic=0.0, rough=0.35),
    "steel": dict(body=srgb(176, 180, 186), band=srgb(44, 44, 48), metallic=0.75, rough=0.42),
}


def material(name, colour, rough=0.5, metallic=0.0, specular=0.5, emit=None, emit_strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = colour
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metallic
    p.inputs["Specular IOR Level"].default_value = specular
    if emit is not None:
        p.inputs["Emission Color"].default_value = emit
        p.inputs["Emission Strength"].default_value = emit_strength
    return m


def oval(a, b, u, power=2.4):
    """Superellipse point: a slightly squared-off oval, like a real crock."""
    c, s = math.cos(u), math.sin(u)
    return (a * math.copysign(abs(c) ** (2.0 / power), c),
            b * math.copysign(abs(s) ** (2.0 / power), s))


def loft(name, rings, mats, parent, power=2.4, segments=96, cap_bottom=True, cap_top=True):
    """Stack of oval rings: (z, half_length, half_width, material_index for the span above)."""
    verts, faces, face_mats = [], [], []
    for z, a, b, *_ in rings:
        for i in range(segments):
            x, y = oval(a, b, 2.0 * math.pi * i / segments, power)
            verts.append((x, y, z))
    for r in range(len(rings) - 1):
        mi = rings[r][3] if len(rings[r]) > 3 else 0
        for i in range(segments):
            j = (i + 1) % segments
            faces.append((r * segments + i, r * segments + j,
                          (r + 1) * segments + j, (r + 1) * segments + i))
            face_mats.append(mi)
    last = (len(rings) - 1) * segments
    if cap_bottom:
        faces.append(tuple(reversed(range(segments))))
        face_mats.append(rings[0][3] if len(rings[0]) > 3 else 0)
    if cap_top:
        faces.append(tuple(last + i for i in range(segments)))
        face_mats.append(rings[-2][3] if len(rings[-2]) > 3 else 0)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    for m in mats:
        mesh.materials.append(m)
    for poly, mi in zip(mesh.polygons, face_mats):
        poly.material_index = mi
        poly.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    return obj


def disc_on_front(name, x, z, y_back, y_front, radius, mat, parent, bevel=0.0):
    """A short cylinder sticking out of the front face along -Y."""
    r2 = radius - bevel
    depth = y_front - y_back  # negative: towards the viewer side (-Y)
    rings = [(0.0, radius, radius), (depth * 0.8, radius, radius),
             (depth, r2, r2)]
    obj = loft(name, [(abs(z_), a, b) for z_, a, b in rings], [mat], parent,
               power=2.0, segments=32)
    obj.matrix_local = Matrix.Translation((x, y_back, z)) @ Matrix.Rotation(math.radians(90), 4, "X")
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
    obj = bpy.data.objects.new(name, curve)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    return obj


def build(colourway):
    cw = COLOURWAYS[colourway]
    root = bpy.data.objects.new("SlowCooker", None)
    bpy.context.scene.collection.objects.link(root)

    m = dict(
        body=material("Body", cw["body"], rough=cw["rough"], metallic=cw["metallic"]),
        band=material("Band", cw["band"], rough=0.4),
        steel=material("Steel", srgb(190, 194, 198), rough=0.3, metallic=0.9),
        black=material("BlackPlastic", srgb(30, 29, 30), rough=0.38),
        crock=material("Stoneware", srgb(74, 50, 38), rough=0.22),
        glass=material("LidGlass", LID_OFF, rough=0.08, specular=1.0),
        white=material("Index", srgb(235, 235, 230), rough=0.5),
        lamp=material("Lamp", srgb(70, 26, 18), rough=0.25),
    )

    a, b = 0.185, 0.128

    def s(z, k, mi=0):
        return (z, a * k, b * k, mi)

    loft("Foot", [s(0.0, 0.82), s(0.014, 0.84)], [m["black"]], root)
    loft("Housing",
         [s(0.012, 0.90, 0), s(0.017, 0.965, 0), s(0.028, 1.0, 1), s(0.064, 1.0, 0),
          s(0.178, 1.0, 0), s(0.194, 0.985, 0), s(0.200, 0.97, 0)],
         [m["body"], m["band"]], root)
    loft("TrimRing", [s(0.188, 1.008), s(0.200, 1.008), s(0.204, 0.985)], [m["steel"]], root)
    loft("CrockRim", [s(0.200, 0.975), s(0.214, 0.975), s(0.218, 0.94)], [m["crock"]], root)
    loft("LidRim", [s(0.216, 0.965), s(0.221, 0.965), s(0.224, 0.945)], [m["steel"]], root)
    loft("LidGlass",
         [s(0.223, 0.945), s(0.236, 0.86), s(0.250, 0.70), s(0.262, 0.48),
          s(0.269, 0.26), s(0.272, 0.08)],
         [m["glass"]], root, power=2.25)

    knob = lambda z, r: (z, r, r)
    loft("LidKnob",
         [knob(0.270, 0.016), knob(0.280, 0.011), knob(0.284, 0.020), knob(0.296, 0.026),
          knob(0.304, 0.022), knob(0.307, 0.012)],
         [m["black"]], root, power=2.0, segments=32)

    for sign, label in ((1, "R"), (-1, "L")):
        x0 = sign * (a - 0.006)
        tube(f"Handle{label}",
             [(x0, -0.058, 0.176), (x0 + sign * 0.030, -0.046, 0.178),
              (x0 + sign * 0.038, 0.0, 0.179),
              (x0 + sign * 0.030, 0.046, 0.178), (x0, 0.058, 0.176)],
             0.0095, m["black"], root)

    # Control plate on the front, sitting on the curved body.
    plate = loft("ControlPlate",
                 [(0.0, 0.066, 0.040), (0.009, 0.066, 0.040), (0.011, 0.062, 0.036)],
                 [m["steel"]], root, power=3.2, segments=48)
    plate.matrix_local = Matrix.Translation((0.0, -0.121, 0.112)) @ Matrix.Rotation(math.radians(90), 4, "X")

    disc_on_front("DialSkirt", -0.012, 0.112, -0.128, -0.137, 0.029, m["black"], root, bevel=0.002)
    disc_on_front("Dial", -0.012, 0.112, -0.130, -0.152, 0.019, m["black"], root, bevel=0.003)
    tick = loft("DialTick", [(0.0, 0.0035, 0.012), (0.003, 0.0035, 0.012)], [m["white"]], root,
                power=4.0, segments=16)
    tick.matrix_local = Matrix.Translation((-0.012, -0.1495, 0.122)) @ Matrix.Rotation(math.radians(90), 4, "X")
    disc_on_front("Lamp", 0.044, 0.112, -0.128, -0.139, 0.012, m["lamp"], root, bevel=0.002)

    return root, m


def set_state(mats, state):
    """off: clear glass, dark lamp. on: amber lamp, lid fogged with steam (shows from every side)."""
    lamp = mats["lamp"].node_tree.nodes["Principled BSDF"]
    glass = mats["glass"].node_tree.nodes["Principled BSDF"]
    if state == "on":
        lamp.inputs["Base Color"].default_value = srgb(255, 150, 40)
        lamp.inputs["Emission Color"].default_value = srgb(255, 130, 30)
        lamp.inputs["Emission Strength"].default_value = 9.0
        glass.inputs["Base Color"].default_value = srgb(160, 172, 170)
        glass.inputs["Roughness"].default_value = 0.3
    else:
        lamp.inputs["Base Color"].default_value = srgb(70, 26, 18)
        lamp.inputs["Emission Strength"].default_value = 0.0
        glass.inputs["Base Color"].default_value = LID_OFF
        glass.inputs["Roughness"].default_value = 0.08


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

    # Only the area round the object needs rendering.
    scene.render.use_border = True
    scene.render.use_crop_to_border = False
    scene.render.border_min_x, scene.render.border_max_x = 0.1, 0.9
    scene.render.border_min_y, scene.render.border_max_y = 0.3, 0.7

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
    # Offset of the view centre from the base centre, in metres on the image plane.
    dx = (TILE_W / 2.0 - BASE_PX[0]) / PX_PER_M
    dy = (BASE_PX[1] - TILE_H / 2.0) / PX_PER_M
    target = screen_right * dx + screen_up * dy

    cam_data = bpy.data.cameras.new("IsoCamera")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = TILE_H / PX_PER_M
    cam = bpy.data.objects.new("IsoCamera", cam_data)
    scene.collection.objects.link(cam)
    cam.location = target + view_from * 5.0
    cam.rotation_euler = (-view_from).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    # Top light slightly towards the viewer's left, like vanilla appliance shading.
    sun = bpy.data.lights.new("Key", "SUN")
    sun.energy = 2.2
    sun.angle = math.radians(25)
    sun_obj = bpy.data.objects.new("Key", sun)
    scene.collection.objects.link(sun_obj)
    sun_obj.rotation_euler = Vector((-0.45, -0.75, 1.0)).to_track_quat("Z", "Y").to_euler()

    # Two thin strips placed where they mirror off the dome towards the camera:
    # the bright streaks are what make the lid read as glass rather than metal.
    def strip(name, location, size, energy):
        light = bpy.data.lights.new(name, "AREA")
        light.shape = "RECTANGLE"
        light.size, light.size_y = size
        light.energy = energy
        obj = bpy.data.objects.new(name, light)
        scene.collection.objects.link(obj)
        obj.location = location
        aim = Vector(location) - Vector((0.0, 0.0, 0.25))
        obj.rotation_euler = aim.to_track_quat("Z", "Y").to_euler()

    strip("LidGlintMain", (-1.37, 0.59, 0.83), (1.5, 0.10), 34.0)
    strip("LidGlintLow", (0.75, 1.15, 0.72), (1.1, 0.06), 12.0)
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
    ap.add_argument("--variants", default="harvest")
    ap.add_argument("--facings", default="S,E,N,W")
    ap.add_argument("--states", default="off,on")
    ap.add_argument("--scale", type=int, default=8)
    ap.add_argument("--samples", type=int, default=64)
    ap.add_argument("--depth", action="store_true")
    ap.add_argument("--save-blend")
    args = ap.parse_args(argv)
    os.makedirs(args.out, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    view_from = setup_scene(args.scale, args.samples)
    scene = bpy.context.scene

    for variant in args.variants.split(","):
        for obj in [o for o in scene.objects if o.type in {"MESH", "CURVE", "EMPTY"}]:
            bpy.data.objects.remove(obj, do_unlink=True)
        root, mats = build(variant)

        for state in args.states.split(","):
            set_state(mats, state)
            for facing in args.facings.split(","):
                face(root, facing)
                scene.render.filepath = os.path.join(args.out, f"{variant}_{facing}_{state}_raw.png")
                bpy.ops.render.render(write_still=True)
                print("rendered", scene.render.filepath, flush=True)

        if args.depth:
            samples = scene.cycles.samples
            scene.cycles.samples = 8
            scene.view_settings.view_transform = "Raw"
            scene.view_layers[0].material_override = depth_override(view_from)
            for facing in args.facings.split(","):
                face(root, facing)
                scene.render.filepath = os.path.join(args.out, f"{variant}_{facing}_depthraw.png")
                bpy.ops.render.render(write_still=True)
                print("rendered", scene.render.filepath, flush=True)
            scene.view_layers[0].material_override = None
            scene.view_settings.view_transform = "Standard"
            scene.cycles.samples = samples

    if args.save_blend:
        root.rotation_euler = (0, 0, 0)
        root.location = (0, 0, 0)
        set_state(mats, "off")
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(args.save_blend))
        print("saved", args.save_blend, flush=True)


if __name__ == "__main__":
    main()

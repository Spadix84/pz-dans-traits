"""Build the electric space heater model and render Project Zomboid tile sprites.

Run with Blender's Python (no GUI needed):
  blender --background --factory-startup --python build_spaceheater.py -- \
      --out <abs>/renders --depth --save-blend <abs>/spaceheater.blend
  blender --background --factory-startup --python build_spaceheater.py -- --out <abs>/renders --preview

A 1990s radiant heater: a low metal cabinet on two skids, a chrome reflector behind a
wire guard, two quartz elements that glow orange while it runs, a dial and a switch on
top, a carry handle. Units are metres. The front (the elements) points along -Y, and the
origin is the middle of its footprint on the floor.

It stands in the middle of a tile. The camera, the tile geometry and the modelling
helpers are the window air conditioner's (../windowac/build_windowac.py): a 128x256
tile, the floor centre at (64, 224), 90.5 px per metre.

Facings name the way the front points: S is towards the bottom left of the screen, E the
bottom right, so S and E show the elements and N and W the back.
"""
import argparse
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "windowac"))
import build_windowac as wac  # noqa: E402

srgb, material, link, box, slab, tube = wac.srgb, wac.material, wac.link, wac.box, wac.slab, wac.tube

FACINGS = {"S": 0.0, "E": 90.0, "N": 180.0, "W": 270.0}

# Cabinet
HW = 0.27                 # half its width
Y_FRONT, Y_BACK = -0.08, 0.09
Y_WELL = 0.0              # how far back the element well goes: the reflector's plane
Z0, Z1 = 0.035, 0.385     # underside (on the skids) and top
RIM = 0.045               # the frame around the opening
OPEN_X = HW - RIM         # the opening's half-width
OPEN_Z0, OPEN_Z1 = Z0 + RIM, Z1 - RIM
ELEMENT_Z = (0.155, 0.265)


def knob(name, x, y, z0, z1, radius, mat, parent):
    """A short cylinder standing on the top panel."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=radius, radius2=radius * 0.9, depth=z1 - z0)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat)
    obj = link(bpy.data.objects.new(name, mesh), parent)
    obj.matrix_local = Matrix.Translation((x, y, (z0 + z1) / 2))
    for p in mesh.polygons:
        p.use_smooth = True
    return obj


def build():
    root = bpy.data.objects.new("SpaceHeater", None)
    bpy.context.scene.collection.objects.link(root)

    m = dict(
        case=material("CaseEnamel", srgb(126, 88, 54), rough=0.42, metallic=0.2),
        trim=material("TrimBlack", srgb(34, 33, 34), rough=0.5),
        chrome=material("Reflector", srgb(226, 226, 222), rough=0.16, metallic=1.0),
        wire=material("GuardWire", srgb(196, 198, 200), rough=0.3, metallic=0.9),
        element=material("QuartzElement", srgb(196, 190, 178), rough=0.3),
        ceramic=material("Ceramic", srgb(226, 220, 204), rough=0.6),
        knob=material("KnobPlastic", srgb(40, 40, 42), rough=0.35),
        white=material("Index", srgb(240, 240, 236), rough=0.5),
        lamp=material("Lamp", srgb(60, 18, 14), rough=0.25),
        dark=material("DarkVoid", srgb(22, 21, 22), rough=0.85),
        cord=material("Cord", srgb(40, 40, 42), rough=0.5),
    )

    # Two skids it stands on, a little longer than the cabinet is deep.
    for sign in (-1, 1):
        x = sign * (HW - 0.06)
        box(f"Skid{'LR'[sign > 0]}", x - 0.022, x + 0.022, Y_FRONT - 0.05, Y_BACK + 0.05, 0.0, Z0,
            m["trim"], root, bevel=0.008)

    # The cabinet: a closed back half, and a frame around the element well in front.
    box("Back", -HW, HW, Y_WELL, Y_BACK, Z0, Z1, m["case"], root, bevel=0.008)
    box("FrameTop", -HW, HW, Y_FRONT, Y_WELL + 0.01, OPEN_Z1, Z1, m["case"], root, bevel=0.008)
    box("FrameBottom", -HW, HW, Y_FRONT, Y_WELL + 0.01, Z0, OPEN_Z0, m["case"], root, bevel=0.008)
    for sign in (-1, 1):
        x0, x1 = sorted((sign * OPEN_X, sign * HW))
        box(f"Frame{'LR'[sign > 0]}", x0, x1, Y_FRONT, Y_WELL + 0.01, OPEN_Z0 - 0.01, OPEN_Z1 + 0.01,
            m["case"], root, bevel=0.008)
    # A black bezel round the opening.
    b = 0.012
    box("BezelTop", -OPEN_X - b, OPEN_X + b, Y_FRONT - 0.004, Y_FRONT + 0.004, OPEN_Z1, OPEN_Z1 + b, m["trim"], root)
    box("BezelBottom", -OPEN_X - b, OPEN_X + b, Y_FRONT - 0.004, Y_FRONT + 0.004, OPEN_Z0 - b, OPEN_Z0, m["trim"], root)
    for sign in (-1, 1):
        x0, x1 = sorted((sign * OPEN_X, sign * (OPEN_X + b)))
        box(f"Bezel{'LR'[sign > 0]}", x0, x1, Y_FRONT - 0.004, Y_FRONT + 0.004, OPEN_Z0, OPEN_Z1, m["trim"], root)

    # The reflector: a chrome back plate, with slanted plates above and below it.
    box("Reflector", -OPEN_X, OPEN_X, Y_WELL - 0.004, Y_WELL + 0.002, OPEN_Z0, OPEN_Z1, m["chrome"], root)
    depth = Y_WELL - Y_FRONT
    for name, z, tilt in (("ReflectorTop", OPEN_Z1 - 0.02, 28.0), ("ReflectorBottom", OPEN_Z0 + 0.02, -28.0)):
        slab(name, (0.0, Y_WELL - depth * 0.45, z), (OPEN_X * 2, depth * 0.95, 0.003), tilt, m["chrome"], root)

    # Two quartz elements across the well, in ceramic holders.
    y_el = Y_WELL - 0.038
    for i, z in enumerate(ELEMENT_Z):
        tube(f"Element{i}", [(-OPEN_X + 0.012, y_el, z), (OPEN_X - 0.012, y_el, z)], 0.0115, m["element"], root)
        for sign in (-1, 1):
            x0, x1 = sorted((sign * (OPEN_X - 0.016), sign * OPEN_X))
            box(f"Holder{i}{'LR'[sign > 0]}", x0, x1, y_el - 0.018, y_el + 0.018, z - 0.018, z + 0.018,
                m["ceramic"], root, bevel=0.003, segments=1)

    # The guard: upright wires across the opening and three rails.
    y_guard = Y_FRONT + 0.002
    wires = 11
    for i in range(wires):
        x = -OPEN_X + 0.012 + i * (2 * OPEN_X - 0.024) / (wires - 1)
        tube(f"GuardWire{i}", [(x, y_guard, OPEN_Z0), (x, y_guard, OPEN_Z1)], 0.0032, m["wire"], root)
    for i, z in enumerate((OPEN_Z0 + 0.03, (OPEN_Z0 + OPEN_Z1) / 2, OPEN_Z1 - 0.03)):
        tube(f"GuardRail{i}", [(-OPEN_X, y_guard - 0.004, z), (OPEN_X, y_guard - 0.004, z)], 0.0036, m["wire"], root)

    # On top: the thermostat dial, the low/high switch and the pilot lamp, to the right;
    # a carry handle to the left.
    y_top = 0.01
    box("ControlPlate", 0.02, HW - 0.015, y_top - 0.045, y_top + 0.045, Z1 - 0.002, Z1 + 0.004, m["trim"], root,
        bevel=0.003, segments=1)
    knob("Dial", HW - 0.065, y_top, Z1 + 0.004, Z1 + 0.026, 0.03, m["knob"], root)
    box("DialTick", HW - 0.068, HW - 0.062, y_top - 0.028, y_top - 0.008, Z1 + 0.026, Z1 + 0.028, m["white"], root)
    knob("Switch", HW - 0.15, y_top, Z1 + 0.004, Z1 + 0.022, 0.02, m["knob"], root)
    box("SwitchTick", HW - 0.153, HW - 0.147, y_top - 0.018, y_top - 0.004, Z1 + 0.022, Z1 + 0.024, m["white"], root)
    box("Lamp", 0.04, 0.075, y_top - 0.016, y_top + 0.016, Z1 + 0.003, Z1 + 0.013, m["lamp"], root, bevel=0.003,
        segments=1)
    tube("Handle", [(-HW + 0.05, 0.02, Z1 - 0.005), (-HW + 0.06, 0.02, Z1 + 0.05), (-0.05, 0.02, Z1 + 0.05),
                    (-0.04, 0.02, Z1 - 0.005)], 0.0095, m["trim"], root)

    # The back: rows of vent slots and the rating plate.
    for i in range(6):
        z = Z0 + 0.075 + i * 0.042
        box(f"BackVent{i}", -HW + 0.05, HW - 0.05, Y_BACK - 0.002, Y_BACK + 0.002, z, z + 0.016, m["dark"], root)
    box("RatingPlate", HW - 0.14, HW - 0.05, Y_BACK - 0.001, Y_BACK + 0.003, Z0 + 0.02, Z0 + 0.06, m["wire"], root)
    # Side vents near the top, so the ends aren't blank.
    for sign in (-1, 1):
        for i in range(4):
            y = Y_WELL + 0.012 + i * 0.019
            box(f"SideVent{'LR'[sign > 0]}{i}", sign * HW - 0.002, sign * HW + 0.002, y, y + 0.009, Z1 - 0.15, Z1 - 0.04,
                m["dark"], root)

    # The cord leaves the back at the bottom and trails off across the floor.
    tube("Cord", [(-HW + 0.15, Y_BACK, Z0 + 0.03), (-HW + 0.15, Y_BACK + 0.06, 0.012),
                  (-HW + 0.2, Y_BACK + 0.14, 0.008), (-HW + 0.1, Y_BACK + 0.2, 0.008)],
         0.0075, m["cord"], root)

    # The elements' light on the reflector and the guard, while it runs.
    glow = bpy.data.lights.new("Glow", "POINT")
    glow.color = (1.0, 0.3, 0.06)
    glow.shadow_soft_size = 0.05
    glow_obj = bpy.data.objects.new("Glow", glow)
    bpy.context.scene.collection.objects.link(glow_obj)
    glow_obj.parent = root
    glow_obj.location = (0.0, Y_WELL - 0.06, (ELEMENT_Z[0] + ELEMENT_Z[1]) / 2)
    return root, m, glow


def set_state(mats, glow, state):
    """off: grey quartz tubes and a dark lamp. on: the elements and the lamp glow."""
    on = state == "on"
    el = mats["element"].node_tree.nodes["Principled BSDF"]
    el.inputs["Base Color"].default_value = srgb(255, 120, 40) if on else srgb(196, 190, 178)
    el.inputs["Emission Color"].default_value = srgb(255, 96, 24)
    el.inputs["Emission Strength"].default_value = 7.0 if on else 0.0
    lamp = mats["lamp"].node_tree.nodes["Principled BSDF"]
    lamp.inputs["Base Color"].default_value = srgb(255, 90, 50) if on else srgb(60, 18, 14)
    lamp.inputs["Emission Color"].default_value = srgb(255, 60, 30)
    lamp.inputs["Emission Strength"].default_value = 6.0 if on else 0.0
    glow.energy = 1.2 if on else 0.0


def face(root, facing):
    root.rotation_euler = (0, 0, math.radians(FACINGS[facing]))
    root.location = (0, 0, 0)


# The depth map: vanilla's grey rises 103.2 a metre away from the camera (the window air
# conditioner's fit). Vanilla floor appliances (DEPTH_appliances_cooking_01, _laundry_01,
# _misc_01) read 10 to 12 grey farther than that fit where they meet the floor, so a
# floor object's grey at the tile's floor centre is 188, not the wall fit's 177.
DEPTH_GREY_AT_CENTRE = 188.2
DEPTH_GREY_PER_M = wac.DEPTH_GREY_PER_M


def render_depth(scene, root, facings, out):
    samples, depth_bits = scene.cycles.samples, scene.render.image_settings.color_depth
    centre = wac.DEPTH_GREY_AT_CENTRE
    wac.DEPTH_GREY_AT_CENTRE = DEPTH_GREY_AT_CENTRE
    scene.cycles.samples = 8
    scene.render.image_settings.color_depth = "16"
    scene.view_settings.view_transform = "Raw"
    scene.view_layers[0].material_override = wac.depth_override()
    wac.DEPTH_GREY_AT_CENTRE = centre
    for facing in facings:
        face(root, facing)
        scene.render.filepath = os.path.join(out, f"spaceheater_{facing}_depthraw.png")
        bpy.ops.render.render(write_still=True)
        print("rendered", scene.render.filepath, flush=True)
    scene.view_layers[0].material_override = None
    scene.view_settings.view_transform = "Standard"
    scene.render.image_settings.color_depth = depth_bits
    scene.cycles.samples = samples


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
    ap.add_argument("--save-blend")
    args = ap.parse_args(argv)
    os.makedirs(args.out, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    cam = wac.setup_scene(args.scale, args.samples)
    scene = bpy.context.scene
    root, mats, glow = build()

    if args.preview:
        wac.setup_preview(scene, cam, max(args.samples, 96))
        target = (0.0, 0.0, 0.2)
        cam.location = (0.95, -1.3, 0.85)
        from mathutils import Vector
        cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
        for state in args.states.split(","):
            set_state(mats, glow, state)
            for name, angle in (("front", 0.0), ("back", 180.0)):
                root.rotation_euler = (0, 0, math.radians(angle))
                scene.render.filepath = os.path.join(args.out, f"preview_{name}_{state}.png")
                bpy.ops.render.render(write_still=True)
                print("rendered", scene.render.filepath, flush=True)
    else:
        for state in args.states.split(","):
            set_state(mats, glow, state)
            for facing in args.facings.split(","):
                face(root, facing)
                scene.render.filepath = os.path.join(args.out, f"spaceheater_{facing}_{state}_raw.png")
                bpy.ops.render.render(write_still=True)
                print("rendered", scene.render.filepath, flush=True)
        if args.depth:
            set_state(mats, glow, "off")
            render_depth(scene, root, args.facings.split(","), args.out)

    if args.save_blend:
        face(root, "S")
        set_state(mats, glow, "off")
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(args.save_blend))
        print("saved", args.save_blend, flush=True)


if __name__ == "__main__":
    main()

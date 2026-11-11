"""Build the central heating and cooling models and render Project Zomboid tile sprites.

Run with Blender's Python (no GUI needed):
  blender --background --factory-startup --python build_hvac.py -- \
      --out <abs>/renders --depth --save-blend <abs>/hvac.blend
  blender --background --factory-startup --python build_hvac.py -- --out <abs>/renders --preview
  blender --background --factory-startup --python build_hvac.py -- --out <abs>/renders --icon

Three objects, each standing in the middle of a tile, its origin the middle of its
footprint on the floor. Units are metres.

  furnace    an electric upflow furnace: a beige sheet-metal cabinet 0.55 m wide, 0.65 m
             deep and 1.35 m tall, a louvred lower door, a control label and a pilot lamp
             on the upper door, a disconnect box on its right side, a galvanised plenum
             stub on top. Running: the pilot lamp (and the one on the disconnect) is lit.
  condenser  the outdoor half of a central air conditioner: a grey-green box 0.8 m square
             and 0.75 m tall on a concrete pad, louvred all round, a round fan grille on
             top, the refrigerant lines and the electrical whip leaving its front.
             Running: the fan blades are a blurred disc.
  vent       a steel floor register, 0.30 by 0.15 m. Two tiles: A with its long side
             along the tile's north-south axis, B turned a quarter.

The camera, the tile geometry and the modelling helpers are the window air
conditioner's (../windowac/build_windowac.py): a 128x256 tile, the floor centre at
(64, 224), 90.5 px per metre. Facings name the way the front points, as the space
heater's: S is towards the bottom left of the screen, E the bottom right, so S and E
show the front and N and W the back.
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

srgb, material, link, box, slab, tube = wac.srgb, wac.material, wac.link, wac.box, wac.slab, wac.tube

FACINGS = {"S": 0.0, "E": 90.0, "N": 180.0, "W": 270.0}
VENT_TURNS = {"A": 0.0, "B": 90.0}
STATES = ("off", "on")

# Floor objects: see ../spaceheater/build_spaceheater.py for where 188.2 comes from.
DEPTH_GREY_AT_CENTRE = 188.2


# -- helpers ------------------------------------------------------------------------------

def disc(name, x, y, z0, z1, radius, mat, parent, segments=48, radius_top=None):
    """An upright cylinder (or a cone frustum) from z0 to z1."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius,
                          radius2=radius if radius_top is None else radius_top, depth=z1 - z0)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat)
    obj = link(bpy.data.objects.new(name, mesh), parent)
    obj.matrix_local = Matrix.Translation((x, y, (z0 + z1) / 2))
    return obj


def ring(name, radius, z, wire, mat, parent, points=48):
    """A wire hoop lying flat at height z."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = wire
    curve.bevel_resolution = 2
    spline = curve.splines.new("POLY")
    spline.points.add(points - 1)
    for i, p in enumerate(spline.points):
        a = 2 * math.pi * i / points
        p.co = (radius * math.cos(a), radius * math.sin(a), z, 1.0)
    spline.use_cyclic_u = True
    curve.materials.append(mat)
    return link(bpy.data.objects.new(name, curve), parent)


def turned(obj, centre, axis, degrees):
    """Move a box built round the origin to centre, turned about one of its own axes."""
    obj.matrix_local = Matrix.Translation(centre) @ Matrix.Rotation(math.radians(degrees), 4, axis)
    return obj


def centred(name, size, mat, parent, bevel=0.0):
    sx, sy, sz = size
    return box(name, -sx / 2, sx / 2, -sy / 2, sy / 2, -sz / 2, sz / 2, mat, parent, bevel=bevel, segments=1)


def worn(mat, dirt=(84, 74, 60), amount=0.3, scale=5.0):
    """Blotches of grime over a paint colour, so a panel isn't one flat tone."""
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    base = tuple(bsdf.inputs["Base Color"].default_value)
    coord = nt.nodes.new("ShaderNodeTexCoord")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = 5.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.42
    ramp.color_ramp.elements[1].position = 0.78
    ramp.color_ramp.elements[1].color = (amount, amount, amount, 1.0)
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    colours = [s for s in mix.inputs if s.type == "RGBA"]
    colours[0].default_value = base
    colours[1].default_value = srgb(*dirt)
    result = [s for s in mix.outputs if s.type == "RGBA"][0]
    nt.links.new(coord.outputs["Object"], noise.inputs["Vector"])
    nt.links.new(noise.outputs[0], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], mix.inputs[0])
    nt.links.new(result, bsdf.inputs["Base Color"])
    return mat


def lamp_state(mat, on, lit, glow, dark, strength=6.0):
    p = mat.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = srgb(*lit) if on else srgb(*dark)
    p.inputs["Emission Color"].default_value = srgb(*glow)
    p.inputs["Emission Strength"].default_value = strength if on else 0.0


# -- the furnace --------------------------------------------------------------------------

F_HW = 0.275                    # half its width
F_YF, F_YB = -0.325, 0.325      # front and back
F_H = 1.35
F_PLENUM = 0.12                 # the plenum stub's height above the cabinet


def build_furnace():
    root = bpy.data.objects.new("Furnace", None)
    bpy.context.scene.collection.objects.link(root)
    m = dict(
        case=worn(material("FurnaceEnamel", srgb(196, 189, 170), rough=0.5, metallic=0.15)),
        door=worn(material("FurnaceDoor", srgb(210, 204, 187), rough=0.45, metallic=0.15), amount=0.2),
        dark=material("FurnaceVoid", srgb(26, 26, 27), rough=0.85),
        seam=material("FurnaceSeam", srgb(70, 66, 58), rough=0.7),
        galv=worn(material("Galvanised", srgb(176, 180, 182), rough=0.35, metallic=0.85), dirt=(120, 122, 120),
                  amount=0.35, scale=9.0),
        steel=material("BoxSteel", srgb(128, 132, 134), rough=0.5, metallic=0.5),
        label=material("Label", srgb(232, 226, 204), rough=0.6),
        ink=material("LabelInk", srgb(52, 50, 48), rough=0.6),
        badge=material("Badge", srgb(150, 44, 36), rough=0.4),
        black=material("BlackPlastic", srgb(34, 34, 36), rough=0.4),
        lamp=material("PilotLamp", srgb(70, 44, 14), rough=0.25),
        conduit=material("Conduit", srgb(150, 152, 150), rough=0.4, metallic=0.7),
    )
    hw, yf, yb, h = F_HW, F_YF, F_YB, F_H

    # A dark kick strip it stands on, and the cabinet.
    box("Kick", -hw + 0.012, hw - 0.012, yf + 0.02, yb - 0.012, 0.0, 0.05, m["dark"], root)
    box("Cabinet", -hw, hw, yf, yb, 0.04, h, m["case"], root, bevel=0.01)

    # The front: two doors, a little proud of the cabinet, a dark gap between them.
    box("DoorGap", -hw + 0.012, hw - 0.012, yf - 0.004, yf + 0.004, 0.06, h - 0.03, m["dark"], root)
    box("DoorLower", -hw + 0.016, hw - 0.016, yf - 0.014, yf + 0.004, 0.07, 0.70, m["door"], root, bevel=0.006)
    box("DoorUpper", -hw + 0.016, hw - 0.016, yf - 0.014, yf + 0.004, 0.725, h - 0.035, m["door"], root, bevel=0.006)

    # Louvres in the lower door: a dark opening with blades slanting down and out.
    lx, lz0, lz1 = hw - 0.065, 0.14, 0.63
    box("LouvreRecess", -lx, lx, yf - 0.0155, yf - 0.012, lz0, lz1, m["dark"], root)
    blades = 12
    for i in range(blades):
        z = lz0 + 0.022 + i * (lz1 - lz0 - 0.044) / (blades - 1)
        slab(f"Louvre{i}", (0.0, yf - 0.019, z), (2 * lx - 0.006, 0.02, 0.006), -38.0, m["door"], root)

    # The upper door: the control label, the maker's badge, a finger pull and the lamp.
    y_face = yf - 0.014
    box("Label", -hw + 0.06, -0.01, y_face - 0.002, y_face + 0.002, 1.02, 1.22, m["label"], root)
    for i, (z, w) in enumerate(((1.185, 0.17), (1.15, 0.13), (1.115, 0.16), (1.08, 0.10), (1.045, 0.14))):
        box(f"LabelLine{i}", -hw + 0.075, -hw + 0.075 + w, y_face - 0.0035, y_face - 0.0015, z, z + 0.012,
            m["ink"], root)
    box("Badge", 0.05, 0.19, y_face - 0.003, y_face + 0.002, 0.80, 0.84, m["badge"], root)
    box("Pull", -0.07, 0.07, y_face - 0.003, y_face + 0.002, 0.745, 0.765, m["dark"], root)
    box("LampBezel", 0.07, 0.17, y_face - 0.005, y_face + 0.002, 1.12, 1.195, m["black"], root, bevel=0.003,
        segments=1)
    box("PilotLamp", 0.085, 0.155, y_face - 0.008, y_face - 0.004, 1.134, 1.181, m["lamp"], root)

    # Seams round the sides and the back at the height the doors part.
    for sign in (-1, 1):
        box(f"SideSeam{'LR'[sign > 0]}", sign * hw - 0.002, sign * hw + 0.002, yf + 0.02, yb - 0.02, 0.705, 0.715,
            m["seam"], root)
    box("BackSeam", -hw + 0.02, hw - 0.02, yb - 0.002, yb + 0.002, 0.705, 0.715, m["seam"], root)
    box("RatingPlate", -0.2, -0.06, yb - 0.001, yb + 0.003, 1.02, 1.12, m["steel"], root)
    for i in range(5):                      # knock-outs and a row of slots low on the back
        z = 0.16 + i * 0.05
        box(f"BackSlot{i}", -0.16, 0.16, yb - 0.002, yb + 0.002, z, z + 0.018, m["dark"], root)

    # The left side: the filter slot, low down, with its pull tab.
    box("FilterSlot", -hw - 0.002, -hw + 0.002, yf + 0.06, yb - 0.06, 0.10, 0.135, m["dark"], root)
    box("FilterTab", -hw - 0.012, -hw, -0.04, 0.04, 0.105, 0.13, m["label"], root)

    # The right side: the disconnect box, its lever and lamp, and the conduit to the floor.
    bx0, bx1, by0, by1, bz0, bz1 = hw, hw + 0.075, -0.15, 0.03, 0.93, 1.17
    box("Disconnect", bx0 - 0.004, bx1, by0, by1, bz0, bz1, m["steel"], root, bevel=0.006)
    box("DisconnectCover", bx1 - 0.002, bx1 + 0.006, by0 + 0.015, by1 - 0.015, bz0 + 0.02, bz1 - 0.02, m["steel"],
        root, bevel=0.003, segments=1)
    box("Lever", bx1 + 0.004, bx1 + 0.022, by0 + 0.03, by0 + 0.06, bz0 + 0.06, bz0 + 0.15, m["black"], root,
        bevel=0.003, segments=1)
    box("DisconnectLamp", bx1 + 0.004, bx1 + 0.012, by1 - 0.07, by1 - 0.04, bz1 - 0.075, bz1 - 0.045, m["lamp"], root)
    cx, cy = hw + 0.036, (by0 + by1) / 2
    tube("Conduit", [(cx, cy, bz0), (cx, cy, 0.30), (cx, cy + 0.02, 0.06), (cx, cy + 0.12, 0.016),
                     (cx - 0.01, yb + 0.06, 0.014)], 0.013, m["conduit"], root)
    for i, z in enumerate((0.35, 0.7)):
        box(f"ConduitStrap{i}", hw - 0.002, cx + 0.02, cy - 0.012, cy + 0.012, z, z + 0.012, m["steel"], root)

    # On top: the plenum stub, a flanged galvanised duct going up, open at the top.
    px, py0, py1 = 0.215, -0.19, 0.27
    box("PlenumFlange", -px - 0.022, px + 0.022, py0 - 0.022, py1 + 0.022, h - 0.002, h + 0.014, m["galv"], root)
    box("Plenum", -px, px, py0, py1, h, h + F_PLENUM, m["galv"], root, bevel=0.003, segments=1)
    box("PlenumMouth", -px + 0.018, px - 0.018, py0 + 0.018, py1 - 0.018, h + F_PLENUM - 0.002, h + F_PLENUM + 0.002,
        m["dark"], root)
    return root, m


def furnace_state(mats, state):
    lamp_state(mats["lamp"], state == "on", lit=(150, 70, 10), glow=(255, 128, 12), dark=(70, 44, 14), strength=1.0)


# -- the condenser ------------------------------------------------------------------------

C_HW = 0.40                 # half its width (it is square)
C_PAD = 0.05                # the pad's thickness
C_Z1 = 0.80                 # its top, pad included
C_FAN_R = 0.30


def build_condenser():
    root = bpy.data.objects.new("Condenser", None)
    bpy.context.scene.collection.objects.link(root)
    m = dict(
        case=worn(material("CondenserPaint", srgb(120, 134, 118), rough=0.55, metallic=0.2), dirt=(72, 70, 58),
                  amount=0.35),
        top=worn(material("CondenserTop", srgb(132, 146, 130), rough=0.5, metallic=0.2), dirt=(84, 82, 68),
                 amount=0.3, scale=7.0),
        coil=material("Coil", srgb(44, 46, 46), rough=0.6, metallic=0.5),
        dark=material("CondenserVoid", srgb(20, 21, 22), rough=0.9),
        concrete=worn(material("Concrete", srgb(152, 150, 143), rough=0.95), dirt=(104, 100, 90), amount=0.5,
                      scale=11.0),
        blade=material("FanBlade", srgb(176, 180, 180), rough=0.35, metallic=0.8),
        blur=material("FanBlur", srgb(92, 96, 96), rough=0.5, metallic=0.4),
        blur2=material("FanBlurRing", srgb(116, 120, 120), rough=0.5, metallic=0.4),
        wire=material("GuardWire", srgb(58, 60, 62), rough=0.4, metallic=0.8),
        label=material("CondenserLabel", srgb(228, 222, 200), rough=0.6),
        ink=material("CondenserInk", srgb(52, 50, 48), rough=0.6),
        steel=material("PlateSteel", srgb(150, 152, 150), rough=0.4, metallic=0.7),
        copper=material("Copper", srgb(176, 108, 66), rough=0.35, metallic=0.9),
        foam=material("LineInsulation", srgb(30, 30, 32), rough=0.9),
        whip=material("Whip", srgb(120, 122, 122), rough=0.5, metallic=0.5),
    )
    hw, z0, z1 = C_HW, C_PAD, C_Z1

    box("Pad", -0.46, 0.46, -0.46, 0.46, 0.0, z0, m["concrete"], root, bevel=0.008)

    # A base pan, the coil behind the louvres, four corner posts and the top cap.
    box("BasePan", -hw, hw, -hw, hw, z0, z0 + 0.06, m["case"], root, bevel=0.006)
    box("Coil", -hw + 0.03, hw - 0.03, -hw + 0.03, hw - 0.03, z0 + 0.05, z1 - 0.05, m["coil"], root)
    post = 0.055
    for sx in (-1, 1):
        for sy in (-1, 1):
            x0, x1 = sorted((sx * hw, sx * (hw - post)))
            y0, y1 = sorted((sy * hw, sy * (hw - post)))
            box(f"Post{'WE'[sx > 0]}{'SN'[sy > 0]}", x0, x1, y0, y1, z0 + 0.05, z1 - 0.05, m["case"], root,
                bevel=0.006)
    box("TopCap", -hw - 0.006, hw + 0.006, -hw - 0.006, hw + 0.006, z1 - 0.07, z1, m["top"], root, bevel=0.012)

    # Louvres on all four sides: blades slanting down and out, between the posts.
    blades = 13
    lz0, lz1 = z0 + 0.09, z1 - 0.10
    span = 2 * (hw - post) - 0.004
    for side, (axis, sign) in {"S": ("X", -1), "N": ("X", 1), "W": ("Y", -1), "E": ("Y", 1)}.items():
        for i in range(blades):
            z = lz0 + i * (lz1 - lz0) / (blades - 1)
            if axis == "X":      # a face across Y: the blade runs along X
                b = centred(f"Louvre{side}{i}", (span, 0.03, 0.008), m["case"], root)
                turned(b, (0.0, sign * (hw - 0.012), z), "X", sign * 38.0)
            else:                # a face across X: the blade runs along Y
                b = centred(f"Louvre{side}{i}", (0.03, span, 0.008), m["case"], root)
                turned(b, (sign * (hw - 0.012), 0.0, z), "Y", -sign * 38.0)

    # The front (-Y): a plain service panel on the right with the label and the rating
    # plate, the two refrigerant lines and the electrical whip leaving it.
    sx0, sx1 = 0.10, hw - post + 0.004
    yf = -hw
    box("ServicePanel", sx0, sx1, yf - 0.008, yf + 0.02, z0 + 0.06, z1 - 0.07, m["top"], root, bevel=0.004,
        segments=1)
    box("ServiceLabel", sx0 + 0.03, sx1 - 0.03, yf - 0.011, yf - 0.007, 0.52, 0.66, m["label"], root)
    for i, (z, w) in enumerate(((0.625, 0.15), (0.595, 0.11), (0.565, 0.14), (0.535, 0.08))):
        box(f"ServiceLine{i}", sx0 + 0.045, sx0 + 0.045 + w, yf - 0.0125, yf - 0.0105, z, z + 0.011, m["ink"], root)
    box("ServicePlate", sx0 + 0.05, sx1 - 0.05, yf - 0.011, yf - 0.007, 0.40, 0.46, m["steel"], root)
    lx = sx0 + 0.06
    tube("SuctionLine", [(lx, yf - 0.004, 0.27), (lx, yf - 0.07, 0.25), (lx - 0.01, yf - 0.085, 0.10),
                         (lx - 0.03, yf - 0.10, z0 + 0.02)], 0.017, m["foam"], root)
    tube("LiquidLine", [(lx + 0.05, yf - 0.004, 0.22), (lx + 0.05, yf - 0.05, 0.20), (lx + 0.045, yf - 0.065, 0.10),
                        (lx + 0.03, yf - 0.10, z0 + 0.012)], 0.0075, m["copper"], root)
    wx = sx1 - 0.05
    tube("Whip", [(wx, yf - 0.004, 0.33), (wx + 0.01, yf - 0.06, 0.30), (wx + 0.03, yf - 0.075, 0.12),
                  (wx + 0.04, yf - 0.10, z0 + 0.016)], 0.012, m["whip"], root)

    # On top: the fan opening, the motor hub, four blades, and the wire guard over them.
    disc("FanWell", 0, 0, z1 - 0.002, z1 + 0.002, C_FAN_R, m["dark"], root)
    disc("FanCollar", 0, 0, z1 - 0.001, z1 + 0.006, C_FAN_R + 0.012, m["top"], root)
    disc("FanWellInner", 0, 0, z1 + 0.004, z1 + 0.008, C_FAN_R - 0.004, m["dark"], root)
    disc("Hub", 0, 0, z1 + 0.006, z1 + 0.034, 0.062, m["wire"], root)
    blades_obj = []
    for i in range(4):
        b = centred(f"FanBlade{i}", (0.205, 0.135, 0.004), m["blade"], root)
        b.matrix_local = (Matrix.Translation((0, 0, z1 + 0.018)) @ Matrix.Rotation(math.radians(22 + 90 * i), 4, "Z") @
                          Matrix.Translation((0.165, 0, 0)) @ Matrix.Rotation(math.radians(16), 4, "X"))
        blades_obj.append(b)
    # Running: the blades as a blurred disc, lighter in a band where they are widest.
    blur = [disc("FanBlur", 0, 0, z1 + 0.014, z1 + 0.018, C_FAN_R - 0.03, m["blur"], root),
            disc("FanBlurBand", 0, 0, z1 + 0.017, z1 + 0.020, 0.215, m["blur2"], root),
            disc("FanBlurCore", 0, 0, z1 + 0.019, z1 + 0.022, 0.125, m["blur"], root)]
    gz = z1 + 0.036
    for i, r in enumerate((0.11, 0.20, 0.288)):
        ring(f"GuardRing{i}", r, gz - 0.024 * (r - 0.05) / 0.25, 0.0034, m["wire"], root)
    for i in range(8):
        a = math.radians(22.5 + 45 * i)
        tube(f"GuardSpoke{i}", [(0.05 * math.cos(a), 0.05 * math.sin(a), gz + 0.004),
                                ((C_FAN_R + 0.008) * math.cos(a), (C_FAN_R + 0.008) * math.sin(a), gz - 0.024)],
             0.0034, m["wire"], root)
    disc("GuardCap", 0, 0, gz, gz + 0.008, 0.05, m["wire"], root)
    return root, m, blades_obj, blur


# -- the vent -----------------------------------------------------------------------------

V_HL, V_HW, V_T = 0.15, 0.075, 0.007     # half its length (along Y), half its width, thickness


def build_vent():
    root = bpy.data.objects.new("Vent", None)
    bpy.context.scene.collection.objects.link(root)
    m = dict(
        steel=worn(material("RegisterSteel", srgb(168, 166, 158), rough=0.4, metallic=0.75), dirt=(96, 90, 78),
                   amount=0.35, scale=18.0),
        dark=material("RegisterVoid", srgb(18, 18, 19), rough=0.9),
        lever=material("RegisterLever", srgb(60, 60, 62), rough=0.4, metallic=0.6),
    )
    box("Frame", -V_HW, V_HW, -V_HL, V_HL, 0.0, V_T, m["steel"], root, bevel=0.002, segments=1)
    ix, iy = V_HW - 0.014, V_HL - 0.018
    box("Well", -ix, ix, -iy, iy, V_T - 0.0005, V_T + 0.0008, m["dark"], root)
    # Fins across the short way: bars of steel with dark slots between them.
    fins = 8
    for i in range(fins):
        y = -iy + (i + 0.5) * (2 * iy) / fins
        box(f"Fin{i}", -ix, ix, y - 0.0075, y + 0.0075, V_T, V_T + 0.0025, m["steel"], root)
    # The spine down the middle and the damper's thumb lever at one end.
    box("Spine", -0.004, 0.004, -iy, iy, V_T, V_T + 0.003, m["steel"], root)
    box("Lever", V_HW - 0.012, V_HW - 0.003, iy - 0.05, iy - 0.02, V_T, V_T + 0.006, m["lever"], root)
    return root, m


# -- rendering ----------------------------------------------------------------------------

class Kit:
    """The three models in one scene, one of them shown at a time."""

    def __init__(self):
        self.furnace, self.f_mats = build_furnace()
        self.condenser, self.c_mats, self.blades, self.blur = build_condenser()
        self.vent, self.v_mats = build_vent()
        self.roots = {"furnace": self.furnace, "condenser": self.condenser, "vent": self.vent}

    def show(self, name, state="off"):
        for key, root in self.roots.items():
            for obj in root.children_recursive:
                obj.hide_render = key != name
        on = state == "on"
        if name == "furnace":
            furnace_state(self.f_mats, state)
        elif name == "condenser":
            for obj in self.blades:
                obj.hide_render = on
            for obj in self.blur:
                obj.hide_render = not on
        return self.roots[name]


def turn(root, degrees):
    root.rotation_euler = (0, 0, math.radians(degrees))
    root.location = (0, 0, 0)


def jobs(objects):
    """(object, tile name, turn in degrees, states) for every sprite."""
    out = []
    for name in objects:
        if name == "vent":
            out += [(name, key, angle, ("off",)) for key, angle in VENT_TURNS.items()]
        else:
            out += [(name, key, angle, STATES) for key, angle in FACINGS.items()]
    return out


def render(scene, path):
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("rendered", path, flush=True)


def render_depth(scene, kit, objects, out):
    samples, depth_bits = scene.cycles.samples, scene.render.image_settings.color_depth
    centre = wac.DEPTH_GREY_AT_CENTRE
    wac.DEPTH_GREY_AT_CENTRE = DEPTH_GREY_AT_CENTRE
    override = wac.depth_override()
    wac.DEPTH_GREY_AT_CENTRE = centre
    scene.cycles.samples = 8
    scene.render.image_settings.color_depth = "16"
    scene.view_settings.view_transform = "Raw"
    scene.view_layers[0].material_override = override
    for name, key, angle, _ in jobs(objects):
        turn(kit.show(name, "off"), angle)
        render(scene, os.path.join(out, f"{name}_{key}_depthraw.png"))
    scene.view_layers[0].material_override = None
    scene.view_settings.view_transform = "Standard"
    scene.render.image_settings.color_depth = depth_bits
    scene.cycles.samples = samples


# What a close-up looks at: (target height, how far back the camera stands, icon span in metres)
LOOK = {"furnace": (0.72, 3.4, 1.95), "condenser": (0.42, 3.0, 1.55), "vent": (0.0, 0.75, 0.42)}
VIEW_FROM = Vector((0.80, -1.15, 0.72)).normalized()


def aim(cam, name):
    height, distance, _ = LOOK[name]
    target = Vector((0.0, 0.0, height))
    cam.location = target + VIEW_FROM * distance
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--objects", default="furnace,condenser,vent")
    ap.add_argument("--scale", type=int, default=8)
    ap.add_argument("--samples", type=int, default=64)
    ap.add_argument("--preview", action="store_true", help="render 3/4 close-ups instead of sprites")
    ap.add_argument("--icon", action="store_true", help="render the inventory icons instead of sprites")
    ap.add_argument("--depth", action="store_true", help="also render the depth pass for each sprite")
    ap.add_argument("--save-blend")
    args = ap.parse_args(argv)
    os.makedirs(args.out, exist_ok=True)
    objects = args.objects.split(",")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    cam = wac.setup_scene(args.scale, args.samples)
    scene = bpy.context.scene
    kit = Kit()

    if args.icon:
        wac.setup_preview(scene, cam, 96)
        scene.render.film_transparent = True
        scene.render.resolution_x = scene.render.resolution_y = 512
        cam.data.type = "ORTHO"
        for name in objects:
            if name == "vent":
                continue
            turn(kit.show(name, "off"), 0.0)
            aim(cam, name)
            cam.data.ortho_scale = LOOK[name][2]
            render(scene, os.path.join(args.out, f"icon_{name}_raw.png"))
    elif args.preview:
        wac.setup_preview(scene, cam, max(args.samples, 96))
        for name in objects:
            aim(cam, name)
            for state in (("off",) if name == "vent" else STATES):
                for view, angle in (("front", 0.0), ("back", 180.0)):
                    turn(kit.show(name, state), angle)
                    render(scene, os.path.join(args.out, f"preview_{name}_{view}_{state}.png"))
    else:
        for name, key, angle, states in jobs(objects):
            for state in states:
                turn(kit.show(name, state), angle)
                render(scene, os.path.join(args.out, f"{name}_{key}_{state}_raw.png"))
        if args.depth:
            render_depth(scene, kit, objects, args.out)

    if args.save_blend:
        # side by side, so the file is something to look around in
        for i, name in enumerate(("furnace", "condenser", "vent")):
            root = kit.show(name, "off")
            turn(root, 0.0)
            root.location = (1.2 * (i - 1), 0, 0)
        for root in kit.roots.values():
            for obj in root.children_recursive:
                obj.hide_render = False
        for obj in kit.blur:
            obj.hide_render = True
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(args.save_blend))
        print("saved", args.save_blend, flush=True)


if __name__ == "__main__":
    main()

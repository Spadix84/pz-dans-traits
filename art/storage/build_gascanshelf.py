"""Build the gas can shelf and render its Project Zomboid tile sprites.

  blender --background --factory-startup --python build_gascanshelf.py -- \
      --out <abs>/renders/gascanshelf --depth --save-blend <abs>/gascanshelf.blend
  blender --background --factory-startup --python build_gascanshelf.py -- --out <abs>/renders/gascanshelf --preview

The jug rack's steel frame with sheet steel decks: three levels (the floor deck, the
middle one and the top), three cans standing on each level of each tile, narrow end to
the front. The shelf takes red petrol cans (Base.PetrolCan) and jerry cans
(Base.JerryCan); the sprites show mostly red cans with a green jerry can here and there,
whatever is really on it. 2 m long, 0.42 m deep, 1.14 m to the top deck.
Conventions and rendering: shelf_common.py.

States: empty, half (the bottom level full and two on the middle), full (nine a tile).
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import shelf_common as sc  # noqa: E402

Y_FRONT, Y_BACK = 0.075, 0.44
LEVELS = (0.10, 0.62, 1.14)    # the top of each deck: the cans stand on them
PER_LEVEL = 3
CAN_W = 0.165                  # across the shelf
Y_MID = (Y_FRONT + Y_BACK) / 2
JERRY = {(0, 2), (1, 0), (2, 1)}   # where the sprites show a jerry can rather than a red one

SHOWN = {
    "empty": set(),
    "half": {(0, 0), (0, 1), (0, 2), (1, 0), (1, 1)},
    "full": {(t, s) for t in range(len(LEVELS)) for s in range(PER_LEVEL)},
}


def petrol_can(name, x, z, m, parent):
    """A red plastic petrol can, 10 l: a rounded block, a handle along the top, the spout
    at the front corner with a black cap."""
    parts = [sc.wac.box(name + "Body", x - 0.075, x + 0.075, Y_MID - 0.16, Y_MID + 0.16, z, z + 0.27,
                        m["red"], parent, bevel=0.025, segments=3)]
    for i, y in enumerate((Y_MID - 0.02, Y_MID + 0.12)):
        parts.append(sc.wac.box(f"{name}HandlePost{i}", x - 0.016, x + 0.016, y - 0.016, y + 0.016,
                                z + 0.26, z + 0.31, m["red"], parent, bevel=0.006, segments=1))
    parts.append(sc.wac.box(name + "Handle", x - 0.018, x + 0.018, Y_MID - 0.04, Y_MID + 0.14, z + 0.30, z + 0.33,
                            m["red"], parent, bevel=0.01, segments=2))
    parts.append(sc.wac.tube(name + "Spout", [(x, Y_MID - 0.11, z + 0.25), (x, Y_MID - 0.16, z + 0.33),
                                              (x, Y_MID - 0.2, z + 0.37)], 0.017, m["red"], parent))
    parts.append(sc.upright(name + "SpoutCap", 0.021, 0.021, z + 0.355, z + 0.39, x, Y_MID - 0.205,
                            m["black"], parent, segments=16))
    return sc.mark_item(parts)


def jerry_can(name, x, z, m, parent):
    """A steel jerry can, 20 l: a tall slab with a raised rim round each face, three handle
    bars on top and the spout cap at the front."""
    parts = [sc.wac.box(name + "Body", x - 0.07, x + 0.07, Y_MID - 0.165, Y_MID + 0.165, z, z + 0.44,
                        m["green"], parent, bevel=0.015, segments=2)]
    for sign in (-1, 1):
        parts.append(sc.wac.box(f"{name}Rim{'LR'[sign > 0]}", x + sign * 0.07 - 0.006, x + sign * 0.07 + 0.006,
                                Y_MID - 0.14, Y_MID + 0.14, z + 0.04, z + 0.4, m["green_dark"], parent))
    for i, y in enumerate((Y_MID - 0.02, Y_MID + 0.05, Y_MID + 0.12)):
        parts.append(sc.wac.box(f"{name}Handle{i}", x - 0.05, x + 0.05, y - 0.012, y + 0.012, z + 0.44, z + 0.47,
                                m["green"], parent, bevel=0.006, segments=1))
    parts.append(sc.upright(name + "Cap", 0.03, 0.03, z + 0.43, z + 0.47, x, Y_MID - 0.12, m["green_dark"], parent,
                            segments=16))
    return sc.mark_item(parts)


def build():
    root = bpy.data.objects.new("GasCanShelf", None)
    bpy.context.scene.collection.objects.link(root)
    m = sc.materials()
    m["red"] = sc.material("PetrolCanRed", sc.srgb(196, 40, 30), rough=0.38, specular=0.55)
    m["black"] = sc.material("SpoutCap", sc.srgb(30, 30, 30), rough=0.5)
    m["green"] = sc.material("JerryGreen", sc.srgb(86, 98, 58), rough=0.55, metallic=0.2)
    m["green_dark"] = sc.material("JerryGreenDark", sc.srgb(64, 74, 42), rough=0.6, metallic=0.2)
    halves, items = {}, {}
    for half in sc.HALVES:
        hroot = sc.link(bpy.data.objects.new(f"Half{half}", None), root)
        sc.frame(half, m, hroot, Y_FRONT, Y_BACK, LEVELS, decks=(0, 1, 2))
        items[half] = {}
        for t, z in enumerate(LEVELS):
            for s, x in enumerate(sc.slot_xs(half, PER_LEVEL, CAN_W)):
                make = jerry_can if (t, s) in JERRY else petrol_can
                items[half][(t, s)] = make(f"Can{half}{t}{s}", x, z + 0.002, m, hroot)
        halves[half] = hroot
    return root, halves, items


if __name__ == "__main__":
    sc.run("gascanshelf", build, SHOWN)

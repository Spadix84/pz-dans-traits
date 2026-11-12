"""Build the water jug rack and render its Project Zomboid tile sprites.

  blender --background --factory-startup --python build_waterjugrack.py -- \
      --out <abs>/renders/waterjugrack --depth --save-blend <abs>/waterjugrack.blend
  blender --background --factory-startup --python build_waterjugrack.py -- --out <abs>/renders/waterjugrack --preview

A plain steel rack two tiles long for water dispenser jugs (Base.WaterDispenserBottle):
three tiers of a front and a back beam and no deck, three jugs lying on their sides on
each tier of each tile, necks out to the front, resting on the two beams. 2 m long,
0.42 m deep, 1.12 m high. Conventions and rendering: shelf_common.py.

States: empty, half (the bottom tier full and two on the middle tier), full (nine a tile).
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import shelf_common as sc  # noqa: E402

Y_FRONT, Y_BACK = 0.075, 0.44   # the uprights' centres, front and back
TIER_Z = (0.10, 0.44, 0.78)     # the top of each tier's beams: the jugs rest on them
TOP_Z = 1.12

# A 5-gallon (19 l) jug lying on its side: body, shoulder, neck, cap
JUG_R = 0.135
JUG_Y = (0.06, 0.44)      # its body, front to back
SHOULDER_Y = 0.0
NECK_R, NECK_Y = 0.03, -0.04
CAP_R, CAP_Y = 0.034, -0.066
PER_TIER = 3

SHOWN = {
    "empty": set(),
    "half": {(0, 0), (0, 1), (0, 2), (1, 0), (1, 1)},
    "full": {(t, s) for t in range(3) for s in range(PER_TIER)},
}


def jug(name, x, z, m, parent):
    """One jug lying on its side, neck to the front (-Y). Returns its parts."""
    parts = [sc.bevel(sc.along_y(name + "Body", JUG_R, JUG_R, JUG_Y[1], JUG_Y[0], x, z, m["jug"], parent), 0.035)]
    for i, y in enumerate((0.17, 0.33)):
        parts.append(sc.along_y(f"{name}Rib{i}", JUG_R + 0.004, JUG_R + 0.004, y + 0.012, y - 0.012, x, z,
                                m["jug"], parent))
    parts.append(sc.along_y(name + "Shoulder", JUG_R * 0.93, NECK_R + 0.012, JUG_Y[0] + 0.01, SHOULDER_Y, x, z,
                            m["jug"], parent))
    parts.append(sc.along_y(name + "Neck", NECK_R, NECK_R, SHOULDER_Y + 0.005, NECK_Y, x, z, m["jug"], parent))
    parts.append(sc.along_y(name + "Cap", CAP_R, CAP_R, NECK_Y + 0.004, CAP_Y, x, z, m["cap"], parent))
    return sc.mark_item(parts)


def build():
    root = bpy.data.objects.new("WaterJugRack", None)
    bpy.context.scene.collection.objects.link(root)
    m = sc.materials()
    m["jug"] = sc.material("JugPlastic", sc.srgb(112, 168, 214), rough=0.16, specular=0.7)
    m["cap"] = sc.material("JugCap", sc.srgb(28, 74, 158), rough=0.35)
    halves, items = {}, {}
    for half in sc.HALVES:
        hroot = sc.link(bpy.data.objects.new(f"Half{half}", None), root)
        sc.frame(half, m, hroot, Y_FRONT, Y_BACK, TIER_Z + (TOP_Z,))
        items[half] = {}
        for t, z_top in enumerate(TIER_Z):
            for s, x in enumerate(sc.slot_xs(half, PER_TIER, 2 * JUG_R)):
                items[half][(t, s)] = jug(f"Jug{half}{t}{s}", x, z_top + JUG_R, m, hroot)
        halves[half] = hroot
    return root, halves, items


if __name__ == "__main__":
    sc.run("waterjugrack", build, SHOWN)

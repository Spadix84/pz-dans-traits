"""Build the propane shelf and render its Project Zomboid tile sprites.

  blender --background --factory-startup --python build_propaneshelf.py -- \
      --out <abs>/renders/propaneshelf --depth --save-blend <abs>/propaneshelf.blend
  blender --background --factory-startup --python build_propaneshelf.py -- --out <abs>/renders/propaneshelf --preview

The jug rack's steel frame with two sheet steel decks under a top frame, three 20 lb
propane tanks (Base.PropaneTank) standing on each deck of each tile: white, rounded,
on a foot ring, with the collar and the valve on top. 2 m long, 0.42 m deep, 1.22 m high.
Conventions and rendering: shelf_common.py.

States: empty, half (the bottom deck full), full (six a tile).
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import shelf_common as sc  # noqa: E402

Y_FRONT, Y_BACK = 0.075, 0.44
LEVELS = (0.10, 0.66, 1.22)    # two decks and the top frame
PER_LEVEL = 3
TANK_R = 0.14
Y_MID = (Y_FRONT + Y_BACK) / 2

SHOWN = {
    "empty": set(),
    "half": {(0, 0), (0, 1), (0, 2)},
    "full": {(t, s) for t in range(2) for s in range(PER_LEVEL)},
}


def tank(name, x, z, m, parent):
    """A 20 lb propane tank standing on its foot ring."""
    y = Y_MID
    parts = [
        sc.upright(name + "Foot", TANK_R * 0.8, TANK_R * 0.8, z, z + 0.05, x, y, m["white"], parent),
        sc.bevel(sc.upright(name + "Body", TANK_R, TANK_R, z + 0.035, z + 0.385, x, y, m["white"], parent), 0.07, 4),
        # the weld seam round its middle
        sc.upright(name + "Seam", TANK_R + 0.004, TANK_R + 0.004, z + 0.205, z + 0.217, x, y, m["seam"], parent),
        sc.upright(name + "Collar", TANK_R * 0.62, TANK_R * 0.62, z + 0.36, z + 0.455, x, y, m["white"], parent),
        sc.upright(name + "CollarHole", TANK_R * 0.5, TANK_R * 0.5, z + 0.40, z + 0.458, x, y, m["shadow"], parent),
        sc.upright(name + "Valve", 0.022, 0.022, z + 0.38, z + 0.43, x, y, m["brass"], parent, segments=16),
        sc.upright(name + "Wheel", 0.04, 0.04, z + 0.43, z + 0.445, x, y, m["wheel"], parent, segments=20),
    ]
    return sc.mark_item(parts)


def build():
    root = bpy.data.objects.new("PropaneShelf", None)
    bpy.context.scene.collection.objects.link(root)
    m = sc.materials()
    m["white"] = sc.material("TankWhite", sc.srgb(222, 222, 214), rough=0.4, specular=0.5)
    m["seam"] = sc.material("TankSeam", sc.srgb(176, 178, 174), rough=0.45)
    m["shadow"] =sc.material("CollarInside", sc.srgb(70, 70, 68), rough=0.7)
    m["brass"] = sc.material("ValveBrass", sc.srgb(176, 142, 70), rough=0.35, metallic=0.8)
    m["wheel"] = sc.material("ValveWheel", sc.srgb(40, 40, 42), rough=0.5)
    halves, items = {}, {}
    for half in sc.HALVES:
        hroot = sc.link(bpy.data.objects.new(f"Half{half}", None), root)
        sc.frame(half, m, hroot, Y_FRONT, Y_BACK, LEVELS, decks=(0, 1))
        items[half] = {}
        for t, z in enumerate(LEVELS[:2]):
            for s, x in enumerate(sc.slot_xs(half, PER_LEVEL, 2 * TANK_R)):
                items[half][(t, s)] = tank(f"Tank{half}{t}{s}", x, z + 0.002, m, hroot)
        halves[half] = hroot
    return root, halves, items


if __name__ == "__main__":
    sc.run("propaneshelf", build, SHOWN)

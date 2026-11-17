"""Blender: render the mod's weapons for the Workshop pictures, on a transparent background.

    blender --background --factory-startup --python render_weapons.py -- --out DIR [--samples N]

make_images.py runs this. It reads the models and textures the mod ships
(DansWeapons/42/media), so the pictures show what is in the game, and writes for each:

    side_<Name>.png   from the side, grip left, every weapon at the same scale (PPU pixels
                      to one unit of the game's model space)
    hero_<Name>.png   the working end, three quarters on
"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(REPO, "art", "weapons"))
import weapon_common as wc  # noqa: E402

MEDIA = os.path.join(REPO, "DansWeapons", "42", "media")
PPU = 1500          # side views: pixels per unit of model space
PAD = 0.02          # side views: room round the model, in model units

# name: (the game's weapon folder, texture, side view direction,
#        hero (target, toward, width in model units, size in pixels))
WEAPONS = {
    "HockeyStickCleaver": ("2handed", "HockeyStickCleaver", (1, 0, 0),
                           ((0.0, 0.50, 0.01), (0.8, 0.5, -0.45), 0.42, (1500, 1100))),
    "BreadKnifeGlaive": ("2handed", "BreadKnifeGlaive", (1, 0, 0),
                         ((0.0, 0.56, -0.016), (0.8, 0.5, -0.45), 0.44, (1500, 900))),
    "CutleryMace": ("1handed", "CutleryMace", (1, 0, 0.25),
                    ((0.0, 0.29, 0.0), (0.7, 0.6, 0.4), 0.26, (1500, 1100))),
    "LockInASock": ("1handed", "LockInASock", (1, 0, 0),
                    ((0.0, 0.14, -0.02), (0.7, 0.45, 0.5), 0.44, (1500, 1000))),
    "SockFlail": ("1handed", "LockInASock", (1, 0, 0),
                  ((0.0, 0.19, -0.03), (0.7, 0.45, 0.5), 0.54, (1500, 1000))),
}


def main():
    import bpy
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--samples", type=int, default=96)
    args = ap.parse_args(argv)
    # absolute: Blender reads a relative render path against the drive's root, not the cwd
    args.out = os.path.abspath(args.out)
    os.makedirs(args.out, exist_ok=True)

    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    rig = wc.setup_scene(args.samples)
    scene = rig["scene"]
    scene.render.film_transparent = True
    scene.render.image_settings.color_mode = "RGBA"
    scene.cycles.use_denoising = True
    rig["back"].hide_render = True

    objects = {}
    for name, (hands, texture, _, _) in WEAPONS.items():
        obj = wc.x_to_blender(os.path.join(MEDIA, "models_X", "weapons", hands, name + ".X"),
                              os.path.join(MEDIA, "textures", "weapons", hands, texture + ".png"), name)
        obj.hide_render = True
        objects[name] = obj

    def out(file):
        return os.path.join(args.out, file).replace("\\", "/")

    for name, (_, _, side, hero) in WEAPONS.items():
        obj = objects[name]
        obj.hide_render = False
        vs = [v.co for v in obj.data.vertices]
        lo = [min(v[k] for v in vs) for k in range(3)]
        hi = [max(v[k] for v in vs) for k in range(3)]
        mid = [(lo[k] + hi[k]) / 2.0 for k in range(3)]
        # on screen: +Y runs right, +Z up; a tilted view also shows some of the X extent
        wide = (hi[1] - lo[1]) + 2 * PAD
        tall = (hi[2] - lo[2]) + (hi[0] - lo[0]) * abs(side[2]) + 2 * PAD
        size = (int(round(wide * PPU)), int(round(tall * PPU)))
        wc.shot(rig, out("side_%s.png" % name), mid, side, (0, 0, 1), max(wide, tall), size)
        target, toward, width, hsize = hero
        wc.shot(rig, out("hero_%s.png" % name), target, toward, (0, 0, 1), width, hsize)
        obj.hide_render = True


if __name__ == "__main__":
    main()

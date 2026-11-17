"""Copy the built weapon art into the Dan's Weapons mod (DansWeapons/42/media).

    python install.py            every weapon in WEAPONS
    python install.py --check    say which mod files differ from the built ones, copy nothing

Build first (each weapon's folder: make_texture.py, the Blender build, make_icon.py).
"""
import filecmp
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MEDIA = os.path.join(HERE, "..", "..", "DansWeapons", "42", "media")
MOD = os.path.join(HERE, "..", "..", "DansWeapons", "42")
# folder, the game's weapon folder (1handed or 2handed), the models in it, their textures
# (a model without one of its own names another's in its model script). Each model has an
# icon, Item_<model>.png.
WEAPONS = [
    ("hockeycleaver", "2handed", ["HockeyStickCleaver"], ["HockeyStickCleaver"]),
    ("glaive", "2handed", ["BreadKnifeGlaive"], ["BreadKnifeGlaive"]),
    ("cutlerymace", "1handed", ["CutleryMace"], ["CutleryMace"]),
    ("sock", "1handed", ["LockInASock", "SockFlail"], ["LockInASock"]),
]
# the mod's own icon in the mod list: the first weapon's
MOD_ICON = ("hockeycleaver", "Item_HockeyStickCleaver.png")


def pairs():
    for folder, hands, models, textures in WEAPONS:
        src = os.path.join(HERE, folder)
        for name in models:
            yield os.path.join(src, name + ".X"), os.path.join(MEDIA, "models_X", "weapons", hands, name + ".X")
            yield os.path.join(src, "Item_%s.png" % name), os.path.join(MEDIA, "textures", "Item_%s.png" % name)
        for name in textures:
            yield os.path.join(src, name + ".png"), os.path.join(MEDIA, "textures", "weapons", hands, name + ".png")
    yield os.path.join(HERE, *MOD_ICON), os.path.join(MOD, "icon.png")


def main():
    check = "--check" in sys.argv[1:]
    stale = 0
    for src, dst in pairs():
        same = os.path.isfile(dst) and filecmp.cmp(src, dst, shallow=False)
        if same:
            continue
        stale += 1
        if check:
            print("differs: %s" % os.path.relpath(dst, os.path.join(HERE, "..", "..")))
        else:
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copyfile(src, dst)
            print("copied %s" % os.path.relpath(dst, os.path.join(HERE, "..", "..")))
    if not stale:
        print("the mod's weapon art is up to date")
    return 1 if (check and stale) else 0


if __name__ == "__main__":
    sys.exit(main())

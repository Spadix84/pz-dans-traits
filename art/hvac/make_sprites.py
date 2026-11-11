"""Turn the high-res furnace, condenser and vent renders into game-sized sprites.

  python make_sprites.py <raw_dir> <out_dir>

The same treatment as the window air conditioner's (../windowac/make_sprites.py, whose
functions this uses): downscale to the 128x256 tile, a dark inner edge, a reduced palette.
Writes:
  <object>_<facing>_<state>.png   each sprite (the vent's are vent_A_off, vent_B_off)
  appliances_hvac_01.png          the tile sheet, 8 columns by 3 rows (see LAYOUT)
  DEPTH_appliances_hvac_01.png    its depth map, from the depth renders
  Item_HVACFurnace.png, Item_HVACCondenser.png   32x32 inventory icons, from icon_*_raw.png
  mockup.png                      each sprite on a floor tile, at 3x, to look at
"""
import argparse
import importlib.util
import os

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("windowac_sprites", os.path.join(HERE, "..", "windowac", "make_sprites.py"))
wac = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wac)

TILE = wac.TILE
TILESET = "appliances_hvac_01"
COLUMNS, ROWS = 8, 3
FACINGS = ("S", "E", "N", "W")
# Tile number -> (object, facing or turn, state). Tiles 18-23 stay empty.
LAYOUT = {}
for i, f in enumerate(FACINGS):
    LAYOUT[i] = ("furnace", f, "off")
    LAYOUT[4 + i] = ("furnace", f, "on")
    LAYOUT[8 + i] = ("condenser", f, "off")
    LAYOUT[12 + i] = ("condenser", f, "on")
LAYOUT[16] = ("vent", "A", "off")      # long side along the tile's north-south axis
LAYOUT[17] = ("vent", "B", "off")      # turned a quarter
ICONS = {"furnace": "Item_HVACFurnace.png", "condenser": "Item_HVACCondenser.png"}


def stylise(path):
    """The window air conditioner's treatment, then the lit lamp put back: it is a few
    pixels of amber, too few to win a place in the reduced palette, which turns them
    cream. Lit pixels are the strongly orange ones in the plain downscale."""
    sprite = wac.stylise(path)
    r, g, b, a = (np.asarray(c).astype(int) for c in wac.downscale(path))
    lit = (a > 200) & (r > 190) & (g > 60) & (g < 190) & (b < 90) & (r - b > 130)
    if lit.any():
        px = np.array(sprite)
        px[lit, 0], px[lit, 1], px[lit, 2] = r[lit], g[lit], b[lit]
        sprite = Image.fromarray(px, "RGBA")
    return sprite, int(lit.sum())


def icon(raw, name, out):
    src = Image.open(os.path.join(raw, f"icon_{name}_raw.png")).convert("RGBA")
    src = src.crop(src.getbbox())
    src.thumbnail((32, 32), Image.LANCZOS)
    im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    im.paste(src, ((32 - src.width) // 2, (32 - src.height) // 2))
    im.save(os.path.join(out, ICONS[name]))


def mockup(sprites, out):
    """Each sprite on a floor-coloured tile with the diamond drawn in, at 3x: a row for
    the furnace idle, running, the condenser idle, running, and the two vents."""
    rows = [([0, 1, 2, 3], 70), ([4, 5, 6, 7], 70), ([8, 9, 10, 11], 120), ([12, 13, 14, 15], 120), ([16, 17], 176)]
    height = sum(TILE[1] - top for _, top in rows)
    sheet = Image.new("RGBA", (TILE[0] * 4, height), (74, 82, 70, 255))
    draw = ImageDraw.Draw(sheet)
    y = 0
    for tiles, top in rows:
        for i, n in enumerate(tiles):
            tile = Image.new("RGBA", TILE, (0, 0, 0, 0))
            ImageDraw.Draw(tile).polygon([(64, 192), (128, 224), (64, 256), (0, 224)], fill=(150, 128, 98, 255))
            tile.alpha_composite(sprites[n])
            sheet.alpha_composite(tile.crop((0, top, TILE[0], TILE[1])), (i * TILE[0], y))
            draw.text((i * TILE[0] + 4, y + 2), "%d %s %s %s" % ((n,) + LAYOUT[n]), fill=(255, 255, 255))
        y += TILE[1] - top
    sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("raw")
    ap.add_argument("out")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    sheet = Image.new("RGBA", (TILE[0] * COLUMNS, TILE[1] * ROWS), (0, 0, 0, 0))
    depth_sheet = sheet.copy()
    sprites = {}
    for n, (name, key, state) in sorted(LAYOUT.items()):
        sprite, lit = stylise(os.path.join(args.raw, f"{name}_{key}_{state}_raw.png"))
        sprite.save(os.path.join(args.out, f"{name}_{key}_{state}.png"))
        sprites[n] = sprite
        depth = wac.depth_tile(os.path.join(args.raw, f"{name}_{key}_depthraw.png"), sprite)
        pos = ((n % COLUMNS) * TILE[0], (n // COLUMNS) * TILE[1])
        sheet.paste(sprite, pos)
        depth_sheet.paste(depth, pos)
        grey = depth.getchannel("R").crop(sprite.getbbox())
        alpha = sprite.getchannel("A").crop(sprite.getbbox())
        values = np.asarray(grey)[np.asarray(alpha) > 0]
        print(f"{n:2d} {name}_{key}_{state}.png bbox {sprite.getbbox()} depth {values.min()}-{values.max()}"
              + (f", {lit} lit px" if lit else ""))
    sheet.save(os.path.join(args.out, f"{TILESET}.png"))
    depth_sheet.save(os.path.join(args.out, f"DEPTH_{TILESET}.png"))
    for name in ICONS:
        icon(args.raw, name, args.out)
    mockup(sprites, os.path.join(args.out, "mockup.png"))
    print(f"{TILESET}.png, DEPTH_{TILESET}.png, {', '.join(ICONS.values())}, mockup.png")


if __name__ == "__main__":
    main()

"""Turn the high-res space heater renders into game-sized sprites in the vanilla style.

  python make_sprites.py <raw_dir> <out_dir> [--facings S,E,N,W] [--states off,on]

The same treatment as the window air conditioner's (../windowac/make_sprites.py, whose
functions this uses): downscale to the 128x256 tile, a dark inner edge, a reduced palette.
Writes:
  spaceheater_<facing>_<state>.png     each sprite
  appliances_spaceheater_01.png        the tile sheet: facings in order, off then on
  DEPTH_appliances_spaceheater_01.png  its depth map, from the depth renders
  mockup.png                           each sprite on a floor tile, at 3x, to look at
"""
import argparse
import importlib.util
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("windowac_sprites", os.path.join(HERE, "..", "windowac", "make_sprites.py"))
wac = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wac)

TILE = wac.TILE
TILESET = "appliances_spaceheater_01"


def mockup(sprites, facings, states, out):
    """Each sprite on a floor-coloured tile with the diamond drawn in, at 3x."""
    sheet = Image.new("RGBA", (TILE[0] * len(facings), 112 * len(states)), (74, 82, 70, 255))
    draw = ImageDraw.Draw(sheet)
    for j, state in enumerate(states):
        for i, facing in enumerate(facings):
            tile = Image.new("RGBA", TILE, (0, 0, 0, 0))
            ImageDraw.Draw(tile).polygon([(64, 192), (128, 224), (64, 256), (0, 224)], fill=(150, 128, 98, 255))
            tile.alpha_composite(sprites[(facing, state)])
            pos = (i * TILE[0], j * 112)
            sheet.alpha_composite(tile.crop((0, 150, TILE[0], TILE[1])), pos)
            draw.text((pos[0] + 4, pos[1] + 2), f"{facing} {state}", fill=(255, 255, 255))
    sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("raw")
    ap.add_argument("out")
    ap.add_argument("--facings", default="S,E,N,W")
    ap.add_argument("--states", default="off,on")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    facings, states = args.facings.split(","), args.states.split(",")
    sprites = {}
    n = len(facings) * len(states)
    sheet = Image.new("RGBA", (TILE[0] * n, TILE[1]), (0, 0, 0, 0))
    depth_sheet = sheet.copy()
    i = 0
    for state in states:
        for facing in facings:
            sprite = wac.stylise(os.path.join(args.raw, f"spaceheater_{facing}_{state}_raw.png"))
            sprite.save(os.path.join(args.out, f"spaceheater_{facing}_{state}.png"))
            sprites[(facing, state)] = sprite
            depth = wac.depth_tile(os.path.join(args.raw, f"spaceheater_{facing}_depthraw.png"), sprite)
            sheet.paste(sprite, (i * TILE[0], 0))
            depth_sheet.paste(depth, (i * TILE[0], 0))
            i += 1
            print(f"spaceheater_{facing}_{state}.png", "bbox", sprite.getbbox())
    sheet.save(os.path.join(args.out, f"{TILESET}.png"))
    depth_sheet.save(os.path.join(args.out, f"DEPTH_{TILESET}.png"))
    mockup(sprites, facings, states, os.path.join(args.out, "mockup.png"))
    print(f"{TILESET}.png, DEPTH_{TILESET}.png, mockup.png")


if __name__ == "__main__":
    main()

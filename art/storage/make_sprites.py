"""Turn a storage shelf's renders into game-sized sprites in the vanilla style.

  python make_sprites.py <name>        e.g. waterjugrack, gascanshelf, propaneshelf

Reads renders/<name>/ (the build_<name>.py output), writes sprites/<name>/.

The same treatment as the window air conditioner's (../windowac/make_sprites.py, whose
functions this uses): downscale to the 128x256 tile, a dark inner edge, a reduced palette.

The sheet is 8 columns by 3 rows. A row is a state (empty, half, full); along it, each
facing's two tiles in the order vanilla's own two-tile shelves use (crafted_05_48/49):
  S: west tile (0,0), east tile (1,0)      E: south tile (0,1), north tile (0,0)
  N: west tile (0,0), east tile (1,0)      W: south tile (0,1), north tile (0,0)
So tiles 0-7 are the shelf itself, 8-15 the same half full (drawn over it while it holds
some) and 16-23 full (drawn over it when every place is taken).

Writes:
  <name>_<facing>_<half>_<state>.png  each sprite
  storage_<name>_01.png               the tile sheet
  DEPTH_storage_<name>_01.png         its depth map, from the depth renders
  mockup.png                          the whole shelf on the floor, each facing and state, at 2x
  preview.png                         the 3/4 render of the full shelf, scaled down (the build icon's source)
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
FACINGS = ["S", "E", "N", "W"]
STATES = ["empty", "half", "full"]
# Each facing's halves in sheet order, and their grid positions (the build scripts print these)
ORDER = {
    "S": [("L", (0, 0)), ("R", (1, 0))],
    "E": [("L", (0, 1)), ("R", (0, 0))],
    "N": [("R", (0, 0)), ("L", (1, 0))],
    "W": [("R", (0, 1)), ("L", (0, 0))],
}


def floor_diamond(draw, ox, oy, colour):
    draw.polygon([(ox + 64, oy + 192), (ox + 128, oy + 224), (ox + 64, oy + 256), (ox, oy + 224)], fill=colour)


def mockup(sprites, out):
    """The two tiles of each facing put together on two floor tiles, a state a row, at 2x."""
    cell_w, cell_h = 256, 200
    sheet = Image.new("RGBA", (cell_w * len(FACINGS), cell_h * len(STATES)), (74, 82, 70, 255))
    draw = ImageDraw.Draw(sheet)
    for j, state in enumerate(STATES):
        for i, facing in enumerate(FACINGS):
            cell = Image.new("RGBA", (cell_w + 128, 256 + 64), (0, 0, 0, 0))
            cd = ImageDraw.Draw(cell)
            # grid (x, y) -> screen: +x goes right-down, +y left-down
            placed = []
            for half, (gx, gy) in ORDER[facing]:
                ox = 64 + (gx - gy) * 64
                oy = (gx + gy) * 32
                placed.append((gx + gy, ox, oy, sprites[(facing, half, state)]))
            for _, ox, oy, _ in placed:
                floor_diamond(cd, ox, oy, (150, 128, 98, 255))
            for _, ox, oy, sprite in sorted(placed, key=lambda p: p[0]):
                cell.alpha_composite(sprite, (ox, oy))
            crop = cell.crop((0, 60, cell_w + 128, 60 + cell_h))
            crop = crop.resize((cell_w, round(crop.height * cell_w / crop.width)), Image.LANCZOS)
            sheet.alpha_composite(crop, (i * cell_w, j * cell_h))
            draw.text((i * cell_w + 4, j * cell_h + 2), f"{facing} {state}", fill=(255, 255, 255))
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    args = ap.parse_args()
    tileset = f"storage_{args.name}_01"
    raw = os.path.join(HERE, "renders", args.name)
    out = os.path.join(HERE, "sprites", args.name)
    os.makedirs(out, exist_ok=True)
    sprites = {}
    sheet = Image.new("RGBA", (TILE[0] * 8, TILE[1] * len(STATES)), (0, 0, 0, 0))
    depth_sheet = sheet.copy()
    for row, state in enumerate(STATES):
        col = 0
        for facing in FACINGS:
            for half, _ in ORDER[facing]:
                stem = f"{args.name}_{facing}_{half}_{state}"
                sprite = wac.stylise(os.path.join(raw, stem + "_raw.png"))
                sprite.save(os.path.join(out, stem + ".png"))
                sprites[(facing, half, state)] = sprite
                depth = wac.depth_tile(os.path.join(raw, stem + "_depthraw.png"), sprite)
                sheet.paste(sprite, (col * TILE[0], row * TILE[1]))
                depth_sheet.paste(depth, (col * TILE[0], row * TILE[1]))
                print(f"{tileset}_{row * 8 + col}: {stem}", "bbox", sprite.getbbox())
                col += 1
    sheet.save(os.path.join(out, f"{tileset}.png"))
    depth_sheet.save(os.path.join(out, f"DEPTH_{tileset}.png"))
    mockup(sprites, os.path.join(out, "mockup.png"))
    preview = os.path.join(raw, "preview_full.png")
    if os.path.exists(preview):
        im = Image.open(preview).convert("RGBA")
        im.thumbnail((700, 500), Image.LANCZOS)
        im.save(os.path.join(out, "preview.png"))
    print(f"{tileset}.png, DEPTH_{tileset}.png, mockup.png")


if __name__ == "__main__":
    main()

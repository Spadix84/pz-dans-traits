"""Package the window AC tile sheet for the game: texture pack, tile definitions, depth map.

  python build_pack.py <sprites_dir> <mod_media_dir>

Writes into the mod's media folder:
  texturepacks/DansClimate.pack            PZPK v1: every tile trimmed onto one atlas page
  DansClimate_tiledefinitions.tiles        tdef v1 binary, the file the game reads
  DansClimate_tiledefinitions.tiles.txt    the same as text, for reading and TileZed
  depthmaps/DEPTH_appliances_windowac_01.png
  textures/Item_WindowAC.png               the inventory icon

mod.info names them: pack=DansClimate, tiledef=DansClimate_tiledefinitions 6743 (6742 is
the Slow Cooker's; no installed mod uses 6743). The formats are the Slow Cooker's
art/build_pack.py, which read them from the game's own files.

Tiles 0-3 are the unit switched off, facing S, E, N, W; 4-7 the same switched on. The
facing is the way the front grille points, the room's side. The object always sits on
the window's own square: S and N on a window in the square's north edge (attachedN, like
vanilla curtains and the wall AC), E and W in its west edge (attachedW). It is not a
vanilla moveable (no IsMoveAble): the mod's own install and remove actions place and
take it, so the game's pick-up and place cursor can't put it anywhere but a window.
"""
import io
import os
import shutil
import struct
import sys

from PIL import Image

TILESET = "appliances_windowac_01"
PACK = "DansClimate"
TILE_W, TILE_H = 128, 256
FACINGS = ["S", "E", "N", "W"]   # the sheet order make_sprites.py writes
ATLAS_W = 512


def props(facing):
    edge = "attachedN" if facing in ("S", "N") else "attachedW"
    return [
        ("CustomName", "Window Air Conditioner"), ("Facing", facing),
        ("Material", "MetalScrap"), ("Material2", "Electric"),
        ("MaterialType", "Metal_Light"), (edge, ""),
    ]


def tiles():
    return [props(f) for f in FACINGS] * 2


def write_tiledefs(media):
    data = tiles()
    out = bytearray(b"tdef")
    out += struct.pack("<ii", 1, 1)
    out += f"{TILESET}\n{TILESET}.png\n".encode("latin1")
    out += struct.pack("<iiii", 8, 1, 1, len(data))
    for p in data:
        out += struct.pack("<i", len(p))
        for k, v in p:
            out += f"{k}\n{v}\n".encode("latin1")
    with open(os.path.join(media, f"{PACK}_tiledefinitions.tiles"), "wb") as f:
        f.write(out)

    lines = ["version = 1", "tileset", "{", f"    file = {TILESET}", "    size = 8,1", "    id = 1"]
    for i, p in enumerate(data):
        lines += [f"    // {TILESET}_{i}", "    tile", "    {", f"        xy = {i},0"]
        lines += [f"        {k} = {v}" for k, v in p]
        lines.append("    }")
    lines.append("}")
    with open(os.path.join(media, f"{PACK}_tiledefinitions.tiles.txt"), "w", newline="\r\n") as f:
        f.write("\n".join(lines) + "\n")


def lp_string(s):
    b = s.encode("latin1")
    return struct.pack("<i", len(b)) + b


def write_pack(sheet_path, media):
    sheet = Image.open(sheet_path).convert("RGBA")
    atlas = Image.new("RGBA", (ATLAS_W, ATLAS_W), (0, 0, 0, 0))
    x = y = row = 0
    entries = []
    for i in range(sheet.width // TILE_W):
        tile = sheet.crop((i * TILE_W, 0, (i + 1) * TILE_W, TILE_H))
        box = tile.getbbox()
        trimmed = tile.crop(box)
        if x + trimmed.width > ATLAS_W:
            x, y, row = 0, y + row + 1, 0
        atlas.paste(trimmed, (x, y))
        entries.append((f"{TILESET}_{i}", x, y, trimmed.width, trimmed.height, box[0], box[1], TILE_W, TILE_H))
        x += trimmed.width + 1
        row = max(row, trimmed.height)
    assert y + row <= ATLAS_W, "atlas too small"

    png = io.BytesIO()
    atlas.save(png, "PNG")
    png = png.getvalue()
    out = bytearray(b"PZPK") + struct.pack("<ii", 1, 1)
    out += lp_string(f"{PACK}0") + struct.pack("<ii", len(entries), 1)
    for name, *nums in entries:
        out += lp_string(name) + struct.pack("<8i", *nums)
    out += struct.pack("<i", len(png)) + png
    os.makedirs(os.path.join(media, "texturepacks"), exist_ok=True)
    with open(os.path.join(media, "texturepacks", f"{PACK}.pack"), "wb") as f:
        f.write(out)


def main():
    sprites, media = sys.argv[1:3]
    os.makedirs(media, exist_ok=True)
    write_tiledefs(media)
    write_pack(os.path.join(sprites, f"{TILESET}.png"), media)
    for folder, name in (("depthmaps", f"DEPTH_{TILESET}.png"), ("textures", "Item_WindowAC.png")):
        os.makedirs(os.path.join(media, folder), exist_ok=True)
        shutil.copy(os.path.join(sprites, name), os.path.join(media, folder))
    print("packed", media)


if __name__ == "__main__":
    main()

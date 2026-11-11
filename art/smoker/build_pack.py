"""Package the tile sheet for the game: texture pack, tile definitions, depth map, icons.

  python build_pack.py <sprites_dir> <mod_dir>      (mod_dir = ../../VitalityAppliances/42)

Writes, under mod_dir:
  media/texturepacks/BrickSmoker.pack             PZPK v1: every tile trimmed onto one atlas page
  media/BrickSmoker_tiledefinitions.tiles         tdef v1 binary, the file the game reads
  media/BrickSmoker_tiledefinitions.tiles.txt     the same as text, for reading and TileZed
  media/depthmaps/DEPTH_crafted_smoker_01.png
  media/textures/Item_BrickSmoker.png, Build_BrickSmoker.png
  media/ui/Container_Smoker.png

The mod's own icon.png shows both appliances and is drawn by
workshop/appliances/make_images.py, from sprites/icon.png here and the slow cooker's.

The formats are the slow cooker's (read from the game's own files). Properties follow
the vanilla stone cabinet (crafted_04_40): a built masonry object with a container,
not movable. Tiles 0-3 face E, S, W, N; 4-7 are the same views lit, drawn over them.
"""
import io
import os
import shutil
import struct
import sys

from PIL import Image

TILESET = "crafted_smoker_01"
TILE_W, TILE_H = 128, 256
FACINGS = ["E", "S", "W", "N"]
ATLAS_W = 1024


def smoker_props(facing):
    return [
        ("BlocksPlacement", ""), ("ContainerCapacity", "20"), ("CustomName", "Smoker"),
        ("Facing", facing), ("GroupName", "Brick"), ("Material", "Stone"), ("ScrapSize", "Small"),
        ("ScrapUseSkill", ""), ("container", "smoker"), ("solidtrans", ""),
    ]


def tiles():
    return [smoker_props(f) for f in FACINGS] + [[] for _ in FACINGS]


def write_tiledefs(media):
    data = tiles()
    out = bytearray(b"tdef")
    out += struct.pack("<ii", 1, 1)
    out += f"{TILESET}\n{TILESET}.png\n".encode("latin1")
    out += struct.pack("<iiii", 8, 1, 1, len(data))
    for props in data:
        out += struct.pack("<i", len(props))
        for k, v in props:
            out += f"{k}\n{v}\n".encode("latin1")
    with open(os.path.join(media, "BrickSmoker_tiledefinitions.tiles"), "wb") as f:
        f.write(out)

    lines = ["version = 1", "tileset", "{", f"    file = {TILESET}", "    size = 8,1", "    id = 1"]
    for i, props in enumerate(data):
        lines += [f"    // {TILESET}_{i}", "    tile", "    {", f"        xy = {i},0"]
        lines += [f"        {k} = {v}" for k, v in props]
        lines.append("    }")
    lines.append("}")
    with open(os.path.join(media, "BrickSmoker_tiledefinitions.tiles.txt"), "w", newline="\r\n") as f:
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
    out += lp_string("BrickSmoker0") + struct.pack("<ii", len(entries), 1)
    for name, *nums in entries:
        out += lp_string(name) + struct.pack("<8i", *nums)
    out += struct.pack("<i", len(png)) + png
    os.makedirs(os.path.join(media, "texturepacks"), exist_ok=True)
    with open(os.path.join(media, "texturepacks", "BrickSmoker.pack"), "wb") as f:
        f.write(out)


def main():
    sprites, mod = sys.argv[1:3]
    media = os.path.join(mod, "media")
    os.makedirs(media, exist_ok=True)
    write_tiledefs(media)
    write_pack(os.path.join(sprites, f"{TILESET}.png"), media)
    os.makedirs(os.path.join(media, "depthmaps"), exist_ok=True)
    shutil.copy(os.path.join(sprites, f"DEPTH_{TILESET}.png"), os.path.join(media, "depthmaps"))
    os.makedirs(os.path.join(media, "textures"), exist_ok=True)
    for name in ("Item_BrickSmoker", "Build_BrickSmoker"):
        shutil.copy(os.path.join(sprites, f"{name}.png"), os.path.join(media, "textures"))
    os.makedirs(os.path.join(media, "ui"), exist_ok=True)
    shutil.copy(os.path.join(sprites, "Item_BrickSmoker.png"), os.path.join(media, "ui", "Container_Smoker.png"))
    print("packed", mod)


if __name__ == "__main__":
    main()

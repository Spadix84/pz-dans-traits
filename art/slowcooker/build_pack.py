"""Package the tile sheet for the game: texture pack, tile definitions, depth map.

  python build_pack.py <sprites_dir> <mod_media_dir>      (../../VitalityAppliances/42/media)

Writes:
  texturepacks/SlowCooker.pack       PZPK v1: every tile trimmed onto one atlas page
  SlowCooker_tiledefinitions.tiles   tdef v1 binary, the file the game reads
  SlowCooker_tiledefinitions.tiles.txt   the same as text, for reading and TileZed
  depthmaps/DEPTH_appliances_slowcooker_01.png

Both binary formats were read from the game's own files and a shipped Build 42 tile
mod. Properties are the vanilla microwave's, minus its light and microwave flag.
"""
import io
import os
import shutil
import struct
import sys

from PIL import Image

TILESET = "appliances_slowcooker_01"
TILE_W, TILE_H = 128, 256
FACINGS = ["E", "S", "W", "N"]  # vanilla microwave order
ATLAS_W = 512


def moveable_props(facing):
    return [
        ("BlocksPlacement", ""), ("CanScrap", ""), ("ContainerCapacity", "10"),
        ("CustomItem", "Base.Mov_SlowCooker"), ("CustomName", "Slow Cooker"),
        ("Facing", facing), ("GroupName", "Harvest"), ("IsMoveAble", ""),
        ("IsSurfaceOffset", ""), ("IsTableTop", ""), ("IsoType", "IsoStove"),
        ("ItemHeight", "15"), ("Material", "MetalScrap"), ("Material2", "Electric"),
        ("MaterialType", "Metal_Light"), ("PickUpWeight", "50"), ("ScrapSize", "Small"),
        ("Surface", "34"), ("attachedSurface", ""), ("container", "slowcooker"),
    ]


def tiles():
    """Tiles 0-3 are the placeable cooker; 4-7 are drawn over them while it runs."""
    return [moveable_props(f) for f in FACINGS] + [[] for _ in FACINGS]


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
    with open(os.path.join(media, "SlowCooker_tiledefinitions.tiles"), "wb") as f:
        f.write(out)

    lines = ["version = 1", "tileset", "{", f"    file = {TILESET}", "    size = 8,1", "    id = 1"]
    for i, props in enumerate(data):
        lines += [f"    // {TILESET}_{i}", "    tile", "    {", f"        xy = {i},0"]
        lines += [f"        {k} = {v}" for k, v in props]
        lines.append("    }")
    lines.append("}")
    with open(os.path.join(media, "SlowCooker_tiledefinitions.tiles.txt"), "w", newline="\r\n") as f:
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
    out += lp_string("SlowCooker0") + struct.pack("<ii", len(entries), 1)
    for name, *nums in entries:
        out += lp_string(name) + struct.pack("<8i", *nums)
    out += struct.pack("<i", len(png)) + png
    os.makedirs(os.path.join(media, "texturepacks"), exist_ok=True)
    with open(os.path.join(media, "texturepacks", "SlowCooker.pack"), "wb") as f:
        f.write(out)


def main():
    sprites, media = sys.argv[1:3]
    os.makedirs(media, exist_ok=True)
    write_tiledefs(media)
    write_pack(os.path.join(sprites, f"{TILESET}.png"), media)
    os.makedirs(os.path.join(media, "depthmaps"), exist_ok=True)
    shutil.copy(os.path.join(sprites, f"DEPTH_{TILESET}.png"), os.path.join(media, "depthmaps"))
    print("packed", media)


if __name__ == "__main__":
    main()

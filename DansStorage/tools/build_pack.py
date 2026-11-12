"""Package Dan's Storage's tile sheets for the game: texture pack, tile definitions, depth maps.

  python DansStorage/tools/build_pack.py

Reads the sprite sheets the art scripts wrote (art/storage/sprites/<shelf>) and writes into
DansStorage/42/media:
  texturepacks/DansStorage.pack            PZPK v1: every tile trimmed onto one atlas page
  DansStorage_tiledefinitions.tiles        tdef v1 binary, the file the game reads
  DansStorage_tiledefinitions.tiles.txt    the same as text, for reading and TileZed
  depthmaps/DEPTH_<tileset>.png            one per tileset
  textures/Build_DansStorage<Shelf>.png    the build-menu icons

mod.info names them: pack=DansStorage, tiledef=DansStorage_tiledefinitions 6744 (6742 is
the Slow Cooker's, 6743 Climate Control's; no installed mod uses 6744). The formats are
DansClimate/tools/build_pack.py's. A tileset keeps its id for good: saved objects name
their tile by file number, tileset id and position.

storage_waterjugrack_01 (id 1), storage_gascanshelf_01 (id 2), storage_propaneshelf_01
(id 3): the same layout, three rows of eight. Row 0 (tiles 0-7) is the shelf, two tiles
for each facing in the order of vanilla's own two-tile shelves (crafted_05_48/49): S west
then east, E south then north, N west then east, W south then north, with the grid
position each tile has in the whole (SpriteGridPos). They are a vanilla two-tile
moveable: GroupName + CustomName + Facing tie the two together, like the game's Large
Metal Shelves, and each tile is its own container. Like every vanilla two-tile piece
they carry no facing offsets: the facing is chosen when it is built, and the furniture
tools pick it up and put it down as it is.
Rows 1 (8-15) and 2 (16-23) are the same tiles half full and full, without properties:
the mod draws them over a shelf tile as it fills (lua/shared/DansStorage_Shelves.lua).
"""
import io
import os
import shutil
import struct

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
MEDIA = os.path.join(REPO, "DansStorage", "42", "media")
ART = os.path.join(REPO, "art", "storage", "sprites")
PACK = "DansStorage"
TILE_W, TILE_H = 128, 256
ATLAS_W = 2048

# the sheet's first row, as art/storage/make_sprites.py lays it out: facing, grid position
SHELF_TILES = [("S", "0,0"), ("S", "1,0"), ("E", "0,1"), ("E", "0,0"),
               ("N", "0,0"), ("N", "1,0"), ("W", "0,1"), ("W", "0,0")]

# shelf (the art folder), tileset id, GroupName, CustomName, container type, capacity,
# icon name. The Lua counts the items itself (lua/shared/DansStorage_Shelves.lua); the
# capacity has to let a full tile in (nine jugs, nine jerry cans of 4 + 20 litres, six tanks
# of 10; 160 was too little for nine full jugs in play) and matches KINDS in the Lua.
SHELVES = [
    ("waterjugrack", 1, "Water Jug", "Rack", "waterjugrack", 200, "WaterJugRack"),
    ("gascanshelf", 2, "Gas Can", "Shelf", "gascanshelf", 220, "GasCanShelf"),
    ("propaneshelf", 3, "Propane", "Shelf", "propaneshelf", 70, "PropaneShelf"),
]


def shelf_props(group, custom, container, capacity, facing, grid):
    return sorted([
        ("BlocksPlacement", ""), ("CanBreak", ""), ("CanScrap", ""),
        ("ContainerCapacity", str(capacity)),
        ("ContainerPutSound", "ShelfMetalTransferItem"), ("ContainerTakeSound", "ShelfMetalTransferItem"),
        ("CustomName", custom), ("Facing", facing), ("GroupName", group), ("IsMoveAble", ""),
        ("ItemHeight", "100"), ("Material", "MetalBars"), ("Material2", "MetalPlates"),
        ("MaterialType", "Metal_Light"), ("PickUpLevel", "2"), ("PickUpWeight", "150"),
        ("SpriteGridPos", grid), ("container", container), ("solidtrans", ""),
    ])


TILESETS = [
    # name, id in the tile definitions file, the folder its sheet is in, columns, each tile's properties
    (f"storage_{shelf}_01", tid, os.path.join(ART, shelf), 8,
     [shelf_props(group, custom, container, capacity, f, g) for f, g in SHELF_TILES] + [[] for _ in range(16)])
    for shelf, tid, group, custom, container, capacity, _ in SHELVES
]

def write_tiledefs(media):
    out = bytearray(b"tdef")
    out += struct.pack("<ii", 1, len(TILESETS))
    lines = ["version = 1"]
    for name, tileset_id, _, columns, tiles in TILESETS:
        rows = len(tiles) // columns
        assert rows * columns == len(tiles), f"{name}: {len(tiles)} tiles don't fill rows of {columns}"
        out += f"{name}\n{name}.png\n".encode("latin1")
        out += struct.pack("<iiii", columns, rows, tileset_id, len(tiles))
        lines += ["tileset", "{", f"    file = {name}", f"    size = {columns},{rows}", f"    id = {tileset_id}"]
        for i, p in enumerate(tiles):
            out += struct.pack("<i", len(p))
            for k, v in p:
                out += f"{k}\n{v}\n".encode("latin1")
            lines += [f"    // {name}_{i}", "    tile", "    {", f"        xy = {i % columns},{i // columns}"]
            lines += [f"        {k} = {v}" for k, v in p]
            lines.append("    }")
        lines.append("}")
    with open(os.path.join(media, f"{PACK}_tiledefinitions.tiles"), "wb") as f:
        f.write(out)
    with open(os.path.join(media, f"{PACK}_tiledefinitions.tiles.txt"), "w", newline="\r\n") as f:
        f.write("\n".join(lines) + "\n")


def lp_string(s):
    b = s.encode("latin1")
    return struct.pack("<i", len(b)) + b


def write_pack(media):
    atlas = Image.new("RGBA", (ATLAS_W, ATLAS_W), (0, 0, 0, 0))
    x = y = row = 0
    entries = []
    for name, _, folder, columns, tiles in TILESETS:
        sheet = Image.open(os.path.join(folder, f"{name}.png")).convert("RGBA")
        assert sheet.width // TILE_W == columns and sheet.height // TILE_H == len(tiles) // columns, \
            f"{name}: the sheet and the tile list differ"
        for i in range(len(tiles)):
            col, line = i % columns, i // columns
            tile = sheet.crop((col * TILE_W, line * TILE_H, (col + 1) * TILE_W, (line + 1) * TILE_H))
            box = tile.getbbox()
            if box is None:
                continue
            trimmed = tile.crop(box)
            if x + trimmed.width > ATLAS_W:
                x, y, row = 0, y + row + 1, 0
            atlas.paste(trimmed, (x, y))
            entries.append((f"{name}_{i}", x, y, trimmed.width, trimmed.height, box[0], box[1], TILE_W, TILE_H))
            x += trimmed.width + 1
            row = max(row, trimmed.height)
    assert y + row <= ATLAS_W, "atlas too small"
    # crop the page to what it uses, rounded up to a power of two in height
    used = y + row
    height = 1
    while height < used:
        height *= 2
    atlas = atlas.crop((0, 0, ATLAS_W, height))

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
    return len(entries)


def build_icon(shelf):
    """A build-menu icon: the full shelf from the 3/4 preview, fitted into 32x32."""
    src = Image.open(os.path.join(ART, shelf, "preview.png")).convert("RGBA")
    # the preview has a grey backdrop: key it out by the corner colour
    bg = src.getpixel((2, 2))
    px = src.load()
    for yy in range(src.height):
        for xx in range(src.width):
            r, g, b, _ = px[xx, yy]
            if abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2]) < 18:
                px[xx, yy] = (0, 0, 0, 0)
    src = src.crop(src.getbbox())
    src.thumbnail((32, 32), Image.LANCZOS)
    icon = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    icon.paste(src, ((32 - src.width) // 2, (32 - src.height) // 2))
    return icon


def main():
    os.makedirs(MEDIA, exist_ok=True)
    write_tiledefs(MEDIA)
    count = write_pack(MEDIA)
    os.makedirs(os.path.join(MEDIA, "depthmaps"), exist_ok=True)
    for name, _, folder, _, _ in TILESETS:
        shutil.copy(os.path.join(folder, f"DEPTH_{name}.png"), os.path.join(MEDIA, "depthmaps"))
    os.makedirs(os.path.join(MEDIA, "textures"), exist_ok=True)
    for shelf, *_, icon in SHELVES:
        build_icon(shelf).save(os.path.join(MEDIA, "textures", f"Build_DansStorage{icon}.png"))
    print(f"packed {count} tiles in {len(TILESETS)} tilesets into {os.path.relpath(MEDIA, REPO)}")


if __name__ == "__main__":
    main()

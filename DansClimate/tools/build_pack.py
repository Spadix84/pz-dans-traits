"""Package the mod's tile sheets for the game: texture pack, tile definitions, depth maps.

  python DansClimate/tools/build_pack.py

Reads the sprite sheets the art scripts wrote (art/windowac/sprites, art/spaceheater/sprites,
art/hvac/sprites) and writes into DansClimate/42/media:
  texturepacks/DansClimate.pack            PZPK v1: every tile trimmed onto one atlas page
  DansClimate_tiledefinitions.tiles        tdef v1 binary, the file the game reads
  DansClimate_tiledefinitions.tiles.txt    the same as text, for reading and TileZed
  depthmaps/DEPTH_<tileset>.png            one per tileset
  textures/Item_*.png                      inventory icons: the window air conditioner, the
                                           furnace, the central air conditioner
  textures/Build_DansClimate*.png          build-menu icons for the furnace, the central air
                                           conditioner and the vent

mod.info names them: pack=DansClimate, tiledef=DansClimate_tiledefinitions 6743 (6742 is
the Slow Cooker's; no installed mod uses 6743). The formats are the Slow Cooker's
art/build_pack.py, which read them from the game's own files. A tileset keeps its id
for good: saved objects name their tile by file number, tileset id and position.

appliances_windowac_01 (id 1). Tiles 0-3 are the unit switched off, facing S, E, N, W;
4-7 the same switched on. The facing is the way the front grille points, the room's
side. The object always sits on the window's own square: S and N on a window in the
square's north edge (attachedN, like vanilla curtains and the wall AC), E and W in its
west edge (attachedW). It is not a vanilla moveable (no IsMoveAble): the mod's own
install and remove actions place and take it, so the game's pick-up and place cursor
can't put it anywhere but a window.

appliances_spaceheater_01 (id 2). Tiles 0-3 are the heater, facing S, E, N, W: a
vanilla moveable (IsMoveAble, item Base.Mov_SpaceHeater), so the game's own furniture
tools pick it up, place it and turn it. 4-7 are the same views with the elements
glowing, and carry no properties: the mod draws them over 0-3 while it runs.

appliances_hvac_01 (id 3), three rows of eight. 0-3 the furnace and 8-11 the central air
conditioner's outdoor unit, facing S, E, N, W: both block their square. 4-7 and 12-15 are
the same views working (a lit lamp, a spinning fan), without properties: the mod draws
them over a working unit. 16-17 the vent, a floor register two ways round, which blocks
nothing. 18-23 are empty. All three are built from the build menu
(scripts/DansClimate_entities.txt), not moveables.
"""
import io
import os
import shutil
import struct

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
MEDIA = os.path.join(REPO, "DansClimate", "42", "media")
PACK = "DansClimate"
TILE_W, TILE_H = 128, 256
FACINGS = ["S", "E", "N", "W"]   # the sheet order both make_sprites.py write
ATLAS_W = 1024


def windowac_props(facing):
    edge = "attachedN" if facing in ("S", "N") else "attachedW"
    return [
        ("CustomName", "Window Air Conditioner"), ("Facing", facing),
        ("Material", "MetalScrap"), ("Material2", "Electric"),
        ("MaterialType", "Metal_Light"), (edge, ""),
    ]


def spaceheater_props(facing):
    return [
        ("CanScrap", ""), ("CustomItem", "Base.Mov_SpaceHeater"), ("CustomName", "Space Heater"),
        ("Facing", facing), ("IsMoveAble", ""), ("Material", "MetalScrap"), ("Material2", "Electric"),
        ("MaterialType", "Metal_Light"), ("PickUpWeight", "60"), ("ScrapSize", "Small"),
    ]


def central_props(name, facing):
    return [
        ("BlocksPlacement", ""), ("CustomName", name), ("Facing", facing),
        ("Material", "MetalScrap"), ("Material2", "Electric"), ("MaterialType", "Metal_Light"),
        ("solidtrans", ""),
    ]


HVAC = os.path.join(REPO, "art", "hvac", "sprites")
NONE = [[] for _ in FACINGS]
# name, id in the tile definitions file, the folder its sheet is in, columns in the sheet,
# each tile's properties (row by row)
TILESETS = [
    ("appliances_windowac_01", 1, os.path.join(REPO, "art", "windowac", "sprites"), 8,
     [windowac_props(f) for f in FACINGS] * 2),
    ("appliances_spaceheater_01", 2, os.path.join(REPO, "art", "spaceheater", "sprites"), 8,
     [spaceheater_props(f) for f in FACINGS] + NONE),
    ("appliances_hvac_01", 3, HVAC, 8,
     [central_props("Furnace", f) for f in FACINGS] + NONE
     + [central_props("Central Air Conditioner", f) for f in FACINGS] + NONE
     + [[("CustomName", "Vent")], [("CustomName", "Vent")]] + [[] for _ in range(6)]),
]
ICONS = [
    # source, the name it gets in media/textures
    (os.path.join(REPO, "art", "windowac", "sprites", "Item_WindowAC.png"), "Item_WindowAC.png"),
    (os.path.join(HVAC, "Item_HVACFurnace.png"), "Item_HVACFurnace.png"),
    (os.path.join(HVAC, "Item_HVACCondenser.png"), "Item_HVACCondenser.png"),
    (os.path.join(HVAC, "Item_HVACFurnace.png"), "Build_DansClimateFurnace.png"),
    (os.path.join(HVAC, "Item_HVACCondenser.png"), "Build_DansClimateCentralAC.png"),
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
                continue   # an empty tile: nothing to draw, so nothing in the pack
            trimmed = tile.crop(box)
            if x + trimmed.width > ATLAS_W:
                x, y, row = 0, y + row + 1, 0
            atlas.paste(trimmed, (x, y))
            entries.append((f"{name}_{i}", x, y, trimmed.width, trimmed.height, box[0], box[1], TILE_W, TILE_H))
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
    return len(entries)


def vent_icon():
    """The vent's build-menu icon: its own tile, trimmed and scaled up into 32x32."""
    sheet = Image.open(os.path.join(HVAC, "appliances_hvac_01.png")).convert("RGBA")
    tile = sheet.crop((0, 2 * TILE_H, TILE_W, 3 * TILE_H))   # tile 16
    vent = tile.crop(tile.getbbox())
    scale = min(30 / vent.width, 30 / vent.height)
    vent = vent.resize((max(1, round(vent.width * scale)), max(1, round(vent.height * scale))), Image.NEAREST)
    icon = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    icon.paste(vent, ((32 - vent.width) // 2, (32 - vent.height) // 2))
    return icon


def main():
    os.makedirs(MEDIA, exist_ok=True)
    write_tiledefs(MEDIA)
    count = write_pack(MEDIA)
    os.makedirs(os.path.join(MEDIA, "depthmaps"), exist_ok=True)
    for name, _, folder, _, _ in TILESETS:
        shutil.copy(os.path.join(folder, f"DEPTH_{name}.png"), os.path.join(MEDIA, "depthmaps"))
    os.makedirs(os.path.join(MEDIA, "textures"), exist_ok=True)
    for icon, name in ICONS:
        shutil.copy(icon, os.path.join(MEDIA, "textures", name))
    vent_icon().save(os.path.join(MEDIA, "textures", "Build_DansClimateVent.png"))
    print(f"packed {count} tiles in {len(TILESETS)} tilesets into {os.path.relpath(MEDIA, REPO)}")


if __name__ == "__main__":
    main()

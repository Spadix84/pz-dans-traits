"""Draws the art of Spiffo Walk: the screen masks and the colour label.

    python VitalityCartridges/tools/make_spiffo_walk_art.py [--preview <png>]

Writes into VitalityCartridges/42/media/ui/VitalityCartridges/Games/SpiffoWalk/:
    spiffo.png  a layered sheet (four rows, darkest first) of 32x32 cells: the egg (whole, cracked,
                about to hatch), then stand, blink, left foot up and right foot up for each of
                hatched, pup, grown and elder (the hatched one rocks its shell instead)
    hats.png    a layered sheet of eight 16x10 cells, the treasures, in the order of HATS in Game.lua
    icons.png   a white mask of 8x8 cells: a heart, a paw print, a star
    ground.png  a white mask of 360x8: grass and pebbles, the same 180 pixels twice, so any
                180 wide window of it tiles as the ground scrolls
    label.png   the 388x212 colour label of the cartridge (cartridge_label.py turns it into the
                model texture and the icon)
The masks are plain white on transparent, every pixel fully one or the other, as the console
needs (SDK docs/03-screen-and-art.md). --preview also writes the sheets in the four shades, scaled
up, to look at. The cell sizes and the hat rows printed at the end are the ones Game.lua draws with.
"""
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, "..", "42", "media", "ui", "VitalityCartridges", "Games", "SpiffoWalk")

CELL = 32
HAT_W, HAT_H = 16, 10
ICON = 8
GROUND_W, GROUND_H = 360, 8
WHITE = (255, 255, 255, 255)
# the four shades of the screen, darkest first (for the preview and the label's Spiffo)
SHADES = [(28, 36, 32), (72, 86, 78), (112, 128, 118), (156, 168, 160)]


def mirror(half):
    """A row from its left half: the right half is the left one turned round."""
    return half + half[::-1]


def rows_of(halves):
    return [mirror(h) for h in halves]


def overlay(rows, extra):
    """Puts the pixels of extra (same size, '.' leaves the pixel) over rows."""
    out = []
    for row, add in zip(rows, extra):
        out.append("".join(a if a != "." else r for r, a in zip(row, add)))
    return out


# Each sprite is a list of rows of characters: '.' transparent, '1'..'4' a shade (1 darkest),
# 'w' the white of an eye (shade 4, shade 1 while blinking).

# the egg, 16 wide, 20 high: three cells, whole, cracked, about to hatch
EGG = [
    "......1111......",
    "....11333311....",
    "...1333333331...",
    "..133233333331..",
    "..133333332331..",
    ".13333333333331.",
    ".13323333333331.",
    ".13333333323331.",
    "1333333333333331",
    "1333332333333331",
    "1333333333332331",
    "1323333333333331",
    "1333333333333331",
    "1333333233333331",
    ".13333333333231.",
    ".12333333333321.",
    "..123333333321..",
    "...1223333221...",
    "....11222211....",
    "......1111......",
]
CRACK_1 = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "........1.......",
    ".......1.1......",
    "......1...1.....",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
]
CRACK_2 = [
    "................",
    "................",
    "................",
    "................",
    "........1.......",
    ".......1........",
    "....1..11.......",
    ".....11.1.1.....",
    "......1...11.1..",
    "...........1.1..",
    "............1...",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
]

# hatched: a small Spiffo still sitting in the bottom of its shell, 16 wide, 18 high
HATCHED = rows_of([
    "..11....",
    ".1221...",
    ".122111.",
    "11333333",
    "13333333",
    "13111113",
    "111ww111",
    "11w11113",
    "13111113",
    "13333444",
    ".1333441",
    ".1333133",
    "14131413",
    "14414441",
    "14444444",
    ".1444444",
    "..144444",
    "...11111",
])

# the pup: 20 wide, 22 high
PUP_TOP = rows_of([
    "..11......",
    ".1221.....",
    ".12221....",
    ".12221111.",
    "1123333333",
    "1333333333",
    "1311111133",
    "111ww11113",
    "11w1111113",
    "1311111133",
    "1333334444",
    ".133344441",
    "..13334444",
    "...1111111",
    "....133333",
    "...1233344",
    "...1233344",
    "....133344",
    "....133333",
])
PUP_LEGS = rows_of([
    ".....13311",
    ".....131..",
    ".....11...",
])
PUP_TAIL = [
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "...................1",
    "..................13",
    "................1.11",
    "................1131",
    "................1311",
    "................111.",
    "....................",
    "....................",
    "....................",
]

# grown: 24 wide, 30 high
GROWN_TOP = rows_of([
    "..11........",
    ".1221.......",
    ".12221......",
    ".122221.....",
    ".12222111111",
    "112333333333",
    "133333333333",
    "133333333333",
    "131111111333",
    "111ww1111133",
    "11ww11111133",
    "11w111111133",
    "131111111333",
    "133333334444",
    "133333344441",
    ".13333344444",
    "..1133333333",
    "....11111111",
    "....13333333",
    "...123333444",
    "..1223334444",
    "..1223334444",
    "..1223334444",
    "..1133334444",
    "...133333444",
    "...133333333",
    "....13333333",
])
GROWN_LEGS = rows_of([
    "....13331111",
    "....1331....",
    "....1111....",
])
GROWN_TAIL = [
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "......................11",
    ".....................131",
    "....................1311",
    "...................11131",
    "...................13311",
    "...................11131",
    "...................13311",
    "....................1131",
    "....................111.",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
]
# the elder: grown, with white brows and whiskers, and a walking stick in the left hand
ELDER_EXTRA = [
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "..444..........444......",
    ".44444........44444.....",
    "........................",
    "........................",
    "........................",
    "........................",
    ".4..................4...",
    "..4................4....",
    "........................",
    "........................",
    "........................",
    "........................",
    ".1......................",
    ".1......................",
    ".1......................",
    ".1......................",
    ".1......................",
    ".1......................",
    ".1......................",
    ".1......................",
    ".1......................",
    ".1......................",
    ".1......................",
]


def lifted(legs, left):
    """The legs with one foot lifted a row: the left foot, or the right one."""
    w = len(legs[0])
    half = w // 2
    blank = "." * w

    def side(row):
        return row[:half] if left else row[half:]

    def join(row, part):
        return part + row[half:] if left else row[:half] + part

    out = [join(legs[0], side(overlay([legs[0]], [legs[1]])[0])),
           join(legs[1], side(legs[2])),
           join(legs[2], side(blank))]
    return out


def stage_frames(top, legs, tail, extra=None):
    """The stand, blink and two step frames of a stage: the body, the legs, the tail."""
    frames = [overlay(top + legs, tail), None,
              overlay(top + lifted(legs, True), tail), overlay(top + lifted(legs, False), tail)]
    if extra:
        frames = [f and overlay(f, extra) for f in frames]
    frames[1] = [row.replace("w", "1") for row in frames[0]]
    return frames


def egg_frames():
    return [EGG, overlay(EGG, CRACK_1), overlay(EGG, CRACK_2)]


def hatched_frames():
    blink = [row.replace("w", "1") for row in HATCHED]
    # the steps: the shell rocks a pixel right, then left, under the head
    right = HATCHED[:11] + ["." + row[:-1] for row in HATCHED[11:]]
    left = HATCHED[:11] + [row[1:] + "." for row in HATCHED[11:]]
    return [HATCHED, blink, right, left]


# the order of the cells in spiffo.png
SPRITES = (
    egg_frames()
    + hatched_frames()
    + stage_frames(PUP_TOP, PUP_LEGS, PUP_TAIL)
    + stage_frames(GROWN_TOP, GROWN_LEGS, GROWN_TAIL)
    + stage_frames(GROWN_TOP, GROWN_LEGS, GROWN_TAIL, ELDER_EXTRA)
)
STAGE_NAMES = ["egg", "hatched", "pup", "grown", "elder"]

# the treasures, 16x10 each, in the order of HATS in Game.lua; the bottom row sits on the head
HATS = {
    "TopHat": [
        "....11111111....",
        "....12222221....",
        "....12222221....",
        "....12222221....",
        "....12222221....",
        "....14444441....",
        "....12222221....",
        "..111111111111..",
        "..122222222221..",
        "..111111111111..",
    ],
    "Party": [
        ".......44.......",
        "......4334......",
        ".......11.......",
        "......1331......",
        "......1221......",
        ".....133331.....",
        ".....122221.....",
        "....13333331....",
        "....12222221....",
        "...1111111111...",
    ],
    "Crown": [
        "................",
        "................",
        "..1....11....1..",
        ".141..1441..141.",
        ".1431.1441.1341.",
        ".14431344313441.",
        ".14444444444441.",
        ".12121212121211.",
        ".14444444444441.",
        ".11111111111111.",
    ],
    "Bobble": [
        "......1111......",
        ".....144441.....",
        "......1441......",
        "....11111111....",
        "...1222222221...",
        "..122232222221..",
        "..122222232221..",
        "..111111111111..",
        "..131313131311..",
        "..111111111111..",
    ],
    "Cowboy": [
        "................",
        "................",
        ".....11..11.....",
        "....12211221....",
        "....12222221....",
        "....12222221....",
        "....11111111....",
        "11..12222221..11",
        "1211111111111121",
        ".11222222222211.",
    ],
    "Chef": [
        "...1111.1111....",
        "..144441444411..",
        ".14444444444441.",
        ".14444444444441.",
        "..144444444441..",
        "...1444444441...",
        "...1444444441...",
        "...1333333331...",
        "...1444444441...",
        "...1111111111...",
    ],
    "Cone": [
        ".......11.......",
        "......1221......",
        "......1441......",
        ".....144441.....",
        ".....122221.....",
        "....12222221....",
        "....14444441....",
        "...1222222221...",
        ".11111111111111.",
        ".12222222222221.",
    ],
    "Cap": [
        "................",
        "................",
        "................",
        ".....111111.....",
        "....12222221....",
        "...1224442221...",
        "...1224142221...",
        "...1222222222111",
        "...111111111111.",
        "................",
    ],
}
HAT_ORDER = ["TopHat", "Party", "Crown", "Bobble", "Cowboy", "Chef", "Cone", "Cap"]

ICONS = {
    "heart": [
        "........",
        ".11.11..",
        "1111111.",
        "1111111.",
        ".11111..",
        "..111...",
        "...1....",
        "........",
    ],
    "paw": [
        ".1...1..",
        "...1....",
        "1.....1.",
        "..111...",
        ".11111..",
        ".11111..",
        "..1.1...",
        "........",
    ],
    "star": [
        "...1....",
        "...1....",
        "1111111.",
        ".11111..",
        "..111...",
        ".11.11..",
        ".1...1..",
        "........",
    ],
}
ICON_ORDER = ["heart", "paw", "star"]


def shade_of(ch):
    if ch == "w":
        return 4
    if ch in "1234":
        return int(ch)
    return 0


def place(rows, w, h):
    """Centres a sprite at the bottom of a w x h cell; returns the cell's rows."""
    sh, sw = len(rows), len(rows[0])
    assert all(len(r) == sw for r in rows), "ragged sprite rows"
    assert sw <= w and sh <= h, "sprite larger than its cell"
    left = (w - sw) // 2
    top = h - sh
    cell = ["." * w for _ in range(h)]
    for y, row in enumerate(rows):
        line = cell[top + y]
        cell[top + y] = line[:left] + row + line[left + sw:]
    return cell


def layered(cells, w, h):
    """A layered sheet: the cells side by side, one row of the sheet per shade, darkest first."""
    img = Image.new("RGBA", (w * len(cells), h * 4), (0, 0, 0, 0))
    px = img.load()
    for i, rows in enumerate(cells):
        assert len(rows) == h and all(len(r) == w for r in rows)
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                s = shade_of(ch)
                if s:
                    px[i * w + x, (s - 1) * h + y] = WHITE
    return img


def mask(cells, w, h):
    img = Image.new("RGBA", (w * len(cells), h), (0, 0, 0, 0))
    px = img.load()
    for i, rows in enumerate(cells):
        assert len(rows) == h and all(len(r) == w for r in rows)
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch != ".":
                    px[i * w + x, y] = WHITE
    return img


def ground():
    """Grass tufts and pebbles on a ground line; the first 180 pixels repeated, so it tiles."""
    rng = random.Random(1987)
    half = GROUND_W // 2
    img = Image.new("RGBA", (GROUND_W, GROUND_H), (0, 0, 0, 0))
    px = img.load()
    x = 2
    while x < half - 4:
        kind = rng.choice(("tuft", "tuft", "pebble", "blade"))
        if kind == "tuft":
            for dx, top in ((0, 5), (1, 3), (2, 4), (3, 6)):
                for y in range(top, GROUND_H - 1):
                    px[(x + dx) % half, y] = WHITE
        elif kind == "pebble":
            for dx in range(3):
                px[(x + dx) % half, GROUND_H - 2] = WHITE
            px[(x + 1) % half, GROUND_H - 3] = WHITE
        else:
            for y in range(4, GROUND_H - 1):
                px[x % half, y] = WHITE
        x += rng.randint(9, 22)
    for x in range(half):
        px[x, GROUND_H - 1] = WHITE
        for y in range(GROUND_H):
            if px[x, y][3]:
                px[x + half, y] = WHITE
    return img


def hat_rows():
    """The first row of each stage's head (stand frame) in its cell: Game.lua sets the hats there."""
    out = []
    cells = [place(s, CELL, CELL) for s in SPRITES]
    for stage in range(5):
        cell = cells[0] if stage == 0 else cells[3 + (stage - 1) * 4]
        centre = [row[CELL // 2 - 2:CELL // 2 + 2] for row in cell]
        out.append(next(y for y, row in enumerate(centre) if row.strip(".")))
    return out


def preview(path, scale=6):
    """The sheets in the four shades on the paper shade, scaled up, to look at."""
    cells = [place(s, CELL, CELL) for s in SPRITES]
    hats = [place(HATS[k], HAT_W, HAT_H) for k in HAT_ORDER]
    w = CELL * 8
    rows = (len(cells) + 7) // 8
    img = Image.new("RGB", (w, CELL * rows + HAT_H + 4), SHADES[3])
    px = img.load()
    for i, cell in enumerate(cells):
        ox, oy = (i % 8) * CELL, (i // 8) * CELL
        for y, row in enumerate(cell):
            for x, ch in enumerate(row):
                s = shade_of(ch)
                if s:
                    px[ox + x, oy + y] = SHADES[s - 1]
    for i, hat in enumerate(hats):
        ox, oy = i * (HAT_W + 2), CELL * rows + 2
        for y, row in enumerate(hat):
            for x, ch in enumerate(row):
                s = shade_of(ch)
                if s and ox + x < w:
                    px[ox + x, oy + y] = SHADES[s - 1]
    img.resize((img.width * scale, img.height * scale), Image.NEAREST).save(path)


def font(size, bold=True):
    for name in (("georgiab.ttf" if bold else "georgia.ttf"), "segoeuib.ttf", "arialbd.ttf"):
        try:
            return ImageFont.truetype(os.path.join(os.environ.get("WINDIR", "C:/Windows"), "Fonts", name), size)
        except OSError:
            continue
    return ImageFont.load_default()


# Spiffo's colours on the label: the screen's shades turned into a warm grey raccoon
LABEL_COLOURS = {1: (40, 38, 44), 2: (104, 100, 108), 3: (168, 164, 170), 4: (246, 244, 236)}
HAT_COLOURS = {1: (40, 30, 34), 2: (196, 52, 60), 3: (232, 120, 110), 4: (250, 236, 210)}


def paste_pixels(img, rows, x0, y0, scale, colours):
    d = ImageDraw.Draw(img)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            s = shade_of(ch)
            if s:
                d.rectangle([x0 + x * scale, y0 + y * scale, x0 + (x + 1) * scale - 1, y0 + (y + 1) * scale - 1],
                            fill=colours[s])


def label():
    w, h = 388, 212
    img = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    d = ImageDraw.Draw(img)
    # a morning sky over a green verge
    for y in range(h):
        t = y / (h - 1)
        top, bottom = (120, 178, 214), (238, 214, 160)
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    d.ellipse([318, 12, 370, 64], fill=(252, 226, 130, 255))
    d.rectangle([0, 168, w, h], fill=(92, 148, 76, 255))
    # the path, and paw prints along it
    d.polygon([(0, 186), (w, 176), (w, 200), (0, 212)], fill=(196, 168, 120, 255))
    for i, x in enumerate(range(30, 250, 34)):
        y = 196 - i * 1 + (4 if i % 2 else -2)
        d.ellipse([x, y - 3, x + 9, y + 4], fill=(120, 92, 64, 255))
        for k in range(3):
            d.ellipse([x - 1 + k * 4, y - 8, x + 3 + k * 4, y - 4], fill=(120, 92, 64, 255))
    # Spiffo, grown, in a top hat, from the screen's own pixels
    grown = SPRITES[3 + 2 * 4]
    scale = 4
    sx, sy = 268, 186 - len(grown) * scale
    paste_pixels(img, grown, sx, sy, scale, LABEL_COLOURS)
    hat = HATS["TopHat"]
    head_top = next(y for y, row in enumerate(grown) if row[10:14].strip("."))
    hx = sx + (len(grown[0]) - HAT_W) // 2 * scale
    hy = sy + (head_top + 2 - HAT_H) * scale
    paste_pixels(img, hat, hx, hy, scale, HAT_COLOURS)
    f = font(46)
    for i, word in enumerate(("SPIFFO", "WALK")):
        d.text((24 + 2, 14 + i * 50 + 2), word, font=f, fill=(30, 44, 70, 255))
        d.text((24, 14 + i * 50), word, font=f, fill=(255, 250, 240, 255))
    sub = "walk, and watch him grow"
    f2 = font(19, bold=False)
    d.text((26, 124), sub, font=f2, fill=(30, 44, 70, 255))
    return img


def main():
    os.makedirs(ART, exist_ok=True)
    cells = [place(s, CELL, CELL) for s in SPRITES]
    layered(cells, CELL, CELL).save(os.path.join(ART, "spiffo.png"))
    hats = [place(HATS[k], HAT_W, HAT_H) for k in HAT_ORDER]
    layered(hats, HAT_W, HAT_H).save(os.path.join(ART, "hats.png"))
    mask([ICONS[k] for k in ICON_ORDER], ICON, ICON).save(os.path.join(ART, "icons.png"))
    ground().save(os.path.join(ART, "ground.png"))
    label().save(os.path.join(ART, "label.png"))
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1])
    print("written spiffo.png (%d cells of %d), hats.png (%d of %dx%d), icons.png, ground.png, label.png in %s"
          % (len(cells), CELL, len(hats), HAT_W, HAT_H, os.path.normpath(ART)))
    print("head rows by stage (%s): %s" % (", ".join(STAGE_NAMES), hat_rows()))


if __name__ == "__main__":
    main()

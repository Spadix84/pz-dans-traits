"""Draws the art of Spiffo Pup: the screen masks and the colour label.

    python VitalityCartridges/tools/make_spiffo_pup_art.py [--show]

Writes into VitalityCartridges/42/media/ui/VitalityCartridges/Games/SpiffoPup/:
    pup.png     a layered sheet (four rows, darkest first) of six 24x24 cells: idle, idle bobbing,
                eating, happy, sick, asleep (PUP_FRAMES)
    egg.png     a layered sheet of two 16x20 cells: the egg, the egg cracking
    mess.png    a layered sheet of one 12x10 cell: a mess on the floor
    bowl.png    a layered sheet of one 14x6 cell: the food bowl
    ball.png    a 6x6 white mask: the ball of the catch game
    label.png   the 388x212 colour label of the cartridge (cartridge_label.py turns it into the
                model texture, the icon and the poster)
The masks are plain white on transparent, every pixel fully one or the other, as the console
needs (SDK docs/03-screen-and-art.md). The sizes are the ones Game.lua draws with. --show prints
each pup frame in the terminal (# darkest, = , - , . lightest) to look the drawing over.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, "..", "42", "media", "ui", "VitalityCartridges", "Games", "SpiffoPup")

PUP = 24
PUP_FRAMES = ("idle", "bob", "eat", "happy", "sick", "asleep")
EGG_W, EGG_H = 16, 20
MESS_W, MESS_H = 12, 10
BOWL_W, BOWL_H = 14, 6
WHITE = (255, 255, 255, 255)

# Shade numbers per pixel (0 or "." transparent); 1 darkest .. 4 lightest.
#
# The pup is a raccoon kit sitting up, drawn as the left half of its head and body (mirrored
# into the right half) and a striped tail on its right. Its face is patched per frame: the
# eyes at columns 3-4 of rows 8-9 of the half, the mouth at columns 5-7 of rows 11-12.
HALF = [
    "........",
    "..111...",
    ".13331..",
    ".1322311",
    "13223333",
    "13333333",
    "13344433",
    "13111113",
    "13111113",
    "13111113",
    "13314441",
    "13344444",
    ".1334444",
    "..113444",
    "...13444",
    "..133444",
    "..131444",
    "..131444",
    "..131444",
    "..133444",
    "..133344",
    "..113333",
    "..13331.",
    "..11111.",
]
HALF_AT = 1          # the cell column of the half's first column

# the tail, from cell column 15, rows 8 to 21; drawn behind the body
TAIL_AT, TAIL_TOP = 15, 8
TAIL = [
    "......11.",
    ".....1111",
    ".....1331",
    "....13331",
    "....11111",
    "...13331.",
    "...11111.",
    "..13331..",
    "..11111..",
    ".13331...",
    ".11111...",
    "13331....",
    "1111.....",
]

# the eyes: (column, row) of the half -> shade
EYES = {
    "open": {(3, 8): 4, (4, 8): 4, (3, 9): 4, (4, 9): 1},
    "shut": {(3, 8): 1, (4, 8): 1, (3, 9): 3, (4, 9): 3},
    "glad": {(3, 8): 4, (4, 8): 4, (2, 9): 4, (5, 9): 4, (3, 9): 1, (4, 9): 1},
    "sick": {(3, 7): 4, (5, 7): 4, (4, 8): 4, (3, 9): 4, (5, 9): 4},
}
# the mouth: rows 11 and 12, columns 5 to 7 of the half
MOUTHS = {
    "plain": ("441", "414"),
    "eat": ("411", "412"),
    "glad": ("141", "411"),
    "sick": ("441", "141"),
}

# frame -> eyes, mouth, bobbing (the body one pixel lower, feet kept), fur shade
FRAMES = {
    "idle": ("open", "plain", False, 3),
    "bob": ("open", "plain", True, 3),
    "eat": ("shut", "eat", False, 3),
    "happy": ("glad", "glad", False, 3),
    "sick": ("sick", "sick", False, 2),
    "asleep": ("shut", "plain", True, 3),
}

EGG = [
    "......1111......",
    "....11444411....",
    "...1444444441...",
    "..144443344441..",
    "..144443344441..",
    ".14444444444441.",
    ".14334444444441.",
    ".14334444444441.",
    "1444444444433441",
    "1444444444433441",
    "1444444444444441",
    "1444433444444441",
    "1444433444444441",
    "1444444444444441",
    ".14444444443341.",
    ".14444444443341.",
    "..144444444441..",
    "...1444444441...",
    "....11444411....",
    "......1111......",
]
# the crack across the middle of the egg, (column, row)
CRACK = [(1, 9), (2, 10), (3, 9), (4, 8), (5, 9), (6, 10), (7, 9), (8, 8), (9, 9), (10, 10),
         (11, 9), (12, 8), (13, 9), (14, 10)]

MESS = [
    "...2...2....",
    "..2...2.....",
    "...2...2....",
    ".....11.....",
    "....1221....",
    "...122221...",
    "..11222211..",
    ".1222332221.",
    "122222222221",
    ".1111111111.",
]

BOWL = [
    "...3.33.3.3...",
    "..3333333333..",
    "11111111111111",
    "12222222222221",
    ".122222222221.",
    "..1111111111..",
]

BALL = [
    ".1111.",
    "111111",
    "111111",
    "111111",
    "111111",
    ".1111.",
]


def grid(rows, width, height):
    """A drawing as a list of lists of shades (0 transparent), checked for its size."""
    assert len(rows) == height and all(len(r) == width for r in rows), rows
    return [[int(ch) if ch in "1234" else 0 for ch in row] for row in rows]


def pup_frame(name):
    eyes, mouth, bob, fur = FRAMES[name]
    half = grid(HALF, 8, PUP)
    for (x, y), shade in EYES[eyes].items():
        half[y][x] = shade
    for i, row in enumerate(MOUTHS[mouth]):
        for j, ch in enumerate(row):
            half[11 + i][5 + j] = int(ch)
    cell = [[0] * PUP for _ in range(PUP)]
    for i, row in enumerate(grid(TAIL, 9, len(TAIL))):
        for j, shade in enumerate(row):
            if shade:
                cell[TAIL_TOP + i][TAIL_AT + j] = fur if shade == 3 else shade
    for y in range(PUP):
        for x in range(8):
            shade = half[y][x]
            if not shade:
                continue
            if shade == 3:
                shade = fur
            cell[y][HALF_AT + x] = shade
            cell[y][HALF_AT + 15 - x] = shade
    if bob:
        # everything above the feet one pixel lower: the rows 22 and 23 keep the feet
        feet = cell[23]
        cell = [[0] * PUP] + cell[:22] + [feet]
    return cell


def layered(cells, width, height):
    """A layered sheet: the cells side by side, one row of masks per shade, darkest first."""
    img = Image.new("RGBA", (width * len(cells), height * 4), (0, 0, 0, 0))
    px = img.load()
    for c, cell in enumerate(cells):
        assert len(cell) == height and all(len(r) == width for r in cell)
        for y, row in enumerate(cell):
            for x, shade in enumerate(row):
                if shade:
                    px[c * width + x, (shade - 1) * height + y] = WHITE
    return img


def mask(rows, width, height):
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    px = img.load()
    for y, row in enumerate(grid(rows, width, height)):
        for x, shade in enumerate(row):
            if shade:
                px[x, y] = WHITE
    return img


def egg_cells():
    whole = grid(EGG, EGG_W, EGG_H)
    cracked = [row[:] for row in whole]
    for x, y in CRACK:
        cracked[y][x] = 1
    return [whole, cracked]


def font(size, bold=True):
    for name in (("georgiab.ttf" if bold else "georgia.ttf"), "segoeuib.ttf", "arialbd.ttf"):
        try:
            return ImageFont.truetype(os.path.join(os.environ.get("WINDIR", "C:/Windows"), "Fonts", name), size)
        except OSError:
            continue
    return ImageFont.load_default()


def label():
    w, h = 388, 212
    img = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    d = ImageDraw.Draw(img)
    # a warm room: a soft wall over a wooden floor
    for y in range(h):
        t = y / (h - 1)
        top, bottom = (250, 214, 160), (236, 168, 112)
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    d.rectangle([0, 168, w, h], fill=(150, 96, 58, 255))
    for x in range(0, w, 48):
        d.line([(x, 168), (x - 20, h)], fill=(122, 76, 44, 255), width=2)
    # the pup's head, big, right of centre
    cx, cy = 258, 124
    grey, dark, light = (138, 134, 140, 255), (40, 36, 44, 255), (244, 240, 232, 255)
    for side in (-1, 1):
        ex = cx + side * 50
        d.ellipse([ex - 22, cy - 72, ex + 22, cy - 26], fill=grey, outline=dark, width=3)
        d.ellipse([ex - 11, cy - 60, ex + 11, cy - 36], fill=(214, 168, 170, 255))
    d.ellipse([cx - 74, cy - 54, cx + 74, cy + 52], fill=grey, outline=dark, width=3)
    d.ellipse([cx - 40, cy - 46, cx + 40, cy - 26], fill=light)
    d.rounded_rectangle([cx - 66, cy - 30, cx + 66, cy + 2], radius=16, fill=dark)
    for side in (-1, 1):
        ex = cx + side * 32
        d.ellipse([ex - 12, cy - 24, ex + 12, cy], fill=light)
        d.ellipse([ex - 6, cy - 18, ex + 6, cy - 4], fill=dark)
        d.ellipse([ex - 4, cy - 17, ex, cy - 12], fill=light)
    d.ellipse([cx - 34, cy - 2, cx + 34, cy + 46], fill=light)
    d.ellipse([cx - 10, cy - 2, cx + 10, cy + 12], fill=dark)
    d.arc([cx - 16, cy + 8, cx, cy + 26], 20, 160, fill=dark, width=3)
    d.arc([cx, cy + 8, cx + 16, cy + 26], 20, 160, fill=dark, width=3)
    # a bowl of food and the egg it came from
    d.ellipse([52, 158, 132, 176], fill=(200, 64, 56, 255), outline=(120, 30, 28, 255), width=2)
    d.rectangle([58, 150, 126, 166], fill=(200, 64, 56, 255))
    d.ellipse([58, 142, 126, 158], fill=(150, 96, 58, 255), outline=(120, 30, 28, 255), width=2)
    for x in range(66, 120, 10):
        d.ellipse([x, 144, x + 8, 152], fill=(196, 140, 80, 255))
    d.ellipse([344, 132, 380, 180], fill=(250, 246, 236, 255), outline=(150, 128, 110, 255), width=2)
    for (x, y) in ((354, 146), (366, 160), (356, 166)):
        d.ellipse([x, y, x + 7, y + 6], fill=(170, 200, 150, 255))
    title = "SPIFFO PUP"
    f = font(44)
    tw = d.textlength(title, font=f)
    d.text(((w - tw) / 2 + 2, 10 + 2), title, font=f, fill=(96, 48, 24, 255))
    d.text(((w - tw) / 2, 10), title, font=f, fill=(255, 250, 240, 255))
    f2 = font(18, bold=False)
    for i, line in enumerate(("feed it, play,", "keep it clean")):
        d.text((24, 66 + i * 22), line, font=f2, fill=(110, 60, 30, 255))
    return img


def show(cell):
    chars = {0: " ", 1: "#", 2: "=", 3: "-", 4: "."}
    for row in cell:
        print("".join(chars[s] * 2 for s in row))


def main():
    frames = [pup_frame(name) for name in PUP_FRAMES]
    if "--show" in sys.argv:
        for name, cell in zip(PUP_FRAMES, frames):
            print(name)
            show(cell)
        return
    os.makedirs(ART, exist_ok=True)
    layered(frames, PUP, PUP).save(os.path.join(ART, "pup.png"))
    layered(egg_cells(), EGG_W, EGG_H).save(os.path.join(ART, "egg.png"))
    layered([grid(MESS, MESS_W, MESS_H)], MESS_W, MESS_H).save(os.path.join(ART, "mess.png"))
    layered([grid(BOWL, BOWL_W, BOWL_H)], BOWL_W, BOWL_H).save(os.path.join(ART, "bowl.png"))
    mask(BALL, 6, 6).save(os.path.join(ART, "ball.png"))
    label().save(os.path.join(ART, "label.png"))
    print("written pup.png (%d cells of %d), egg.png, mess.png, bowl.png, ball.png, label.png in %s"
          % (len(frames), PUP, os.path.normpath(ART)))


if __name__ == "__main__":
    main()

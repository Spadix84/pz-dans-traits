"""Draws the art of First Aid Quiz: the screen masks and the colour label.

    python VitalityCartridges/tools/make_first_aid_quiz_art.py

Writes into VitalityCartridges/42/media/ui/VitalityCartridges/Games/FirstAidQuiz/:
    kit.png     a layered sheet (four rows, darkest first) of one 32x24 cell: the first aid
                kit on the title, drawn in shades 1, 2 and 4
    marks.png   three 11x11 cells, white mask: a tick (right), a cross (wrong), a plus (the
                medic's cross, on the summary)
    label.png   the 388x212 colour label of the cartridge (cartridge_label.py turns it into the
                model texture, the icon and the poster)
The masks are plain white on transparent, every pixel fully one or the other, as the console
needs (SDK docs/03-screen-and-art.md). The sizes are the ones Game.lua draws with.
"""
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, "..", "42", "media", "ui", "VitalityCartridges", "Games", "FirstAidQuiz")

KIT_W, KIT_H = 32, 24
MARK = 11
WHITE = (255, 255, 255, 255)

# the kit, as shade numbers per pixel (. transparent); 1 darkest .. 4 lightest
KIT = [
    "................................",
    "...........1111111111...........",
    "..........122222222221..........",
    "..........121111111121..........",
    "..........121......121..........",
    "..111111111211111111211111111...",
    ".12222222222222222222222222221..",
    ".12222222222222222222222222221..",
    ".12222222222224444222222222221..",
    ".12222222222224444222222222221..",
    ".12222222222224444222222222221..",
    ".12222222224444444444222222221..",
    ".12222222224444444444222222221..",
    ".12222222224444444444222222221..",
    ".12222222222224444222222222221..",
    ".12222222222224444222222222221..",
    ".12222222222224444222222222221..",
    ".12222222222222222222222222221..",
    ".11111111111111111111111111111..",
    ".12222222222222222222222222221..",
    ".12222222222222222222222222221..",
    "..1111111111111111111111111111..",
    "................................",
    "................................",
]

# the marks, one character per pixel (# set)
TICK = [
    "...........",
    "..........#",
    ".........##",
    "........##.",
    ".......##..",
    "#.....##...",
    "##...##....",
    ".##.##.....",
    "..###......",
    "...#.......",
    "...........",
]
CROSS = [
    "...........",
    ".##.....##.",
    "..##...##..",
    "...##.##...",
    "....###....",
    "....###....",
    "...##.##...",
    "..##...##..",
    ".##.....##.",
    "...........",
    "...........",
]
PLUS = [
    "...........",
    "....###....",
    "....###....",
    "....###....",
    ".#########.",
    ".#########.",
    ".#########.",
    "....###....",
    "....###....",
    "....###....",
    "...........",
]


def kit_sheet():
    img = Image.new("RGBA", (KIT_W, KIT_H * 4), (0, 0, 0, 0))
    px = img.load()
    assert len(KIT) == KIT_H and all(len(r) == KIT_W for r in KIT)
    for y, row in enumerate(KIT):
        for x, ch in enumerate(row):
            if ch in "1234":
                px[x, (int(ch) - 1) * KIT_H + y] = WHITE
    return img


def marks_sheet():
    img = Image.new("RGBA", (MARK * 3, MARK), (0, 0, 0, 0))
    px = img.load()
    for cell, rows in enumerate((TICK, CROSS, PLUS)):
        assert len(rows) == MARK and all(len(r) == MARK for r in rows)
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch == "#":
                    px[cell * MARK + x, y] = WHITE
    return img


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
    # a first aid card: warm white, a red band along the bottom
    d.rectangle([0, 0, w, h], fill=(244, 238, 226, 255))
    d.rectangle([0, 150, w, h], fill=(186, 34, 40, 255))
    d.rectangle([0, 146, w, 150], fill=(120, 20, 26, 255))
    # the kit, on the band's edge
    kx, ky = 250, 106
    d.rounded_rectangle([kx, ky, kx + 112, ky + 78], radius=10, fill=(214, 46, 50, 255), outline=(110, 18, 22, 255), width=4)
    d.rounded_rectangle([kx + 36, ky - 18, kx + 76, ky + 4], radius=6, outline=(110, 18, 22, 255), width=6)
    cx, cy = kx + 56, ky + 39
    d.rectangle([cx - 9, cy - 27, cx + 9, cy + 27], fill=(250, 248, 240, 255))
    d.rectangle([cx - 27, cy - 9, cx + 27, cy + 9], fill=(250, 248, 240, 255))
    # three answer boxes, the middle one ticked
    for i, y in enumerate((92, 110, 128)):
        d.rectangle([28, y, 46, y + 16], outline=(60, 50, 44, 255), width=3, fill=(250, 248, 240, 255))
        d.line([(56, y + 8), (200, y + 8)], fill=(150, 140, 128, 255), width=4)
        if i == 1:
            d.line([(30, y + 8), (36, y + 14), (50, y - 4)], fill=(36, 120, 60, 255), width=4)
    title = "FIRST AID QUIZ"
    f = font(40)
    tw = d.textlength(title, font=f)
    d.text(((w - tw) / 2 + 2, 20 + 2), title, font=f, fill=(150, 130, 120, 255))
    d.text(((w - tw) / 2, 20), title, font=f, fill=(150, 24, 30, 255))
    sub = "forty questions, one right answer"
    f2 = font(18, bold=False)
    sw = d.textlength(sub, font=f2)
    d.text(((w - sw) / 2, 64), sub, font=f2, fill=(80, 64, 56, 255))
    band = "know it before you need it"
    f3 = font(20, bold=False)
    d.text((24, 172), band, font=f3, fill=(250, 236, 226, 255))
    return img


def main():
    os.makedirs(ART, exist_ok=True)
    kit_sheet().save(os.path.join(ART, "kit.png"))
    marks_sheet().save(os.path.join(ART, "marks.png"))
    label().save(os.path.join(ART, "label.png"))
    print("written kit.png (%dx%d, 4 rows), marks.png (3 cells of %d), label.png in %s"
          % (KIT_W, KIT_H, MARK, os.path.normpath(ART)))


if __name__ == "__main__":
    main()

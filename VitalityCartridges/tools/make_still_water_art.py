"""Draws the art of Still Water: the screen masks and the colour label.

    python VitalityCartridges/tools/make_still_water_art.py

Writes into VitalityCartridges/42/media/ui/VitalityCartridges/Games/StillWater/:
    disc.png    the breathing disc, one cell per radius (DISC_RADII), white mask
    ring.png    rings, one cell per radius (RING_RADII), white mask: the guide and the ripples
    lily.png    a layered sheet (four rows, darkest first) of two 16x12 cells: a pad, a pad in flower
    label.png   the 388x212 colour label of the cartridge (cartridge_label.py turns it into the
                model texture, the icon and the poster)
The masks are plain white on transparent, every pixel fully one or the other, as the console
needs (SDK docs/03-screen-and-art.md). The radii and sizes are the ones Game.lua draws with.
"""
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, "..", "42", "media", "ui", "VitalityCartridges", "Games", "StillWater")

DISC_RADII = list(range(6, 41, 2))      # 18 cells
DISC_CELL = 82
RING_RADII = list(range(6, 47, 2))      # 21 cells
RING_CELL = 96
LILY_W, LILY_H = 16, 12
WHITE = (255, 255, 255, 255)


def strip(radii, cell, inside):
    """One cell per radius, side by side; inside(dx, dy, r) says whether a pixel is set."""
    img = Image.new("RGBA", (cell * len(radii), cell), (0, 0, 0, 0))
    px = img.load()
    c = (cell - 1) / 2
    for i, r in enumerate(radii):
        for y in range(cell):
            for x in range(cell):
                if inside(x - c, y - c, r):
                    px[i * cell + x, y] = WHITE
    return img


def disc(dx, dy, r):
    return dx * dx + dy * dy <= r * r + r * 0.8


def ring(dx, dy, r):
    d2 = dx * dx + dy * dy
    return (r - 1) * (r - 1) + (r - 1) * 0.8 < d2 <= r * r + r * 0.8


# the lily pads, as shade numbers per pixel (0 transparent); 1 darkest .. 4 lightest
PAD = [
    "....11111111....",
    "..113333333311..",
    ".13333333333331.",
    "1333333.33333331",
    "133333...3333331",
    "1333333..3333331",
    "13333333.3333331",
    "1333333333333331",
    ".13333333333331.",
    "..113333333311..",
    "....11111111....",
    "................",
]
BLOOM = [
    "....11114411....",
    "..1133344443311.",
    ".13333444444331.",
    "1333334414443331",
    "133333444443.331",
    "1333333444433331",
    "13333333.3333331",
    "1333333333333331",
    ".13333333333331.",
    "..113333333311..",
    "....11111111....",
    "................",
]


def lily_sheet():
    img = Image.new("RGBA", (LILY_W * 2, LILY_H * 4), (0, 0, 0, 0))
    px = img.load()
    for cell, rows in enumerate((PAD, BLOOM)):
        assert len(rows) == LILY_H and all(len(r) == LILY_W for r in rows)
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch in "1234":
                    shade = int(ch)
                    px[cell * LILY_W + x, (shade - 1) * LILY_H + y] = WHITE
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
    # the pond: deep teal at the bottom to dusk at the top
    for y in range(h):
        t = y / (h - 1)
        top, bottom = (58, 84, 112), (18, 64, 70)
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    # the ripples round the breath
    cx, cy = 262, 150
    for i, r in enumerate((18, 34, 50, 66)):
        d.ellipse([cx - r * 1.6, cy - r * 0.55, cx + r * 1.6, cy + r * 0.55],
                  outline=(150 + i * 20, 200 + i * 10, 205, 255), width=3)
    d.ellipse([cx - 20, cy - 8, cx + 20, cy + 8], fill=(214, 236, 230, 255))
    # lily pads, one in flower
    for (x, y, s, bloom) in ((70, 160, 34, True), (128, 186, 20, False), (330, 182, 24, False), (36, 118, 16, False)):
        d.ellipse([x - s, y - s * 0.45, x + s, y + s * 0.45], fill=(62, 128, 74, 255), outline=(30, 72, 40, 255), width=2)
        d.pieslice([x - s, y - s * 0.45, x + s, y + s * 0.45], 300, 330, fill=(18, 64, 70, 255))
        if bloom:
            for k, (ox, oy) in enumerate(((-9, -10), (9, -10), (0, -16), (-14, -4), (14, -4))):
                d.ellipse([x + ox - 8, y + oy - 9, x + ox + 8, y + oy + 5], fill=(236, 170, 196, 255), outline=(196, 112, 150, 255))
            d.ellipse([x - 5, y - 13, x + 5, y - 5], fill=(250, 220, 120, 255))
    title = "STILL WATER"
    f = font(44)
    tw = d.textlength(title, font=f)
    d.text(((w - tw) / 2 + 2, 22 + 2), title, font=f, fill=(10, 30, 36, 255))
    d.text(((w - tw) / 2, 22), title, font=f, fill=(236, 244, 238, 255))
    sub = "breathe in, breathe out"
    f2 = font(20, bold=False)
    sw = d.textlength(sub, font=f2)
    d.text(((w - sw) / 2, 76), sub, font=f2, fill=(196, 222, 216, 255))
    return img


def main():
    os.makedirs(ART, exist_ok=True)
    strip(DISC_RADII, DISC_CELL, disc).save(os.path.join(ART, "disc.png"))
    strip(RING_RADII, RING_CELL, ring).save(os.path.join(ART, "ring.png"))
    lily_sheet().save(os.path.join(ART, "lily.png"))
    label().save(os.path.join(ART, "label.png"))
    print("written disc.png (%d cells of %d), ring.png (%d of %d), lily.png, label.png in %s"
          % (len(DISC_RADII), DISC_CELL, len(RING_RADII), RING_CELL, os.path.normpath(ART)))


if __name__ == "__main__":
    main()

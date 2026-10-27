"""Draws the art of Steady: the screen masks and the colour label.

    python VitalityCartridges/tools/make_steady_art.py

Writes into VitalityCartridges/42/media/ui/VitalityCartridges/Games/Steady/:
    target.png  two 15x15 cells, white mask: the ring the cross follows, and its inside
                (drawn under the ring while the cross is on it)
    cross.png   the 9x9 cross, white mask, open at its centre
    label.png   the 388x212 colour label of the cartridge (cartridge_label.py turns it into the
                model texture, the icon and the poster)
The masks are plain white on transparent, every pixel fully one or the other, as the console
needs (SDK docs/03-screen-and-art.md). The sizes are the ones Game.lua draws with.
"""
import os
import random

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, "..", "42", "media", "ui", "VitalityCartridges", "Games", "Steady")

RING_CELL = 15
RING_OUTER, RING_INNER = 7.4, 5.4       # the ring's edge, as radii from the cell's centre
CROSS = 9
CROSS_GAP = 1                           # pixels left open each side of the centre
WHITE = (255, 255, 255, 255)


def target_sheet():
    """Cell 0 the ring, cell 1 the disc inside it."""
    img = Image.new("RGBA", (RING_CELL * 2, RING_CELL), (0, 0, 0, 0))
    px = img.load()
    c = (RING_CELL - 1) / 2
    for y in range(RING_CELL):
        for x in range(RING_CELL):
            d2 = (x - c) ** 2 + (y - c) ** 2
            if RING_INNER * RING_INNER < d2 <= RING_OUTER * RING_OUTER:
                px[x, y] = WHITE
            if d2 <= RING_INNER * RING_INNER:
                px[RING_CELL + x, y] = WHITE
    return img


def cross():
    img = Image.new("RGBA", (CROSS, CROSS), (0, 0, 0, 0))
    px = img.load()
    c = CROSS // 2
    for i in range(CROSS):
        if abs(i - c) > CROSS_GAP:
            px[i, c] = WHITE
            px[c, i] = WHITE
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
    # the background: warm slate at the top to a deep plum at the bottom
    for y in range(h):
        t = y / (h - 1)
        top, bottom = (64, 70, 92), (38, 28, 52)
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    # the target: rings round a bullseye
    cx, cy = 270, 150
    for r, colour in ((46, (236, 226, 204)), (36, (200, 72, 64)), (26, (236, 226, 204)), (16, (200, 72, 64)), (7, (250, 214, 96))):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=colour + (255,))
    # the trace of a shaky hand closing in on it, the same every run
    rng = random.Random(7)
    x, y = 30.0, 190.0
    points = [(x, y)]
    for i in range(80):
        t = i / 79
        x += (cx - x) * 0.06 + rng.uniform(-11, 11) * (1 - t)
        y += (cy - y) * 0.06 + rng.uniform(-11, 11) * (1 - t)
        points.append((x, y))
    d.line(points, fill=(150, 214, 200, 255), width=3, joint="curve")
    # the cross on the bullseye
    arm, gap = 22, 6
    for (x0, y0, x1, y1) in ((cx - arm, cy, cx - gap, cy), (cx + gap, cy, cx + arm, cy),
                             (cx, cy - arm, cx, cy - gap), (cx, cy + gap, cx, cy + arm)):
        d.line([(x0, y0), (x1, y1)], fill=(24, 24, 32, 255), width=5)
    title = "STEADY"
    f = font(54)
    tw = d.textlength(title, font=f)
    d.text(((w - tw) / 2 + 2, 16 + 2), title, font=f, fill=(16, 14, 24, 255))
    d.text(((w - tw) / 2, 16), title, font=f, fill=(244, 238, 226, 255))
    sub = "how steady are your hands?"
    f2 = font(20, bold=False)
    sw = d.textlength(sub, font=f2)
    d.text(((w - sw) / 2, 80), sub, font=f2, fill=(214, 206, 222, 255))
    return img


def main():
    os.makedirs(ART, exist_ok=True)
    target_sheet().save(os.path.join(ART, "target.png"))
    cross().save(os.path.join(ART, "cross.png"))
    label().save(os.path.join(ART, "label.png"))
    print("written target.png (2 cells of %d), cross.png (%dx%d), label.png in %s"
          % (RING_CELL, CROSS, CROSS, os.path.normpath(ART)))


if __name__ == "__main__":
    main()

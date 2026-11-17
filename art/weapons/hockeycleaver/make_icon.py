"""Draw the hockey stick cleaver's 32x32 inventory icon (Item_HockeyStickCleaver.png).

A render of the model at this size is a one-pixel line, so the icon is drawn: the weapon
on the diagonal the game's long weapons use (butt bottom left, head top right), the shaft
and both blades thicker than life. Drawn eight times too big and shrunk, with a dark rim
so it reads on the inventory's dark and light rows.

    python make_icon.py            writes Item_HockeyStickCleaver.png and icon_preview.png (x8)
"""
import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SIZE, SS = 32, 8

BUTT, TIP = (3.5, 28.5), (23.5, 8.5)          # the shaft's two ends, in icon pixels
LENGTH = math.hypot(TIP[0] - BUTT[0], TIP[1] - BUTT[1])
ALONG = ((TIP[0] - BUTT[0]) / LENGTH, (TIP[1] - BUTT[1]) / LENGTH)
EDGE = (ALONG[1] * -1.0, ALONG[0])            # towards the cleaver's edge: down and right

WOOD, WOOD_DARK = (201, 168, 112), (150, 118, 72)
TAPE_BLACK, KNOB = (38, 38, 42), (226, 224, 216)
RED, WHITE = (176, 38, 34), (232, 230, 224)
STEEL, STEEL_LIGHT, STEEL_DARK = (150, 156, 162), (214, 220, 226), (96, 100, 108)
WALNUT, DUCT, RUST = (86, 54, 34), (128, 132, 138), (140, 96, 66)
RIM = (24, 22, 22)


def at(u, v):
    """Icon pixels (scaled up) for a point u along the shaft from the butt and v towards
    the cleaver's edge."""
    return ((BUTT[0] + ALONG[0] * u + EDGE[0] * v) * SS, (BUTT[1] + ALONG[1] * u + EDGE[1] * v) * SS)


def quad(draw, u0, u1, v0, v1, fill):
    draw.polygon([at(u0, v0), at(u1, v0), at(u1, v1), at(u0, v1)], fill=fill)


def main():
    img = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    half = 1.15                                # the shaft's half thickness

    # the stick's own blade, off the far end on the side away from the cleaver
    d.polygon([at(LENGTH - 2.6, -half), at(LENGTH + 0.2, -half), at(LENGTH + 3.4, -8.6),
               at(LENGTH + 1.2, -9.4), at(LENGTH - 0.6, -8.2)], fill=WOOD)
    d.polygon([at(LENGTH + 0.9, -4.6), at(LENGTH + 2.1, -4.9), at(LENGTH + 3.4, -8.6),
               at(LENGTH + 1.2, -9.4), at(LENGTH - 0.6, -8.2), at(LENGTH - 1.2, -4.2)], fill=TAPE_BLACK)

    # the cleaver: its blade under the shaft near the far end
    b0, b1, deep = LENGTH - 10.2, LENGTH - 1.6, 7.4
    d.polygon([at(b0, half - 0.2), at(b1, half - 0.2), at(b1 + 0.2, deep - 0.6), at(b1 - 0.9, deep),
               at(b0 + 0.6, deep), at(b0 - 0.2, deep - 1.0)], fill=STEEL)
    d.polygon([at(b0 - 0.2, deep - 1.6), at(b1 + 0.2, deep - 1.6), at(b1 + 0.2, deep - 0.6), at(b1 - 0.9, deep),
               at(b0 + 0.6, deep), at(b0 - 0.2, deep - 1.0)], fill=STEEL_LIGHT)
    d.polygon([at(b0, half - 0.2), at(b1, half - 0.2), at(b1, half + 1.2), at(b0, half + 1.2)], fill=STEEL_DARK)
    d.polygon([at(b0 + 1.2, half + 1.8), at(b0 + 3.6, half + 1.6), at(b0 + 2.6, half + 3.4)], fill=RUST)
    cx, cy = at(b1 - 1.5, half + 1.9)          # the hole in the blade's corner
    d.ellipse([cx - 0.55 * SS, cy - 0.55 * SS, cx + 0.55 * SS, cy + 0.55 * SS], fill=RIM)

    # the shaft: wood, the red band, black grip tape, the white knob
    quad(d, 0.0, LENGTH, -half, half, WOOD)
    quad(d, 0.0, LENGTH, half - 0.55, half, WOOD_DARK)
    quad(d, 8.2, 14.0, -half, half, RED)
    quad(d, 10.0, 10.9, -half, half, WHITE)
    quad(d, 12.0, 12.5, -half, half, WHITE)
    quad(d, 0.8, 5.6, -half, half, TAPE_BLACK)
    quad(d, -0.9, 0.9, -half - 0.45, half + 0.45, KNOB)

    # the cleaver's handle flat on the shaft, the two bands of duct tape, the wire
    h0 = LENGTH - 16.0
    quad(d, h0, b0 + 0.4, -half - 0.1, half + 0.75, WALNUT)
    quad(d, h0 + 0.5, h0 + 2.4, -half - 0.45, half + 1.1, DUCT)
    quad(d, b0 - 2.1, b0 + 0.3, -half - 0.45, half + 1.1, DUCT)
    quad(d, b1 - 2.0, b1 - 1.3, -half - 0.3, half + 2.2, STEEL_DARK)

    # the dark rim: the shape grown by a pixel, under the shape
    alpha = img.getchannel("A")
    grown = alpha.filter(ImageFilter.MaxFilter(2 * (SS * 3 // 4) + 1))
    rim = Image.new("RGBA", img.size, RIM + (0,))
    rim.putalpha(grown.point(lambda a: int(a * 0.86)))
    big = Image.alpha_composite(rim, img)

    icon = big.resize((SIZE, SIZE), Image.LANCZOS)
    icon.save(os.path.join(HERE, "Item_HockeyStickCleaver.png"))
    preview = Image.new("RGBA", (SIZE * 8 * 2, SIZE * 8), (58, 56, 54, 255))
    preview.paste(Image.new("RGBA", (SIZE * 8, SIZE * 8), (20, 20, 20, 255)), (0, 0))
    up = icon.resize((SIZE * 8, SIZE * 8), Image.NEAREST)
    preview.alpha_composite(up, (0, 0))
    preview.alpha_composite(up, (SIZE * 8, 0))
    preview.convert("RGB").save(os.path.join(HERE, "icon_preview.png"))
    print("wrote Item_HockeyStickCleaver.png (%dx%d) and icon_preview.png" % icon.size)


if __name__ == "__main__":
    main()

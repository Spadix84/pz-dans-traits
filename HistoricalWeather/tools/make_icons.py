"""Draws the forecast calendar's weather icons into 42/media/ui/HistoricalWeather/.

clear, partly, cloudy, fog, showers, rain, snow, storm: 32x32 PNGs, drawn at 4x and scaled
down for smooth edges. Needs Pillow. Run from anywhere: python tools/make_icons.py
"""
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "42", "media", "ui", "HistoricalWeather")
SIZE, K = 32, 4
S = SIZE * K

SUN = (255, 196, 64, 255)
CLOUD = (226, 230, 236, 255)
GREY = (150, 156, 166, 255)
DARK = (96, 102, 114, 255)
DROP = (92, 160, 255, 255)
FLAKE = (240, 246, 255, 255)
BOLT = (255, 220, 70, 255)
LINE = (190, 196, 204, 255)
EDGE = (40, 44, 52, 255)


def canvas():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def p(v):
    return v * K


def sun(d, cx, cy, r, rays=True):
    if rays:
        import math
        for n in range(8):
            a = n * math.pi / 4
            x1, y1 = cx + math.cos(a) * (r + 2.5), cy + math.sin(a) * (r + 2.5)
            x2, y2 = cx + math.cos(a) * (r + 5.5), cy + math.sin(a) * (r + 5.5)
            d.line([p(x1), p(y1), p(x2), p(y2)], fill=SUN, width=p(2))
    d.ellipse([p(cx - r), p(cy - r), p(cx + r), p(cy + r)], fill=SUN)


def cloud(d, x, y, w, colour):
    """a cloud whose flat bottom runs from x to x + w at height y"""
    h = w * 0.42
    parts = [
        (x + w * 0.00, y - h * 0.62, x + w * 0.42, y),
        (x + w * 0.20, y - h * 1.15, x + w * 0.66, y - h * 0.10),
        (x + w * 0.50, y - h * 0.85, x + w * 1.00, y),
    ]
    for a, b, c, e in parts:     # a dark rim, then the cloud over it
        d.ellipse([p(a) - K, p(b) - K, p(c) + K, p(e) + K], fill=EDGE)
    d.rectangle([p(x + w * 0.2), p(y - h * 0.5) - K, p(x + w * 0.8), p(y) + K], fill=EDGE)
    for a, b, c, e in parts:
        d.ellipse([p(a), p(b), p(c), p(e)], fill=colour)
    d.rectangle([p(x + w * 0.2), p(y - h * 0.5), p(x + w * 0.8), p(y)], fill=colour)


def drops(d, xs, y, length):
    for x in xs:
        d.line([p(x + 1.5), p(y), p(x), p(y + length)], fill=DROP, width=p(2))


def save(img, name):
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    img.save(os.path.join(OUT, name + ".png"))


def main():
    os.makedirs(OUT, exist_ok=True)

    img, d = canvas()
    sun(d, 16, 16, 7)
    save(img, "clear")

    img, d = canvas()
    sun(d, 12, 11, 6)
    cloud(d, 9, 26, 21, CLOUD)
    save(img, "partly")

    img, d = canvas()
    cloud(d, 13, 17, 16, GREY)
    cloud(d, 3, 26, 24, CLOUD)
    save(img, "cloudy")

    img, d = canvas()
    for y, x1, x2 in ((9, 5, 27), (15, 3, 23), (21, 8, 29), (27, 4, 25)):
        d.line([p(x1), p(y), p(x2), p(y)], fill=LINE, width=p(3))
    save(img, "fog")

    img, d = canvas()
    sun(d, 22, 9, 5, rays=False)
    cloud(d, 3, 20, 24, CLOUD)
    drops(d, (10, 18), 23, 5)
    save(img, "showers")

    img, d = canvas()
    cloud(d, 3, 18, 26, GREY)
    drops(d, (7, 13, 19, 25), 21, 8)
    save(img, "rain")

    img, d = canvas()
    cloud(d, 3, 18, 26, CLOUD)
    for x, y in ((8, 23), (16, 22), (24, 23), (12, 28), (20, 28)):
        d.ellipse([p(x - 1.8), p(y - 1.8), p(x + 1.8), p(y + 1.8)], fill=FLAKE, outline=EDGE, width=K)
    save(img, "snow")

    img, d = canvas()
    cloud(d, 3, 17, 26, DARK)
    bolt = [(17, 16), (11, 25), (15.5, 25), (13, 31), (21, 21), (16.5, 21), (19, 16)]
    d.polygon([(p(x), p(y)) for x, y in bolt], fill=BOLT, outline=EDGE)
    drops(d, (6, 24), 20, 6)
    save(img, "storm")

    print("icons written to", os.path.normpath(OUT))


if __name__ == "__main__":
    main()

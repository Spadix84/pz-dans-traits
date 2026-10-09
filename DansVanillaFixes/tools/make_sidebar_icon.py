"""Draw the Collection checklist's sidebar button: a clipboard with a tick, in
the vanilla sidebar's style (grey when the window is closed, in colour while
it is open) at each sidebar size (48, 64, 80, 96 and 128 wide, 3:4 high).

    python DansVanillaFixes/tools/make_sidebar_icon.py

Writes 42/media/ui/DVF/Collection_{Off,On}_<width>.png. The shapes are
described on a 128 x 96 canvas and sampled 4 x 4 per pixel at each size, so
every size is drawn, not scaled. No libraries needed.
"""
import math
import os
import struct
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "42", "media", "ui", "DVF")
WIDTHS = (48, 64, 80, 96, 128)
SS = 4   # samples per pixel along each axis

OUTLINE = (35, 35, 35)
COLOURS = {
    # name: (off, on)
    "board": ((110, 110, 110), (150, 100, 55)),
    "paper": ((215, 215, 215), (245, 242, 230)),
    "clip": ((150, 150, 150), (185, 190, 200)),
    "line": ((150, 150, 150), (150, 150, 160)),
    "tick": ((75, 75, 75), (75, 170, 85)),
}


def rounded(x0, y0, x1, y1, r):
    def inside(x, y, grow):
        ax0, ay0, ax1, ay1, rr = x0 - grow, y0 - grow, x1 + grow, y1 + grow, r + grow
        cx = min(max(x, ax0 + rr), ax1 - rr)
        cy = min(max(y, ay0 + rr), ay1 - rr)
        return ax0 <= x <= ax1 and ay0 <= y <= ay1 and (x - cx) ** 2 + (y - cy) ** 2 <= rr * rr
    return inside


def stroke(points, width):
    segs = list(zip(points, points[1:]))

    def inside(x, y, grow):
        half = width / 2 + grow
        for (ax, ay), (bx, by) in segs:
            dx, dy = bx - ax, by - ay
            t = max(0.0, min(1.0, ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)))
            if math.hypot(x - ax - t * dx, y - ay - t * dy) <= half:
                return True
        return False
    return inside


# back to front: (shape, colour name, outline width on the 128-wide canvas)
LAYERS = [
    (rounded(36, 12, 92, 92, 7), "board", 3),
    (rounded(43, 22, 85, 85, 2), "paper", 0),
    (stroke([(50, 33), (78, 33)], 3.5), "line", 0),
    (stroke([(50, 43), (72, 43)], 3.5), "line", 0),
    (rounded(52, 5, 76, 20, 4), "clip", 3),
    (stroke([(51, 63), (60, 74), (80, 50)], 8), "tick", 3),
]


def draw(width, on):
    height = int(width * 0.75)
    k = 128.0 / width
    rows = []
    for py in range(height):
        row = bytearray()
        for px in range(width):
            acc = [0.0, 0.0, 0.0, 0.0]
            for sy in range(SS):
                for sx in range(SS):
                    x = (px + (sx + 0.5) / SS) * k
                    y = (py + (sy + 0.5) / SS) * k
                    colour = None
                    for shape, name, line in LAYERS:
                        if shape(x, y, 0):
                            colour = COLOURS[name][1 if on else 0]
                        elif line and shape(x, y, line):
                            colour = OUTLINE
                    if colour:
                        acc[0] += colour[0]
                        acc[1] += colour[1]
                        acc[2] += colour[2]
                        acc[3] += 1
            n = acc[3]
            if n:
                row += bytes((round(acc[0] / n), round(acc[1] / n), round(acc[2] / n), round(255 * n / (SS * SS))))
            else:
                row += bytes(4)
        rows.append(bytes(row))
    return width, height, rows


def png(width, height, rows):
    raw = b"".join(b"\x00" + r for r in rows)

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def main():
    os.makedirs(OUT, exist_ok=True)
    for width in WIDTHS:
        for on in (False, True):
            path = os.path.join(OUT, "Collection_%s_%d.png" % ("On" if on else "Off", width))
            with open(path, "wb") as f:
                f.write(png(*draw(width, on)))
            print(path)


if __name__ == "__main__":
    main()

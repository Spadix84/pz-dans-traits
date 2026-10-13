"""Draw Dan's Vanilla Fixes' pixel icons: the Good Read moodle (an open book).
Each is a 16 x 16 grid of palette letters written out at 32 x 32 as a PNG (no
libraries needed), the same way DanTraits/tools/make_icons.py draws Vitality's.

    python DansVanillaFixes/tools/make_icons.py

Moodle icons go to 42/media/ui and 42/media/ui/32 (Moodle Framework looks in
the size folder first).
"""
import os
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
MEDIA = os.path.join(HERE, "..", "42", "media")

PALETTE = {
    ".": (0, 0, 0, 0),
    "k": (30, 30, 30, 255),      # outline
    "w": (250, 250, 250, 255),
    "l": (195, 195, 195, 255),   # light grey
    "d": (95, 95, 95, 255),      # dark grey
    "r": (205, 45, 45, 255),
    "y": (250, 210, 60, 255),
    "n": (130, 90, 50, 255),     # brown
    "N": (85, 55, 30, 255),      # dark brown
    "g": (75, 170, 85, 255),
}

ICONS = {
    # an open book, pages to the reader, a red ribbon bookmark
    "ui/GoodRead": """
................
................
.......k........
..kkkkkrkkkkkk..
.kwwwwkrkwwwwwk.
.kwllwkrkwllwwk.
.kwwwwkrkwwwwwk.
.kwllwkrkwlllwk.
.kwwwwkrkwwwwwk.
.kwlllkrkwllwwk.
.kwwwwkrkwwwwwk.
.kNNNNkrkNNNNNk.
..kkkkkrkkkkkk..
.......r........
.......r........
................
""",
}


def rows_of(art):
    rows = art.strip("\n").split("\n")
    if len(rows) != 16:
        raise ValueError("expected 16 rows, got %d" % len(rows))
    return [[PALETTE[ch] for ch in (r + "." * 16)[:16]] for r in rows]


def png(pixels):
    height, width = len(pixels), len(pixels[0])
    raw = b"".join(b"\x00" + b"".join(struct.pack("BBBB", *p) for p in row) for row in pixels)

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def scaled(rows, k):
    out = []
    for row in rows:
        wide = [p for p in row for _ in range(k)]
        out.extend([wide] * k)
    return out


def main(argv):
    written = []
    for name, art in ICONS.items():
        data = png(scaled(rows_of(art), 2))
        targets = [os.path.join(MEDIA, name + ".png")]
        if name.startswith("ui/"):
            targets.append(os.path.join(MEDIA, "ui", "32", name[3:] + ".png"))
        for path in targets:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "wb") as f:
                f.write(data)
            written.append(path)
    print("wrote %d files" % len(written))


if __name__ == "__main__":
    main(sys.argv[1:])

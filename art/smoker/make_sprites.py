"""Turn high-res Blender renders into game-sized sprites in the vanilla style.

  python make_sprites.py <raw_dir> <out_dir> [--variant brick] [--facings E,S,W,N]
                         [--states off,on] [--sheet]

Downscales to the 128x256 tile, adds the dark inner edge vanilla sprites have,
and reduces the palette so it reads as painted pixels rather than a soft 3D render.
With --sheet it also writes the tile sheet, its depth map and an inventory icon.
Sheet order follows --facings, off then on. The mod uses E,S,W,N.
Icons: Item_BrickSmoker (32 px, the loot window's container button), Build_BrickSmoker
(64 px, the Build menu) and icon.png (32 px, the mod list), cropped from the front view.
"""
import argparse
import os

import numpy as np
from PIL import Image, ImageChops, ImageFilter

TILE = (128, 256)
# Measured from vanilla DEPTH_appliances_cooking_01.png: grey, higher = farther from
# the camera, about one level per pixel of depth, nearest point around 102.
DEPTH_NEAREST = 102
DEPTH_LEVELS_PER_M = 128.0 / 2 ** 0.5  # same as PX_PER_M in build_smoker.py
TILESET = "crafted_smoker_01"


def downscale(path):
    im = Image.open(path).convert("RGBA")
    # Premultiply so the transparent background can't bleed into edge colours.
    r, g, b, a = im.split()
    r, g, b = (ImageChops.multiply(c, a) for c in (r, g, b))
    small = Image.merge("RGBA", (r, g, b, a)).resize(TILE, Image.LANCZOS)
    r, g, b, a = small.split()
    px_a = a.load()
    out = [c.load() for c in (r, g, b)]
    for y in range(TILE[1]):
        for x in range(TILE[0]):
            if px_a[x, y]:
                for c in out:
                    c[x, y] = min(255, c[x, y] * 255 // px_a[x, y])
    return r, g, b, a


def stylise(path):
    r, g, b, a = downscale(path)
    rgb = Image.merge("RGB", (r, g, b))
    rgb = rgb.filter(ImageFilter.UnsharpMask(radius=1.2, percent=70, threshold=1))

    # Hard-ish alpha: vanilla edges are crisp, with no long soft fringe.
    a = a.point(lambda v: 0 if v < 70 else (255 if v > 150 else v))

    # Limited palette for the hand-pixelled look.
    rgb = rgb.quantize(colors=40, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")

    # One-pixel darker rim just inside the silhouette.
    solid = a.point(lambda v: 255 if v > 110 else 0)
    inner = solid.filter(ImageFilter.MinFilter(3))
    rim = ImageChops.subtract(solid, inner)
    dark = rgb.point(lambda v: int(v * 0.58))
    rgb.paste(dark, (0, 0), rim)
    return Image.merge("RGBA", (*rgb.split(), a))


def depth_metres(path):
    """Depth pass to metres towards the camera (the pass stores 0.5 + metres)."""
    a = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32)
    f = a.shape[1] // TILE[0]
    mask = (a[..., 3] > 128).astype(np.float32)
    d = (a[..., 0] / 255.0 - 0.5) * mask
    h, w = TILE[1], TILE[0]
    sum_d = d.reshape(h, f, w, f).sum(axis=(1, 3))
    sum_m = mask.reshape(h, f, w, f).sum(axis=(1, 3))
    return sum_d / np.maximum(sum_m, 1), sum_m > 0


def write_sheet(args, sprites):
    facings, states = args.facings.split(","), args.states.split(",")
    n = len(facings) * len(states)
    sheet = Image.new("RGBA", (TILE[0] * 8, TILE[1] * ((n + 7) // 8)), (0, 0, 0, 0))
    depth_sheet = sheet.copy()
    depths = {f: depth_metres(os.path.join(args.raw, f"{args.variant}_{f}_depthraw.png")) for f in facings}
    nearest = max(float(d[m].max()) for d, m in depths.values())
    i = 0
    for state in states:
        for facing in facings:
            sprite = sprites[(facing, state)]
            pos = ((i % 8) * TILE[0], (i // 8) * TILE[1])
            sheet.paste(sprite, pos)
            d, m = depths[facing]
            grey = np.clip(DEPTH_NEAREST + (nearest - d) * DEPTH_LEVELS_PER_M, 0, 255)
            grey = Image.fromarray(np.where(m, grey, 0).astype(np.uint8), "L")
            alpha = sprite.getchannel("A")
            depth_sheet.paste(Image.merge("RGBA", (grey, grey, grey, alpha)), pos)
            i += 1
    sheet.save(os.path.join(args.out, f"{TILESET}.png"))
    depth_sheet.save(os.path.join(args.out, f"DEPTH_{TILESET}.png"))

    # Icons: cropped from the front view, not separate renders.
    src = Image.open(os.path.join(args.raw, f"{args.variant}_S_off_raw.png")).convert("RGBA")
    src = src.crop(src.getbbox())
    for name, size in (("Item_BrickSmoker", 32), ("Build_BrickSmoker", 64), ("icon", 32)):
        im = src.copy()
        im.thumbnail((size, size), Image.LANCZOS)
        icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        icon.paste(im, ((size - im.width) // 2, (size - im.height) // 2))
        icon.save(os.path.join(args.out, f"{name}.png"))

    # Workshop preview: the lit front view on a dusk background.
    lit = Image.open(os.path.join(args.raw, f"{args.variant}_S_on_raw.png")).convert("RGBA")
    lit = lit.crop(lit.getbbox())
    lit.thumbnail((236, 236), Image.LANCZOS)
    preview = Image.new("RGBA", (256, 256), (52, 58, 66, 255))
    preview.alpha_composite(lit, ((256 - lit.width) // 2, 256 - lit.height - 8))
    preview.convert("RGB").save(os.path.join(args.out, "preview.png"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("raw")
    ap.add_argument("out")
    ap.add_argument("--variant", default="brick")
    ap.add_argument("--facings", default="E,S,W,N")
    ap.add_argument("--states", default="off,on")
    ap.add_argument("--sheet", action="store_true")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    sprites = {}
    for state in args.states.split(","):
        for facing in args.facings.split(","):
            src = os.path.join(args.raw, f"{args.variant}_{facing}_{state}_raw.png")
            sprite = stylise(src)
            dst = os.path.join(args.out, f"{args.variant}_{facing}_{state}.png")
            sprite.save(dst)
            sprites[(facing, state)] = sprite
            print(os.path.basename(dst), "bbox", sprite.getbbox())
    if args.sheet:
        write_sheet(args, sprites)


if __name__ == "__main__":
    main()

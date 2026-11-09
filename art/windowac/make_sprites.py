"""Turn the high-res window AC renders into game-sized sprites in the vanilla style.

  python make_sprites.py <raw_dir> <out_dir> [--facings S,E,N,W] [--states off,on]
                         [--vanilla DIR]

Downscales each render to the 128x256 tile, adds the dark inner edge vanilla sprites
have, and reduces the palette so it reads as painted pixels, not a soft 3D render.
Writes:
  windowac_<facing>_<state>.png     each sprite
  appliances_windowac_01.png        the tile sheet: facings in order, off then on
  DEPTH_appliances_windowac_01.png  its depth map, from the depth renders
  Item_WindowAC.png                 the 32x32 inventory icon, from icon_raw.png
With --vanilla (a folder of extracted vanilla sprites: walls_exterior_house_01_8/9,
fixtures_windows_01_0/1 and DEPTH_fixtures_windows_01_0/1) it also writes mockup.png,
each sprite drawn into a vanilla wall and window, and checks that no pixel of the unit
sorts behind the window it sits in. The same process as the Slow Cooker's art.
"""
import argparse
import os

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

TILE = (128, 256)
# Which vanilla wall, window and window depth tile each facing sits in: the west
# edge for E and W, the north edge for S and N.
VANILLA = {"E": ("walls_exterior_house_01_8", "fixtures_windows_01_0", "DEPTH_fixtures_windows_01_0"),
           "W": ("walls_exterior_house_01_8", "fixtures_windows_01_0", "DEPTH_fixtures_windows_01_0"),
           "S": ("walls_exterior_house_01_9", "fixtures_windows_01_1", "DEPTH_fixtures_windows_01_1"),
           "N": ("walls_exterior_house_01_9", "fixtures_windows_01_1", "DEPTH_fixtures_windows_01_1")}
# How many grey levels in front of the window plane the accordion panels (which lie in
# it) may land, from rounding: anything further behind than this is an error.
DEPTH_SLACK = 4


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
    # Hard-ish alpha: vanilla edges are crisp, with no long soft fringe. The cord is
    # thinner than a pixel, so keep faint pixels a little more than the cooker does.
    a = a.point(lambda v: 0 if v < 60 else (255 if v > 150 else v))
    rgb = rgb.quantize(colors=40, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    # One-pixel darker rim just inside the silhouette.
    solid = a.point(lambda v: 255 if v > 110 else 0)
    inner = solid.filter(ImageFilter.MinFilter(3))
    rim = ImageChops.subtract(solid, inner)
    dark = rgb.point(lambda v: int(v * 0.58))
    rgb.paste(dark, (0, 0), rim)
    return Image.merge("RGBA", (*rgb.split(), a))


def depth_tile(path, sprite):
    """The depth render (vanilla grey already, see build_windowac.py) averaged down to the
    tile over the pixels the unit covers, with the sprite's alpha. Holes the average
    leaves under the sprite take the nearest covered value."""
    a = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32)
    f = a.shape[1] // TILE[0]
    mask = (a[..., 3] > 128).astype(np.float32)
    h, w = TILE[1], TILE[0]
    sum_g = (a[..., 0] * mask).reshape(h, f, w, f).sum(axis=(1, 3))
    sum_m = mask.reshape(h, f, w, f).sum(axis=(1, 3))
    grey = np.where(sum_m > 0, sum_g / np.maximum(sum_m, 1), 0)
    alpha = np.asarray(sprite.getchannel("A"))
    missing = (alpha > 0) & (sum_m == 0)
    for y, x in zip(*np.nonzero(missing)):
        ys, xs = np.nonzero(sum_m > 0)
        k = np.argmin((ys - y) ** 2 + (xs - x) ** 2)
        grey[y, x] = grey[ys[k], xs[k]]
    grey = Image.fromarray(np.clip(np.rint(grey), 0, 255).astype(np.uint8), "L")
    return Image.merge("RGBA", (grey, grey, grey, sprite.getchannel("A")))


def check_depth(depths, vanilla):
    """Over solid wall, no covered pixel may be farther than the wall plane (the window's
    depth tile gives the plane's grey), or the game would draw the wall over the unit.
    Through the opening it may be: that is the part seen through the glass."""
    ok = True
    for facing, depth in depths.items():
        wall_name, _, depth_name = VANILLA[facing]
        plane = np.asarray(Image.open(os.path.join(vanilla, depth_name + ".png")).convert("RGBA"))
        wall = np.asarray(Image.open(os.path.join(vanilla, wall_name + ".png")).convert("RGBA"))
        d = np.asarray(depth).astype(int)
        over_wall = (d[..., 3] > 0) & (plane[..., 3] > 128) & (wall[..., 3] > 128)
        behind = d[..., 0][over_wall] - plane[..., 0][over_wall].astype(int)
        worst = int(behind.max()) if behind.size else 0
        status = "ok" if worst <= DEPTH_SLACK else "BEHIND THE WALL"
        ok &= worst <= DEPTH_SLACK
        print(f"depth {facing}: {over_wall.sum()} px over solid wall, at most {worst} grey behind it: {status}")
    return ok


def icon(raw, out):
    src = Image.open(os.path.join(raw, "icon_raw.png")).convert("RGBA")
    src = src.crop(src.getbbox())
    src.thumbnail((32, 32), Image.LANCZOS)
    im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    im.paste(src, ((32 - src.width) // 2, (32 - src.height) // 2))
    im.save(os.path.join(out, "Item_WindowAC.png"))


def mockup(sprites, facings, states, vanilla, out):
    """Each sprite in a vanilla wall and closed window, on a floor-coloured tile, at 2x."""
    cols = len(facings)
    sheet = Image.new("RGBA", (TILE[0] * cols, (TILE[1] + 16) * len(states)), (74, 82, 70, 255))
    draw = ImageDraw.Draw(sheet)
    for j, state in enumerate(states):
        for i, facing in enumerate(facings):
            wall, window = (Image.open(os.path.join(vanilla, n + ".png")).convert("RGBA")
                            for n in VANILLA[facing][:2])
            tile = Image.new("RGBA", TILE, (0, 0, 0, 0))
            floor = ImageDraw.Draw(tile)
            floor.polygon([(64, 192), (128, 224), (64, 256), (0, 224)], fill=(150, 128, 98, 255))
            tile.alpha_composite(wall)
            tile.alpha_composite(window)
            tile.alpha_composite(sprites[(facing, state)])
            pos = (i * TILE[0], j * (TILE[1] + 16))
            sheet.alpha_composite(tile, pos)
            draw.text((pos[0] + 4, pos[1] + TILE[1] + 2), f"{facing} {state}", fill=(255, 255, 255))
    sheet = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
    sheet.save(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("raw")
    ap.add_argument("out")
    ap.add_argument("--facings", default="S,E,N,W")
    ap.add_argument("--states", default="off,on")
    ap.add_argument("--vanilla")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    facings, states = args.facings.split(","), args.states.split(",")
    sprites, depths = {}, {}
    n = len(facings) * len(states)
    sheet = Image.new("RGBA", (TILE[0] * n, TILE[1]), (0, 0, 0, 0))
    depth_sheet = sheet.copy()
    i = 0
    for state in states:
        for facing in facings:
            sprite = stylise(os.path.join(args.raw, f"windowac_{facing}_{state}_raw.png"))
            sprite.save(os.path.join(args.out, f"windowac_{facing}_{state}.png"))
            sprites[(facing, state)] = sprite
            depth = depth_tile(os.path.join(args.raw, f"windowac_{facing}_depthraw.png"), sprite)
            depths.setdefault(facing, depth)
            sheet.paste(sprite, (i * TILE[0], 0))
            depth_sheet.paste(depth, (i * TILE[0], 0))
            i += 1
            print(f"windowac_{facing}_{state}.png", "bbox", sprite.getbbox())
    sheet.save(os.path.join(args.out, "appliances_windowac_01.png"))
    depth_sheet.save(os.path.join(args.out, "DEPTH_appliances_windowac_01.png"))
    icon(args.raw, args.out)
    print("appliances_windowac_01.png, DEPTH_appliances_windowac_01.png, Item_WindowAC.png")
    if args.vanilla:
        mockup(sprites, facings, states, args.vanilla, os.path.join(args.out, "mockup.png"))
        print("mockup.png")
        if not check_depth(depths, args.vanilla):
            raise SystemExit("depth check failed")


if __name__ == "__main__":
    main()

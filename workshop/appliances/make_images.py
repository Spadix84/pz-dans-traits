"""Draw the two pictures that show both appliances together.

    python workshop/appliances/make_images.py

writes:
    workshop/appliances/preview.png     256x256  the Workshop thumbnail
    VitalityAppliances/42/icon.png      32x32    the mod list icon

Both are put together from each appliance's own art (art/slowcooker/sprites,
art/smoker/sprites): the smoker behind on the left, the cooker in front on the
right. The 256 px previews have a plain dusk background, which is keyed out here
so the two can overlap. Run it again after either appliance's art is rebuilt.
"""
import os

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
COOKER = os.path.join(REPO, "art", "slowcooker", "sprites")
SMOKER = os.path.join(REPO, "art", "smoker", "sprites")
BACKGROUND = (52, 58, 66)   # the smoker preview's dusk


def keyed(path):
    """A preview with its plain background made transparent, cropped to the object."""
    im = Image.open(path).convert("RGB")
    a = np.asarray(im).astype(np.float32)
    ring = np.concatenate([a[:6].reshape(-1, 3), a[-6:].reshape(-1, 3),
                           a[:, :6].reshape(-1, 3), a[:, -6:].reshape(-1, 3)])
    distance = np.sqrt(((a - np.median(ring, axis=0)) ** 2).sum(axis=2))
    alpha = Image.fromarray((np.clip((distance - 10) / 22, 0, 1) * 255).astype(np.uint8))
    # close the holes dark parts of the object leave, then soften the edge
    alpha = alpha.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(0.6))
    out = im.convert("RGBA")
    out.putalpha(alpha)
    return out.crop(out.getbbox())


def fit(im, w, h):
    r = min(w / im.width, h / im.height)
    return im.resize((max(1, round(im.width * r)), max(1, round(im.height * r))), Image.LANCZOS)


def trimmed(path):
    im = Image.open(path).convert("RGBA")
    return im.crop(im.getbbox())


def main():
    preview = Image.new("RGBA", (256, 256), BACKGROUND + (255,))
    smoker = fit(keyed(os.path.join(SMOKER, "preview.png")), 150, 222)
    cooker = fit(keyed(os.path.join(COOKER, "preview.png")), 150, 130)
    preview.alpha_composite(smoker, (14, 14))
    preview.alpha_composite(cooker, (256 - cooker.width - 8, 256 - cooker.height - 12))
    preview.convert("RGB").save(os.path.join(HERE, "preview.png"))

    icon = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    smoker = fit(trimmed(os.path.join(SMOKER, "icon.png")), 20, 30)
    cooker = fit(trimmed(os.path.join(COOKER, "Item_SlowCooker.png")), 22, 18)
    icon.alpha_composite(smoker, (1, 1))
    icon.alpha_composite(cooker, (32 - cooker.width, 32 - cooker.height))
    icon.save(os.path.join(REPO, "VitalityAppliances", "42", "icon.png"))
    print("wrote preview.png and VitalityAppliances/42/icon.png")


if __name__ == "__main__":
    main()

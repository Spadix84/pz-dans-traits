"""Shared helper for drawing a weapon's 32x32 inventory icon.

A render of a long weapon at this size is a one-pixel line, so the icons are drawn: the
weapon on the diagonal the game's weapons use (butt bottom left, head top right), shafts
and heads thicker than life. Drawn eight times too big and shrunk, with a dark rim so it
reads on the inventory's dark and light rows.

    icon = Icon(butt=(3.5, 28.5), tip=(23.5, 8.5))     # the weapon's line, in icon pixels
    icon.quad(0, icon.length, -1.1, 1.1, WOOD)         # u along the line, v across it
    icon.save(folder, "Item_Name.png")                 # and icon_preview.png, enlarged

v is positive towards the lower right (the side a blade's edge is drawn on).
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

SIZE, SS = 32, 8
RIM = (24, 22, 22)

WOOD, WOOD_DARK = (201, 168, 112), (150, 118, 72)
STEEL, STEEL_LIGHT, STEEL_DARK = (150, 156, 162), (214, 220, 226), (96, 100, 108)
DUCT, DUCT_DARK = (128, 132, 138), (92, 96, 102)
BLACK, WHITE = (38, 38, 42), (232, 230, 224)
RED, BLUE = (176, 38, 34), (44, 70, 150)


class Icon:
    def __init__(self, butt, tip):
        self.butt = butt
        self.length = math.hypot(tip[0] - butt[0], tip[1] - butt[1])
        self.along = ((tip[0] - butt[0]) / self.length, (tip[1] - butt[1]) / self.length)
        self.edge = (-self.along[1], self.along[0])
        self.img = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.img)

    def at(self, u, v):
        return ((self.butt[0] + self.along[0] * u + self.edge[0] * v) * SS,
                (self.butt[1] + self.along[1] * u + self.edge[1] * v) * SS)

    def poly(self, uv_points, fill):
        self.draw.polygon([self.at(u, v) for u, v in uv_points], fill=fill)

    def quad(self, u0, u1, v0, v1, fill):
        self.poly([(u0, v0), (u1, v0), (u1, v1), (u0, v1)], fill)

    def dot(self, u, v, r, fill):
        cx, cy = self.at(u, v)
        self.draw.ellipse([cx - r * SS, cy - r * SS, cx + r * SS, cy + r * SS], fill=fill)

    def save(self, folder, name):
        alpha = self.img.getchannel("A")
        grown = alpha.filter(ImageFilter.MaxFilter(2 * (SS * 3 // 4) + 1))   # the shape, a pixel bigger
        rim = Image.new("RGBA", self.img.size, RIM + (0,))
        rim.putalpha(grown.point(lambda a: int(a * 0.86)))
        icon = Image.alpha_composite(rim, self.img).resize((SIZE, SIZE), Image.LANCZOS)
        icon.save(os.path.join(folder, name))
        preview = Image.new("RGBA", (SIZE * 8 * 2, SIZE * 8), (58, 56, 54, 255))
        preview.paste(Image.new("RGBA", (SIZE * 8, SIZE * 8), (20, 20, 20, 255)), (0, 0))
        up = icon.resize((SIZE * 8, SIZE * 8), Image.NEAREST)
        preview.alpha_composite(up, (0, 0))
        preview.alpha_composite(up, (SIZE * 8, 0))
        preview.convert("RGB").save(os.path.join(folder, name.replace("Item_", "icon_preview_")))
        print("wrote %s and its enlarged preview" % name)

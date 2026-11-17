"""Draw the cutlery mace's 32x32 inventory icon (see ../icon_common.py).

    python make_icon.py       writes Item_CutleryMace.png and icon_preview_CutleryMace.png
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import icon_common as ic  # noqa: E402

i = ic.Icon(butt=(4.0, 28.0), tip=(21.0, 11.0))
L = i.length
h0 = L - 11.5                                    # where the head begins
# the cutlery fanned out past the end: a fork up, a knife in the middle, a fork down
for v0, v1 in ((-2.0, -5.6), (2.0, 5.6)):
    for dv in (-1.1, 0.0, 1.1):                  # three tines each
        i.poly([(L - 1.0, v0 + dv * 0.5), (L + 6.6, v1 + dv), (L + 6.9, v1 + dv + 0.45), (L - 0.6, v0 + dv * 0.5 + 0.6)], ic.STEEL_LIGHT)
    i.poly([(L - 3.0, v0 * 0.7), (L + 1.4, v0 * 1.25 - 0.9), (L + 2.2, v0 * 1.25 + 0.9), (L - 2.0, v0 * 0.7 + 0.9)], ic.STEEL)
i.poly([(L - 2.0, -0.9), (L + 6.4, -1.1), (L + 8.2, 0.2), (L + 6.2, 1.2), (L - 2.0, 0.9)], ic.STEEL_LIGHT)
i.poly([(L - 2.0, 0.2), (L + 8.2, 0.2), (L + 6.2, 1.2), (L - 2.0, 0.9)], ic.STEEL)
# the club: a slim grip, a thicker head, a pommel
i.quad(0.0, h0 + 0.6, -1.15, 1.15, ic.WOOD)
i.quad(0.0, h0 + 0.6, 0.55, 1.15, ic.WOOD_DARK)
i.quad(1.6, 7.6, -1.15, 1.15, ic.WOOD_DARK)
i.quad(-0.8, 0.8, -1.6, 1.6, ic.WOOD)
i.quad(h0, L, -2.1, 2.1, ic.WOOD)
i.quad(h0, L, 1.3, 2.1, ic.WOOD_DARK)
# the stems along the head, and two bands of duct tape over them
for v in (-1.3, 0.0, 1.3):
    i.quad(h0 + 0.6, L, v - 0.3, v + 0.3, ic.STEEL_LIGHT)
i.quad(h0 + 1.2, h0 + 4.0, -2.6, 2.6, ic.DUCT)
i.quad(h0 + 6.6, h0 + 9.4, -2.6, 2.6, ic.DUCT)
i.quad(h0 + 1.2, h0 + 4.0, 1.6, 2.6, ic.DUCT_DARK)
i.quad(h0 + 6.6, h0 + 9.4, 1.6, 2.6, ic.DUCT_DARK)
i.save(HERE, "Item_CutleryMace.png")

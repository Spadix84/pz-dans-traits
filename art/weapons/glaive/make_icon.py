"""Draw the bread knife glaive's 32x32 inventory icon (see ../icon_common.py).

    python make_icon.py       writes Item_BreadKnifeGlaive.png and icon_preview_BreadKnifeGlaive.png
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import icon_common as ic  # noqa: E402

POLE, POLE_DARK, HANDLE = (156, 104, 62), (112, 72, 42), (104, 62, 36)

i = ic.Icon(butt=(2.5, 29.5), tip=(18.0, 14.0))
L, half = i.length, 1.05
b0, b1 = L - 0.6, L + 15.2                      # the blade runs on past the pole's end
# the blade, below the pole's line: spine, bright serrated grind, rounded tip
i.poly([(b0, 1.0), (b1 - 2.4, 1.0), (b1, 2.6), (b1 - 0.6, 4.3), (b0 + 1.0, 4.9), (b0, 4.3)], ic.STEEL)
i.poly([(b0, 3.4), (b1 - 0.2, 3.2), (b1 - 0.6, 4.3), (b0 + 1.0, 4.9), (b0, 4.3)], ic.STEEL_LIGHT)
u = b0 + 1.2
while u < b1 - 1.4:                              # the teeth
    i.poly([(u, 4.9), (u + 0.7, 4.0), (u + 1.4, 4.9)], ic.RIM)
    u += 1.9
# the pole
i.quad(0.0, L, -half, half, POLE)
i.quad(0.0, L, half - 0.5, half, POLE_DARK)
i.quad(2.0, 8.5, -half, half, POLE_DARK)
# the knife's handle under the pole's end, and two bands of duct tape round both
i.quad(L - 7.6, L - 0.2, half - 0.2, half + 2.5, HANDLE)
i.quad(L - 7.2, L - 5.2, -half - 0.45, half + 2.9, ic.DUCT)
i.quad(L - 2.6, L - 0.5, -half - 0.45, half + 2.9, ic.DUCT)
i.save(HERE, "Item_BreadKnifeGlaive.png")

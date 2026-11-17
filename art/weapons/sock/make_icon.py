"""Draw the 32x32 inventory icons of the lock in a sock and the sock flail (see
../icon_common.py).

    python make_icon.py       writes Item_LockInASock.png, Item_SockFlail.png and their enlarged previews
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import icon_common as ic  # noqa: E402

COTTON, SHADE, GRIME, LOCK = (228, 224, 212), (176, 172, 160), (140, 134, 120), (120, 120, 124)


def sock(i, u0, cuff):
    """The sock from u0 out to the icon's tip: thin, a knot, then the toe round the lock."""
    L = i.length
    k = L - 9.0                                  # the knot
    if cuff:                                     # the open end, with its two bands
        i.poly([(u0 - 0.4, -2.3), (u0 + 4.6, -1.5), (u0 + 4.6, 1.5), (u0 - 0.4, 2.3)], COTTON)
        i.quad(u0 + 0.9, u0 + 1.9, -2.2, 2.2, ic.RED)
        i.quad(u0 + 2.5, u0 + 3.5, -1.9, 1.9, ic.BLUE)
        u0 += 4.4
    i.poly([(u0, -1.3), (k, -1.0), (k, 1.0), (u0, 1.3)], COTTON)
    i.poly([(u0, 0.4), (k, 0.3), (k, 1.0), (u0, 1.3)], SHADE)
    i.poly([(k - 0.4, -1.7), (k + 1.6, -1.7), (k + 1.6, 1.7), (k - 0.4, 1.7)], COTTON)        # the knot
    i.quad(k + 1.5, k + 2.3, -0.9, 0.9, SHADE)
    # the toe, sagging a little towards the lower right, the padlock's body showing through
    i.poly([(k + 2.2, -1.2), (k + 4.4, -3.6), (L + 0.6, -3.2), (L + 2.4, -0.6), (L + 2.2, 2.6),
            (L - 0.2, 4.6), (k + 4.6, 4.4), (k + 2.2, 1.6)], COTTON)
    i.poly([(k + 2.2, 1.0), (L + 2.3, 1.4), (L + 2.2, 2.6), (L - 0.2, 4.6), (k + 4.6, 4.4), (k + 2.2, 1.6)], SHADE)
    i.poly([(k + 5.4, -1.9), (L + 0.6, -1.9), (L + 0.6, 2.9), (k + 5.4, 2.9)], LOCK)
    i.poly([(k + 6.0, -1.3), (L + 0.0, -1.3), (L + 0.0, 2.3), (k + 6.0, 2.3)], COTTON)
    i.poly([(k + 3.6, -0.9), (k + 5.4, -0.9), (k + 5.4, -0.3), (k + 4.2, -0.3), (k + 4.2, 1.3),
            (k + 5.4, 1.3), (k + 5.4, 1.9), (k + 3.6, 1.9)], LOCK)                         # the shackle
    i.poly([(L + 0.9, -2.6), (L + 2.4, -0.6), (L + 2.2, 2.6), (L + 0.9, 3.6)], GRIME)       # the worn toe


i = ic.Icon(butt=(4.0, 27.5), tip=(22.5, 9.0))
sock(i, 0.0, True)
i.save(HERE, "Item_LockInASock.png")

i = ic.Icon(butt=(3.0, 28.5), tip=(23.0, 8.5))
i.quad(0.0, 9.6, -1.25, 1.25, ic.WOOD)                                                     # the small handle
i.quad(0.0, 9.6, 0.55, 1.25, ic.WOOD_DARK)
i.quad(-0.8, 0.8, -1.7, 1.7, ic.WOOD)
sock(i, 9.0, False)
i.quad(8.0, 11.2, -1.9, 1.9, COTTON)                                                       # the cuff over the handle's end
i.quad(8.8, 10.6, -2.2, 2.2, ic.DUCT)
i.quad(8.8, 10.6, 1.2, 2.2, ic.DUCT_DARK)
i.save(HERE, "Item_SockFlail.png")

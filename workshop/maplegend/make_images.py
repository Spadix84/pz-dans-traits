"""Draw the Map Legend Workshop pictures: mock-ups of the legend, built from the
game's own map symbols tinted in the vanilla pen colours, rendered with headless
Chrome.

    python workshop/maplegend/make_images.py

writes, beside this script:
    preview.png   256x256   the Workshop thumbnail (also copied to MapLegend/42/poster.png)
    legend.png    1600x900  the legend on the map, one row hovered
    draw.png      1600x900  click a row to draw; the symbols panel's tooltips
    editor.png    1600x1200 the editor

The symbols are read from the game folder (media/ui/LootableMaps), white glyphs
the game tints with the pen colour; the colours are MapLegend_Core's
DEFAULT_COLORS. Edit the ENTRIES and the pages below, then run it again.
"""
import base64
import io
import os
import random
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
GAME = os.environ.get("PZ_GAME", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
GLYPHS = os.path.join(GAME, "media", "ui", "LootableMaps")
CHROME = os.environ.get("CHROME", r"C:\Program Files\Google\Chrome\Application\chrome.exe")

PENS = {   # MapLegend_Core DEFAULT_COLORS
    "Pen": (0.129, 0.129, 0.129),
    "Pencil": (0.2, 0.2, 0.2),
    "Red Pen": (0.65, 0.054, 0.054),
    "Blue Pen": (0.156, 0.188, 0.49),
    "Green Pen": (0.06, 0.39, 0.17),
}
FILES = {"Fire": "map_firet.png", "Circle": "map_o.png"}
OUTLINE = (255, 217, 51)   # the panel's HIGHLIGHT (1.0, 0.85, 0.2)

# what the pictures' legend holds: symbol, pen, meaning, how many are on the map
ENTRIES = [
    ("House", "Blue Pen", "Safehouse", 1),
    ("Skull", "Red Pen", "Horde", 4),
    ("Skull", "Pen", "Grave", 1),
    ("X", "Green Pen", "Cleared", 7),
    ("X", "Red Pen", "Danger", 2),
    ("MedCross", "Red Pen", "Pharmacy, back door open", 1),
    ("Fuel", "Pen", "Pumps work (generator)", 2),
    ("Waves", "Blue Pen", "Water", 2),
    ("Question", "Pencil", "To check", 5),
]
UNLISTED = 3


# icons ---------------------------------------------------------------------------------

def glyph(sym):
    path = os.path.join(GLYPHS, FILES.get(sym, "map_%s.png" % sym.lower()))
    return Image.open(path).convert("RGBA")


def tinted(sym, pen, outline=False, size=64):
    """The glyph multiplied by the pen colour, as the game draws it; with a
    yellow rim like the legend's renderOutline when `outline`."""
    g = glyph(sym).resize((size, size), Image.LANCZOS)
    r, gg, b = PENS[pen]
    px = [(int(p[0] * r), int(p[1] * gg), int(p[2] * b), p[3]) for p in g.get_flattened_data()]
    ink = Image.new("RGBA", g.size)
    ink.putdata(px)
    if not outline:
        return ink
    pad = size // 8
    canvas = Image.new("RGBA", (size + pad * 2, size + pad * 2))
    alpha = Image.new("L", canvas.size)
    alpha.paste(g.split()[3], (pad, pad))
    rim = alpha.filter(ImageFilter.MaxFilter(7)).point(lambda a: 255 if a > 40 else 0)
    glow = Image.new("RGBA", canvas.size, OUTLINE + (255,))
    glow.putalpha(rim)
    canvas.alpha_composite(glow)
    canvas.alpha_composite(ink, (pad, pad))
    return canvas


def uri(img):
    buf = io.BytesIO()
    img.save(buf, "PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


_cache = {}


def icon(sym, pen, outline=False):
    key = (sym, pen, outline)
    if key not in _cache:
        _cache[key] = uri(tinted(sym, pen, outline))
    return _cache[key]


# the map underneath ----------------------------------------------------------------------

def map_svg(w, h, seed=7):
    """A paper map in the colours of the game's world map: fields, woods, a river,
    roads and the buildings along them."""
    rnd = random.Random(seed)
    out = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % (w, h, w, h),
           '<rect width="100%" height="100%" fill="#e3dac2"/>']
    for _ in range(9):   # woods
        cx, cy, r = rnd.uniform(0, w), rnd.uniform(0, h), rnd.uniform(40, 110)
        pts = []
        for k in range(10):
            a = k / 10 * 6.283
            rr = r * rnd.uniform(0.7, 1.15)
            pts.append("%.0f,%.0f" % (cx + rr * __import__("math").cos(a), cy + rr * __import__("math").sin(a)))
        out.append('<polygon points="%s" fill="#bdc89f" stroke="#a9b68a" stroke-width="1"/>' % " ".join(pts))
    out.append('<path d="M %d -20 C %d %d, %d %d, %d %d S %d %d, %d %d" fill="none" stroke="#a7c4d1" stroke-width="26" stroke-linecap="round"/>'
               % (w * 0.62, w * 0.55, h * 0.3, w * 0.8, h * 0.45, w * 0.7, h * 0.7, w * 0.6, h * 0.95, w * 0.66, h + 30))
    roads = []
    for x in (0.18, 0.42, 0.86):
        roads.append(("v", w * x))
    for y in (0.22, 0.58, 0.84):
        roads.append(("h", h * y))
    for kind, at in roads:
        d = "M %.0f -10 L %.0f %d" % (at, at, h + 10) if kind == "v" else "M -10 %.0f L %d %.0f" % (at, w + 10, at)
        out.append('<path d="%s" stroke="#9b947f" stroke-width="13" fill="none"/>' % d)
        out.append('<path d="%s" stroke="#f6f1e4" stroke-width="10" fill="none"/>' % d)
    out.append('<path d="M -10 %d L %d -10" stroke="#9b947f" stroke-width="17" fill="none"/>' % (h * 0.95, w * 0.5))
    out.append('<path d="M -10 %d L %d -10" stroke="#f3e2a6" stroke-width="13" fill="none"/>' % (h * 0.95, w * 0.5))
    for kind, at in roads:   # houses along the roads
        span = h if kind == "v" else w
        p = rnd.uniform(5, 25)
        while p < span:
            s1, s2 = rnd.uniform(12, 24), rnd.uniform(12, 20)
            side = rnd.choice((-1, 1))
            off = 10 + rnd.uniform(0, 4)
            if kind == "v":
                x, y = at + side * off - (s2 if side < 0 else 0), p
                ww, hh = s2, s1
            else:
                x, y = p, at + side * off - (s2 if side < 0 else 0)
                ww, hh = s1, s2
            out.append('<rect x="%.0f" y="%.0f" width="%.0f" height="%.0f" fill="#c6bba3" stroke="#8f8571" stroke-width="1"/>' % (x, y, ww, hh))
            p += s1 + rnd.uniform(4, 16)
    out.append("</svg>")
    return "data:image/svg+xml;base64," + base64.b64encode("".join(out).encode()).decode()


# the page parts --------------------------------------------------------------------------

CSS = """
* { box-sizing: border-box; margin: 0; padding: 0; }
body { width: %(w)dpx; height: %(h)dpx; overflow: hidden; font-family: "Segoe UI", Arial, sans-serif;
       background: #e3dac2 url(%(map)s) no-repeat; position: relative; color: #fff; }
.sym { position: absolute; width: 22px; height: 22px; }
.sym.hl { width: 27.5px; height: 27.5px; margin: -2.75px 0 0 -2.75px; }
.panel { position: absolute; background: rgba(0,0,0,.84); border: 1px solid #666; }
.btn { position: absolute; height: 20px; padding: 0 10px; font-size: 12.5px; line-height: 18px; text-align: center;
       border: 1px solid rgba(255,255,255,.4); background: rgba(0,0,0,.6); color: #fff; }
.title { position: absolute; font-size: 16px; font-weight: 600; }
.row { position: absolute; left: 5px; right: 5px; height: 24px; }
.row.hover { background: rgba(255,217,51,.15); }
.row.pinned { background: rgba(255,217,51,.25); }
.tile { position: absolute; left: 5px; top: 2px; width: 20px; height: 20px; background: #808080; }
.tile img { width: 18px; height: 18px; margin: 1px; }
.txt { position: absolute; left: 35px; top: 3px; font-size: 13px; white-space: nowrap; }
.cnt { position: absolute; right: 5px; top: 3px; font-size: 13px; color: #999; }
.cnt.zero { color: #595959; }
.line { position: absolute; left: 10px; font-size: 13px; color: #999; white-space: nowrap; }
.note { color: #ffd933; }
.tip { position: absolute; background: rgba(0,0,0,.82); border: 1px solid #555; padding: 6px 9px; font-size: 13px; line-height: 19px; }
.tip .dim { color: #b3b3b3; }
.caption { position: absolute; background: rgba(28,24,18,.9); color: #f3ead2; padding: 7px 12px; font-size: 15px;
           border-left: 3px solid #ffd933; line-height: 20px; }
.caption b { color: #ffd933; font-weight: 600; }
"""


def legend(entries, left, bottom, width, hover=None, pinned=None, note=None, unlisted=UNLISTED):
    rows = []
    top = 38
    for i, (sym, pen, text, count) in enumerate(entries):
        cls = "row" + (" hover" if i == hover else "") + (" pinned" if i == pinned else "")
        rows.append('<div class="%s" style="top:%dpx"><div class="tile"><img src="%s"></div>'
                    '<div class="txt">%s</div><div class="cnt%s">x%d</div></div>'
                    % (cls, top + i * 24, icon(sym, pen), text, " zero" if count == 0 else "", count))
    y = top + len(entries) * 24 + 2
    lines = []
    if unlisted:
        lines.append('<div class="line" style="top:%dpx">%d on the map not in the legend</div>' % (y, unlisted))
        y += 17
    if note:
        lines.append('<div class="line note" style="top:%dpx">%s</div>' % (y, note))
        y += 17
    height = y + 6
    return ('<div class="panel" style="left:%dpx; bottom:%dpx; width:%dpx; height:%dpx">'
            '<div class="title" style="left:10px; top:8px">Legend</div>'
            '<div class="btn" style="right:36px; top:10px">Edit</div>'
            '<div class="btn" style="right:10px; top:10px; padding:0; width:20px">-</div>%s%s</div>'
            % (left, bottom, width, height, "".join(rows), "".join(lines)), height)


def placed(spots, outline_for=None):
    out = []
    for sym, pen, x, y in spots:
        hl = outline_for is not None and (sym, pen) == outline_for
        out.append('<img class="sym%s" style="left:%dpx; top:%dpx" src="%s">' % (" hl" if hl else "", x, y, icon(sym, pen, hl)))
    return "".join(out)


# where the entries sit on the map (CSS pixels of an 800x450 page)
SPOTS = [
    ("House", "Blue Pen", 352, 108),
    ("Skull", "Red Pen", 610, 40), ("Skull", "Red Pen", 742, 300), ("Skull", "Red Pen", 560, 395), ("Skull", "Red Pen", 455, 195),
    ("Skull", "Pen", 640, 345),
    ("X", "Green Pen", 300, 140), ("X", "Green Pen", 395, 160), ("X", "Green Pen", 450, 80), ("X", "Green Pen", 380, 235),
    ("X", "Green Pen", 300, 300), ("X", "Green Pen", 470, 300), ("X", "Green Pen", 640, 190),
    ("X", "Red Pen", 700, 120), ("X", "Red Pen", 600, 300),
    ("MedCross", "Red Pen", 520, 225),
    ("Fuel", "Pen", 410, 330), ("Fuel", "Pen", 705, 380),
    ("Waves", "Blue Pen", 530, 130), ("Waves", "Blue Pen", 555, 330),
    ("Question", "Pencil", 650, 80), ("Question", "Pencil", 770, 220), ("Question", "Pencil", 480, 400),
    ("Question", "Pencil", 330, 400), ("Question", "Pencil", 760, 30),
    ("Star", "Pencil", 690, 250), ("Tent", "Pen", 360, 60), ("Circle", "Blue Pen", 500, 40),
]


def page(w, h, body, seed=7):
    return ("<!doctype html><html><head><meta charset='utf-8'><style>%s</style></head><body>%s</body></html>"
            % (CSS % {"w": w, "h": h, "map": map_svg(w, h, seed)}, body))


def row_of(sym, pen):
    return next(i for i, e in enumerate(ENTRIES) if e[0] == sym and e[1] == pen)


def legend_page():
    hover = row_of("X", "Green Pen")
    panel, ph = legend(ENTRIES, 10, 10, 250, hover=hover)
    tip_top = 450 - 10 - ph + 38 + hover * 24
    tip = ('<div class="tip" style="left:268px; top:%dpx">Cleared<br>Green Pen, 7 on the map<br>'
           '<span class="dim">Click to draw with it.</span></div>' % tip_top)
    cap = ('<div class="caption" style="left:14px; top:14px; max-width:330px"><b>Your own map key.</b> '
           'A symbol in a pen colour, and what it means. Hover a row and its marks light up.</div>')
    return page(800, 450, placed(SPOTS, outline_for=("X", "Green Pen")) + panel + tip + cap)


def symbols_panel(left, top):
    """The vanilla symbols panel, with the legend's tooltip on the X."""
    tabs = '<div class="btn" style="left:8px; top:8px">Locations</div><div class="btn" style="left:92px; top:8px">Loot</div>' \
           '<div class="btn" style="left:140px; top:8px; border-color:#fff">Symbols</div>'
    pens = []
    for i, pen in enumerate(("Pen", "Pencil", "Red Pen", "Blue Pen", "Green Pen")):
        r, g, b = (int(c * 255) for c in PENS[pen])
        border = "#fff" if pen == "Red Pen" else "rgba(255,255,255,.35)"
        pens.append('<div style="position:absolute; left:%dpx; top:36px; width:36px; height:20px; background:rgb(%d,%d,%d); border:1px solid %s"></div>'
                    % (8 + i * 42, r, g, b, border))
    syms = ["Asterisk", "Checkmark", "Club", "Diamond", "Heart", "Spade", "Cross", "Exclamation", "FaceDead", "FaceHappy",
            "FaceSad", "Fire", "Leaf", "Lightning", "Moon", "Circle", "Question", "Radiation", "Skull", "Star", "Sun",
            "Triangle", "Snowflake", "Eye"]
    cells = []
    for i, s in enumerate(syms):
        x, y = 8 + (i % 8) * 28, 66 + (i // 8) * 28
        sel = s == "Skull"
        cells.append('<div style="position:absolute; left:%dpx; top:%dpx; width:24px; height:24px; background:#7a7a7a; %s">'
                     '<img src="%s" style="width:22px; height:22px; margin:1px"></div>'
                     % (x, y, "outline:2px solid #fff;" if sel else "", icon(s, "Red Pen")))
    return '<div class="panel" style="left:%dpx; top:%dpx; width:240px; height:160px">%s%s</div>' % (
        left, top, tabs + "".join(pens), "".join(cells))


def draw_page():
    # the panel widens to fit its note, as in the game
    panel, ph = legend(ENTRIES, 10, 10, 340, pinned=row_of("Skull", "Red Pen"), note="Click the map to draw it. Click the row again to stop.")
    sp = symbols_panel(548, 14)
    # the Skull's button (third row, third column) hovered: a line per pen
    sp_tip = '<div class="tip" style="left:624px; top:166px">Red Pen: Horde<br>Pen: Grave</div>'
    cursor = ('<img class="sym" style="left:470px; top:250px; opacity:.85" src="%s">'
              '<svg style="position:absolute; left:486px; top:266px" width="18" height="24" viewBox="0 0 18 24">'
              '<path d="M1 1 L1 19 L6 14 L9.5 22 L12.5 20.5 L9 13 L16 13 Z" fill="#fff" stroke="#000" stroke-width="1.3"/></svg>'
              % icon("Skull", "Red Pen"))
    spots = [s for s in SPOTS if not (s[0] == "Skull" and s[2] == 560)]
    cap = ('<div class="caption" style="left:14px; top:14px; max-width:300px"><b>Click a row to draw with it.</b> '
           'The symbol and its pen are picked for you, ready to place.</div>')
    cap2 = ('<div class="caption" style="left:556px; top:232px; max-width:230px"><b>The symbols panel knows too.</b> '
            'Hover a symbol to see what it means in each pen. Pick one and the pen switches to its legend colour.</div>')
    return page(800, 450, placed(spots, outline_for=("Skull", "Red Pen")) + panel + sp + sp_tip + cursor + cap + cap2, seed=11)


def editor_page():
    w, h = 800, 600
    left, top, width = 280, 20, 470
    rows = []
    for i, (sym, pen, text, _) in enumerate(ENTRIES[:6]):
        sel = (sym, pen) == ("MedCross", "Red Pen")   # the entry in the form below
        rows.append('<div style="position:absolute; left:0; right:0; top:%dpx; height:26px; border-bottom:1px solid rgba(255,255,255,.12);%s">'
                    '<div class="tile" style="top:3px"><img src="%s"></div><div class="txt" style="top:4px">%s</div></div>'
                    % (i * 26, " background:rgba(179,89,38,.3);" if sel else "", icon(sym, pen), text))
    lst = '<div style="position:absolute; left:10px; top:66px; width:%dpx; height:156px; border:1px solid #555; background:rgba(0,0,0,.4)">%s</div>' % (width - 20, "".join(rows))
    btns = ('<div class="btn" style="left:10px; top:228px">Up</div><div class="btn" style="left:50px; top:228px">Down</div>'
            '<div class="btn" style="left:104px; top:228px">Remove</div><div class="btn" style="right:10px; top:228px">New entry</div>')
    labels = ('<div class="txt" style="left:10px; top:264px">Symbol</div>'
              '<div class="btn" style="left:10px; top:284px; border-color:#fff">Locations</div>'
              '<div class="btn" style="left:94px; top:284px">Loot</div><div class="btn" style="left:142px; top:284px">Symbols</div>')
    locs = ["ArrowEast", "ArrowNorth", "ArrowSouth", "ArrowWest", "ArrowNorthWest", "ArrowNorthEast", "ArrowSouthWest",
            "ArrowSouthEast", "House", "Lock", "MedCross", "Target", "Tent", "Trap", "Waves", "X", "Z", "Tree", "Skyscraper",
            "Police", "Pawprint", "Ladder", "Furnace", "Door", "CrossedSwords", "Columns", "Book", "Bed"]
    cells = []
    for i, s in enumerate(locs):
        x, y = 1 + (i % 15) * 29 + 4, 1 + (i // 15) * 29 + 4
        sel = s == "MedCross"
        cells.append('<div style="position:absolute; left:%dpx; top:%dpx; width:24px; height:24px; background:#808080;%s">'
                     '<img src="%s" style="width:22px; height:22px; margin:1px"></div>'
                     % (x, y, " outline:2px solid #fff; outline-offset:2px;" if sel else "", icon(s, "Red Pen")))   # the grid draws in the picked pen
    grid = '<div style="position:absolute; left:10px; top:310px; width:%dpx; height:66px; border:1px solid #666; background:rgba(0,0,0,.4)">%s</div>' % (width - 20, "".join(cells))
    pens = ['<div class="txt" style="left:10px; top:382px">Colour</div>']
    for i, pen in enumerate(PENS):
        r, g, b = (int(c * 255) for c in PENS[pen])
        sel = pen == "Red Pen"
        pens.append('<div style="position:absolute; left:%dpx; top:402px; width:40px; height:20px; background:rgb(%d,%d,%d); border:1px solid %s"></div>'
                    % (10 + i * 46, r, g, b, "#fff" if sel else "rgba(255,255,255,.4)"))
    meaning = ('<div class="txt" style="left:10px; top:434px">Meaning</div>'
               '<div class="btn" style="left:10px; top:454px; width:180px; text-align:left">Presets... <span style="float:right">&#9662;</span></div>'
               '<div style="position:absolute; left:196px; top:454px; width:264px; height:20px; border:1px solid #777; background:rgba(0,0,0,.6);'
               ' font-size:13px; padding:1px 5px">Pharmacy, back door open<span style="border-left:1px solid #fff; margin-left:1px"></span></div>')
    save = ('<div class="btn" style="left:10px; top:486px; width:222px">Save changes</div>'
            '<div class="btn" style="left:238px; top:486px; width:222px">Close</div>'
            '<div class="txt" style="left:10px; top:512px; color:#cccc80">Saved.</div>')
    head = ('<div style="position:absolute; left:0; top:0; right:0; height:20px; background:rgba(60,60,60,.95); border-bottom:1px solid #555;'
            ' font-size:13px; text-align:center; line-height:19px">Map Legend</div>'
            '<div style="position:absolute; left:10px; top:30px; width:14px; height:14px; border:1px solid #aaa"></div>'
            '<div class="txt" style="left:30px; top:28px">This character keeps its own legend</div>'
            '<div class="txt" style="left:10px; top:46px; color:#bfbfbf">Editing the profile: every character without its own legend uses it.</div>')
    win = ('<div class="panel" style="left:%dpx; top:%dpx; width:%dpx; height:536px">%s%s%s%s%s%s%s%s</div>'
           % (left, top, width, head, lst, btns, labels, grid, "".join(pens), meaning, save))
    panel, _ = legend(ENTRIES, 10, 10, 260)
    cap = ('<div class="caption" style="left:14px; top:14px; max-width:250px"><b>Any symbol, any pen.</b> '
           'Type what it means or pick a preset. Saved to your profile for every save, or kept per character.</div>')
    shade = '<div style="position:absolute; inset:0; background:rgba(0,0,0,.25)"></div>'
    return page(w, h, placed(SPOTS) + shade + panel + win + cap, seed=5)


def preview_page():
    s = 256
    spots = [("Skull", "Red Pen", 196, 66), ("X", "Green Pen", 205, 150), ("House", "Blue Pen", 200, 206), ("X", "Green Pen", 70, 64),
             ("Waves", "Blue Pen", 130, 66)]
    rows = [("Skull", "Red Pen", "Horde"), ("X", "Green Pen", "Cleared"), ("House", "Blue Pen", "Safehouse")]
    body = []
    for sym, pen, x, y in spots:
        body.append('<img style="position:absolute; left:%dpx; top:%dpx; width:30px; height:30px" src="%s">' % (x, y, icon(sym, pen)))
    items = "".join('<div style="height:30px; position:relative"><div style="position:absolute; left:0; top:3px; width:24px; height:24px; background:#808080">'
                    '<img src="%s" style="width:22px; height:22px; margin:1px"></div><div style="position:absolute; left:32px; top:3px; font-size:17px">%s</div></div>'
                    % (icon(sym, pen), text) for sym, pen, text in rows)
    body.append('<div class="panel" style="left:14px; bottom:14px; width:156px; padding:8px 10px 6px">%s</div>' % items)
    body.append('<div style="position:absolute; left:0; right:0; top:0; height:50px; background:rgba(28,24,18,.9);'
                ' border-bottom:3px solid #ffd933; color:#ffd933; font-weight:700; font-size:29px; letter-spacing:2px;'
                ' text-align:center; line-height:48px">MAP LEGEND</div>')
    return page(s, s, "".join(body), seed=3)


def render(html, out, w, h, scale):
    tmp = tempfile.mkdtemp(prefix="maplegend-")
    try:
        src = os.path.join(tmp, "page.html")
        with open(src, "w", encoding="utf-8") as f:
            f.write(html)
        subprocess.run([CHROME, "--headless=new", "--hide-scrollbars", "--force-device-scale-factor=%g" % scale,
                        "--user-data-dir=" + os.path.join(tmp, "profile"), "--window-size=%d,%d" % (w, h),
                        "--screenshot=" + out, "file:///" + src.replace("\\", "/")],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print("wrote", os.path.relpath(out, REPO), Image.open(out).size)


def main():
    render(legend_page(), os.path.join(HERE, "legend.png"), 800, 450, 2)
    render(draw_page(), os.path.join(HERE, "draw.png"), 800, 450, 2)
    render(editor_page(), os.path.join(HERE, "editor.png"), 800, 600, 2)
    big = os.path.join(HERE, "preview-512.png")
    render(preview_page(), big, 256, 256, 2)
    img = Image.open(big).convert("RGB").resize((256, 256), Image.LANCZOS)
    os.remove(big)
    img.save(os.path.join(HERE, "preview.png"))
    img.save(os.path.join(REPO, "MapLegend", "42", "poster.png"))
    print("wrote workshop/maplegend/preview.png and MapLegend/42/poster.png (256, 256)")


if __name__ == "__main__":
    sys.exit(main())

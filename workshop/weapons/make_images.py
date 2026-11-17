"""Draw the Dan's Weapons Workshop pictures: Blender renders of the mod's own models, laid
out with headless Chrome.

    python workshop/weapons/make_images.py              render, then lay out
    python workshop/weapons/make_images.py --no-render  lay out from the renders already there

writes, beside this script:
    preview.png   256x256   the Workshop thumbnail (also copied to DansWeapons/42/poster.png)
    lineup.png    1600x900  the five weapons from the side at one scale, with their numbers
    recipes.png   1600x900  a card each: what it is made from, where, and what is left of it

The numbers come from the mod's item script and the names from its translation, so the
pictures cannot drift from the game; what goes into each weapon is written out in CARDS
below (and checked against the recipe script's inputs). renders/ holds Blender's raw
pictures (render_weapons.py) and is not committed.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
MOD = os.path.join(REPO, "DansWeapons")
RENDERS = os.path.join(HERE, "renders")
CHROME = os.environ.get("CHROME", r"C:\Program Files\Google\Chrome\Application\chrome.exe")
BLENDER = os.environ.get("BLENDER", r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe")

ORDER = ["HockeyStickCleaver", "BreadKnifeGlaive", "CutleryMace", "LockInASock", "SockFlail"]
SKILL = {"base:axe": "Axe", "base:longblade": "Long Blade", "base:smallblunt": "Short Blunt"}
# what the page says about making each one; `needs` are the item types its Make recipe
# must name, so a changed recipe fails here instead of leaving the picture wrong
CARDS = {
    "HockeyStickCleaver": {
        "line": "A hand axe's cut at a hockey stick's reach.",
        "make": ["Ice hockey stick", "Meat cleaver", "2 duct tape", "Wire or electric wire", "Pliers (kept)"],
        "where": "On any surface",
        "apart": "The cleaver and the stick, each with its own wear",
        "breaks": "The cleaver drops; a broken stick is left in your hands",
        "needs": ["Base.IceHockeyStick", "Base.MeatCleaver", "Base.DuctTape", "Base.Wire", "base:pliers"],
    },
    "BreadKnifeGlaive": {
        "line": "The knife nobody takes, on the broom nobody takes.",
        "make": ["Bread knife", "<b>Long handle</b>, broom or mop", "2 duct tape"],
        "where": "On any surface",
        "apart": "The bread knife and a long handle",
        "breaks": "The knife drops; a broken long handle is left",
        "needs": ["Base.BreadKnife", "Base.LongHandle", "Base.Broom", "Base.Mop", "Base.DuctTape"],
    },
    "CutleryMace": {
        "line": "The cutlery drawer, taped round a club. It draws blood.",
        "make": ["<b>Handle</b> or rolling pin", "3 forks", "3 butter knives", "3 duct tape"],
        "where": "On any surface",
        "apart": "It stays a mace",
        "breaks": "One fork and one butter knife drop; the handle is done for",
        "needs": ["Base.Handle", "Base.RollingPin", "Base.Fork", "Base.ButterKnife", "Base.DuctTape"],
    },
    "LockInASock": {
        "line": "Quick, light, and made in a moment with nothing else.",
        "make": ["A pair of long or heavy socks", "Padlock"],
        "where": "In your hands, no tools",
        "apart": "The padlock and the socks",
        "breaks": "The padlock drops; a rag is left in your hand",
        "needs": ["Base.Socks_Long", "Base.Socks_Heavy", "Base.Padlock"],
    },
    "SockFlail": {
        "line": "The same on a handle: more reach, a harder hit.",
        "make": ["Lock in a Sock", "<b>Small handle</b>", "1 duct tape"],
        "where": "In your hands",
        "apart": "It stays a flail",
        "breaks": "The padlock drops; the small handle is left",
        "needs": ["Base.LockInASock", "Base.SmallHandle", "Base.DuctTape"],
    },
}

CSS = """
* { box-sizing: border-box; margin: 0; padding: 0; }
body { width: %(w)dpx; height: %(h)dpx; overflow: hidden; font-family: "Segoe UI", Arial, sans-serif;
       background: radial-gradient(ellipse at 30%% 0%%, #2b3138 0%%, #15181c 70%%); color: #f3ead2; position: relative; }
.head { position: absolute; left: 0; right: 0; top: 0; height: 44px; background: rgba(28,24,18,.92);
        border-bottom: 3px solid #ffd933; padding: 0 18px; line-height: 42px; font-size: 21px; font-weight: 600; }
.head span { color: #ffd933; }
.head small { float: right; font-size: 13px; color: #a59d88; font-weight: 400; }
.foot { position: absolute; left: 18px; right: 18px; bottom: 10px; font-size: 13px; color: #a59d88; }
.foot i { font-style: normal; color: #f3ead2; }
b { font-weight: 600; }

.rows { position: absolute; left: 0; right: 0; top: 47px; }
.row { display: flex; align-items: center; border-bottom: 1px solid rgba(255,255,255,.07); padding: 0 34px; }
.row:last-child { border-bottom: 0; }
.row .text { width: 500px; flex: none; }
.row .name { font-size: 27px; font-weight: 600; color: #ffd933; line-height: 32px; }
.row .kind { font-size: 15px; color: #a59d88; line-height: 21px; }
.row .nums { font-size: 16px; line-height: 23px; }
.row .nums b { color: #ffd933; }
.row img { display: block; filter: drop-shadow(0 5px 6px rgba(0,0,0,.55)); }

.cards { position: absolute; left: 24px; right: 24px; top: 62px; bottom: 40px; display: flex; gap: 14px; }
.card { flex: 1; background: rgba(28,24,18,.80); border: 1px solid rgba(255,255,255,.08);
        border-top: 3px solid #ffd933; padding: 0 16px 14px; display: flex; flex-direction: column; }
.card .pic { height: 286px; margin: 10px -6px 6px; display: flex; align-items: center; justify-content: center; }
.card .pic img { max-width: 100%%; max-height: 100%%; filter: drop-shadow(0 5px 6px rgba(0,0,0,.55)); }
.card .name { font-size: 22px; font-weight: 600; color: #ffd933; line-height: 28px; }
.card .kind { font-size: 13.5px; color: #a59d88; line-height: 19px; }
.card .line { font-size: 14.5px; line-height: 20px; margin: 8px 0 4px; min-height: 40px; }
.card h4 { font-size: 11.5px; letter-spacing: .09em; text-transform: uppercase; color: #a59d88; font-weight: 600;
           margin: 12px 0 4px; }
.card ul { list-style: none; }
.card li { font-size: 15px; line-height: 22px; padding-left: 14px; position: relative; }
.card li:before { content: ""; position: absolute; left: 0; top: 9px; width: 5px; height: 5px; background: #ffd933; }
.card li b { color: #ffd933; }
.card p { font-size: 14.5px; line-height: 20px; }

.thumb { position: absolute; left: 0; top: 0; right: 0; bottom: 0; }
.thumb img { position: absolute; filter: drop-shadow(0 4px 5px rgba(0,0,0,.6)); }
.thumb .title { position: absolute; left: 0; right: 0; bottom: 0; height: 46px; background: rgba(28,24,18,.94);
                border-top: 3px solid #ffd933; text-align: center; line-height: 41px; font-size: 24px; font-weight: 700;
                letter-spacing: .02em; color: #ffd933; }
"""


def page(w, h, body):
    return '<!doctype html><html><head><meta charset="utf-8"><style>%s</style></head><body>%s</body></html>' % (
        CSS % {"w": w, "h": h}, body)


def render(html, out, w, h, scale=1):
    """Chrome wants absolute paths: a relative --screenshot is silently written nowhere."""
    out = os.path.abspath(out)
    tmp = tempfile.mkdtemp(prefix="weapons-")
    try:
        src = os.path.join(tmp, "page.html")
        with open(src, "w", encoding="utf-8") as f:
            f.write(html)
        subprocess.run([CHROME, "--headless=new", "--hide-scrollbars", "--force-device-scale-factor=%g" % scale,
                        "--allow-file-access-from-files", "--user-data-dir=" + os.path.join(tmp, "profile"),
                        "--window-size=%d,%d" % (w, h), "--screenshot=" + out, "file:///" + src.replace("\\", "/")],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print("wrote", os.path.relpath(out, REPO), Image.open(out).size)


# the mod's own data -----------------------------------------------------------------------
def blocks(text, kind):
    """{name: body} for every `kind name { ... }` block of a script file."""
    out = {}
    for m in re.finditer(r"\b%s\s+(\w+)\s*\{" % kind, text):
        depth, i = 1, m.end()
        while depth:
            depth += {"{": 1, "}": -1}.get(text[i], 0)
            i += 1
        out[m.group(1)] = text[m.end():i - 1]
    return out


def weapons():
    scripts = os.path.join(MOD, "42", "media", "scripts")
    with open(os.path.join(scripts, "DansWeapons_items.txt"), encoding="utf-8") as f:
        items = blocks(re.sub(r"/\*.*?\*/", "", f.read(), flags=re.S), "item")
    with open(os.path.join(scripts, "DansWeapons_recipes.txt"), encoding="utf-8") as f:
        recipes = blocks(re.sub(r"/\*.*?\*/", "", f.read(), flags=re.S), "craftRecipe")
    with open(os.path.join(MOD, "42", "media", "lua", "shared", "Translate", "EN", "ItemName.json"),
              encoding="utf-8") as f:
        names = json.load(f)
    if sorted(items) != sorted(ORDER) or sorted(CARDS) != sorted(ORDER):
        raise SystemExit("the item script has %s; ORDER and CARDS here must list the same" % sorted(items))
    out = []
    for key in ORDER:
        f = dict(re.findall(r"^\s*(\w+)\s*=\s*(.+?),?\s*$", items[key], flags=re.M))
        skill = next(SKILL[c] for c in f["Categories"].split(";") if c in SKILL)
        make = recipes["Make" + key]
        missing = [n for n in CARDS[key]["needs"] if n not in make]
        if missing:
            raise SystemExit("Make%s no longer names %s: bring CARDS up to date" % (key, ", ".join(missing)))
        out.append(dict(CARDS[key], key=key, name=names["Base." + key], skill=skill,
                        hands="two hands" if f.get("TwoHandWeapon") == "true" else "one hand",
                        lo=f["MinDamage"], hi=f["MaxDamage"], reach=f["MaxRange"], weight=f["Weight"],
                        cond=f["ConditionMax"]))
    return out


def cropped(name, tmp):
    """A render trimmed to what is in it, as a file URL and its size."""
    img = Image.open(os.path.join(RENDERS, name)).convert("RGBA")
    img = img.crop(img.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox())
    path = os.path.join(tmp, name)
    img.save(path)
    return "file:///" + path.replace("\\", "/"), img.size


# the pictures -----------------------------------------------------------------------------
def lineup_page(ws, tmp):
    """Five rows, every weapon at the same scale; the rows share out the height by how
    tall each weapon is."""
    w, h, gap, top, bottom = 1600, 900, 26, 47, 36
    pics = [cropped("side_%s.png" % x["key"], tmp) for x in ws]
    room = h - top - bottom - gap * len(ws)
    s = min(room / sum(sz[1] for _, sz in pics), 960.0 / max(sz[0] for _, sz in pics))
    rows = []
    for x, (url, (pw, ph)) in zip(ws, pics):
        rows.append(
            '<div class="row" style="height:%dpx"><div class="text"><div class="name">%s</div>'
            '<div class="kind">%s, %s</div>'
            '<div class="nums">Damage <b>%s to %s</b> &nbsp; Reach <b>%s</b> &nbsp; Weight <b>%s</b></div></div>'
            '<img src="%s" width="%d" height="%d"></div>' % (
                round(ph * s) + gap, x["name"], x["skill"], x["hands"], x["lo"], x["hi"], x["reach"], x["weight"],
                url, round(pw * s), round(ph * s)))
    body = ('<div class="head"><span>Dan\'s Weapons</span> &nbsp;five to make from what is in the house'
            '<small>Project Zomboid, Build 42</small></div><div class="rows">%s</div>'
            '<div class="foot">All five at the same scale, as they are in the game. <i>No skill, nothing to learn.</i> '
            'For comparison: a hand axe does 0.7 to 1.5 at reach 1.1, a nightstick 0.6 to 1.1 at 1.2.</div>'
            % "".join(rows))
    return page(w, h, body)


def recipes_page(ws, tmp):
    cards = []
    for x in ws:
        url, _ = cropped("hero_%s.png" % x["key"], tmp)
        cards.append(
            '<div class="card"><div class="pic"><img src="%s"></div><div class="name">%s</div>'
            '<div class="kind">%s, %s</div><div class="line">%s</div>'
            '<h4>Make it from</h4><ul>%s</ul><h4>Where</h4><p>%s</p>'
            '<h4>Taken apart</h4><p>%s</p><h4>When it breaks</h4><p>%s</p></div>' % (
                url, x["name"], x["skill"], x["hands"], x["line"],
                "".join("<li>%s</li>" % m for m in x["make"]), x["where"], x["apart"], x["breaks"]))
    body = ('<div class="head"><span>Dan\'s Weapons</span> &nbsp;what goes into each'
            '<small>Weaponry recipes, nothing to learn</small></div><div class="cards">%s</div>'
            '<div class="foot">The three handle sizes are each a way in: <i>long handle</i>, <i>handle</i>, '
            '<i>small handle</i>. The stick\'s, pole\'s or handle\'s wear carries over to the weapon, '
            'and so does the cleaver\'s or the knife\'s.</div>' % "".join(cards))
    return page(1600, 900, body)


def preview_page(tmp):
    url, (pw, ph) = cropped("hero_HockeyStickCleaver.png", tmp)
    s = 262.0 / pw
    body = ('<div class="thumb"><img src="%s" width="%d" height="%d" style="left:%dpx;top:%dpx">'
            '<div class="title">Dan\'s Weapons</div></div>' % (url, round(pw * s), round(ph * s), -14, 12))
    return page(256, 256, body)


def main():
    if "--no-render" not in sys.argv[1:]:
        subprocess.run([BLENDER, "--background", "--factory-startup", "--python",
                        os.path.join(HERE, "render_weapons.py"), "--", "--out", RENDERS],
                       check=True, stdout=subprocess.DEVNULL)
    ws = weapons()
    tmp = tempfile.mkdtemp(prefix="weapons-pics-")
    try:
        render(lineup_page(ws, tmp), os.path.join(HERE, "lineup.png"), 1600, 900)
        render(recipes_page(ws, tmp), os.path.join(HERE, "recipes.png"), 1600, 900)
        big = os.path.join(tmp, "preview-512.png")
        render(preview_page(tmp), big, 256, 256, 2)
        img = Image.open(big).convert("RGB").resize((256, 256), Image.LANCZOS)
        img.save(os.path.join(HERE, "preview.png"))
        img.save(os.path.join(MOD, "42", "poster.png"))
        print("wrote workshop/weapons/preview.png and DansWeapons/42/poster.png (256, 256)")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()

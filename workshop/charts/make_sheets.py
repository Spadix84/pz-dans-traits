"""Build the Workshop icon sheets from the mod's own icons and English text.

    python workshop/charts/make_sheets.py     writes workshop/charts/sheet-*.html

Each sheet is 1920x1080 (Steam's carousel shape). Render them to PNG with
headless Chrome, as for the other charts:

    chrome --headless=new --hide-scrollbars --force-device-scale-factor=1
           --window-size=1920,1080 --screenshot=workshop/sheet-traits.png
           file:///.../workshop/charts/sheet-traits.html
"""
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
MEDIA = os.path.join(HERE, "..", "..", "DanTraits", "42", "media")
EN = os.path.join(MEDIA, "lua", "shared", "Translate", "EN")
VERSION = "1.2.0"

RETIRED = {"jinxed", "ironstomach", "bouncesback"}
AGE = ["age20s", "age30s", "age40s", "age50s"]
AGE_ONLY = [("green", "20s"), ("quickstudy", "20s"), ("bottomlesspit", "20s"),
            ("paceyourself", "40s"), ("settled", "40s"),
            ("readingglasses", "40s, 50s"), ("badback", "40s, 50s"), ("badknees", "40s, 50s"),
            ("oldhand", "40s, 50s"), ("delicatestomach", "40s, 50s"),
            ("oldinjury", "50s"), ("setinways", "50s"), ("seenitall", "50s"),
            ("castiron", "50s"), ("oldbones", "50s")]
# vanilla traits the mod reworks: they keep the game's own icon, so they are named, not drawn
REWORKED = "Smoker, Fear of Blood, Resilient, Iron Gut, Keen Cook, Outdoorsman and Cat's Eyes"
# moodle icon -> the name of what it tracks (the levels say how bad)
MOODLE_TITLES = {"AirwayIrritation": "Asthma", "BloodLoss": "Blood loss", "BloodSugar": "Blood sugar",
                 "ChestPain": "Heart", "Filthy": "Grime (Germaphobe)", "Infection": "Wound infection",
                 "LowIron": "Low iron (Anaemic)", "MSFlare": "MS flare", "MSHeat": "MS heat",
                 "Seizure": "Epilepsy", "Spoons": "Spoons (MS)", "StiffJoints": "Arthritis",
                 "TriptanAfter": "Sumatriptan, the day after", "WeakHeart": "After a heart attack"}
# items with no tooltip of their own
ITEM_DESC = {"InsulinMag": "Health magazine. Teaches the exact insulin dose for any food, at any First Aid level."}
# traits whose description is flavour only
TRAIT_DESC = {"renfaire": "+1 Spear, Long Blade, Axe and Blacksmithing. Every summer at the faire turns out to have been training."}


def load(name):
    with open(os.path.join(EN, name), encoding="utf-8") as f:
        return json.load(f)


def icon_url(*parts):
    # relative to the sheet, so the HTML renders from any checkout
    return os.path.relpath(os.path.join(MEDIA, *parts), HERE).replace("\\", "/")


def lines(text):
    return [l.strip() for l in (text or "").split("<br>") if l.strip()]


def traits():
    ui = load("UI.json")
    with open(os.path.join(MEDIA, "scripts", "DanTraits.txt"), encoding="utf-8") as f:
        script = f.read()
    out = {}
    for m in re.finditer(r"character_trait_definition DanTraits:(\S+)\s*\{(.*?)\}", script, re.S):
        tid, body = m.group(1), m.group(2)
        if tid in RETIRED:
            continue
        cost = int(re.search(r"Cost = (-?\d+)", body).group(1))
        name = ui.get(re.search(r"UIName = (\S+),", body).group(1), tid)
        desc = [l for l in lines(ui.get(re.search(r"UIDescription = (\S+),", body).group(1)))
                if not re.search(r"\b(20s|30s|40s|50s)( and \d0s)? only\.", l)]
        if tid in TRAIT_DESC:
            desc = [TRAIT_DESC[tid]]
        out[tid] = {"id": tid, "cost": cost, "name": name, "desc": desc}
    return out


def cost_text(c):
    return "+%d" % c if c > 0 else str(c)


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


PAGE = """<!doctype html>
<html><head><meta charset="utf-8"><title>{title}</title>
<style>
  html, body {{ margin: 0; background: #1b2838; color: #e6edf3; font-family: "Segoe UI", Arial, sans-serif; }}
  body {{ width: 1920px; height: 1080px; overflow: hidden; position: relative; }}
  .wrap {{ padding: 34px 56px 0 56px; }}
  h1 {{ margin: 0; font-size: 40px; font-weight: 600; }}
  h1 span {{ color: #66c0f4; }}
  .sub {{ margin: 6px 0 22px 0; font-size: 19px; color: #8fa3b7; }}
  .grid {{ display: grid; grid-template-columns: repeat({cols}, 1fr); gap: {gap}px 28px; }}
  .cell {{ display: grid; grid-template-columns: {box}px 1fr; gap: 16px; align-items: center;
          background: #223a50; border-radius: 6px; padding: 10px 14px; min-height: {box}px; }}
  .ic {{ width: {box}px; height: {box}px; display: grid; place-items: center; background: #16202d; border-radius: 4px; }}
  .ic img {{ width: {img}px; height: {img}px; image-rendering: pixelated; }}
  .nm {{ font-size: 21px; font-weight: 600; color: #fff; line-height: 1.15; }}
  .nm small {{ font-size: 17px; font-weight: 600; margin-left: 8px; }}
  .neg {{ color: #ef8c78; }} .pos {{ color: #8fc98a; }} .zero {{ color: #8fa3b7; }}
  .band {{ font-size: 14px; color: #66c0f4; text-transform: uppercase; letter-spacing: 1.2px; margin-left: 8px; }}
  .ds {{ font-size: {ds}px; color: #c6d4df; line-height: 1.3; margin-top: 3px; }}
  .head {{ grid-column: 1 / -1; font-size: 15px; color: #8fc9f0; text-transform: uppercase; letter-spacing: 1.6px; margin-top: 6px; }}
  .foot {{ position: absolute; left: 56px; right: 56px; bottom: 24px; font-size: 16px; color: #8fa3b7; display: flex; justify-content: space-between; }}
</style></head>
<body><div class="wrap">
<h1>{h1}</h1>
<div class="sub">{sub}</div>
<div class="grid">
{cells}
</div></div>
<div class="foot"><span>{note}</span><span>Vitality Project {version} &middot; Project Zomboid Build 42</span></div>
</body></html>
"""


def cell(icon, name, cost=None, band=None, desc=""):
    tag = ""
    if cost is not None:
        cls = "neg" if cost < 0 else "pos" if cost > 0 else "zero"
        tag = '<small class="%s">%s</small>' % (cls, cost_text(cost))
    if band:
        tag += '<span class="band">%s</span>' % band
    return ('<div class="cell"><div class="ic"><img src="%s"></div><div><div class="nm">%s%s</div>'
            '<div class="ds">%s</div></div></div>' % (icon, esc(name), tag, esc(desc)))


def trait_cell(t, band=None, n=2):
    return cell(icon_url("ui", "Traits", "trait_%s.png" % t["id"]), t["name"], t["cost"], band, " ".join(t["desc"][:n]))


def write(slug, **kw):
    kw.setdefault("version", VERSION)
    with open(os.path.join(HERE, "sheet-%s.html" % slug), "w", encoding="utf-8", newline="\n") as f:
        f.write(PAGE.format(**kw))


def main():
    t = traits()
    age_ids = set(AGE) | {a for a, _ in AGE_ONLY}
    neg = sorted((v for k, v in t.items() if v["cost"] < 0 and k not in age_ids), key=lambda v: (v["cost"], v["name"]))
    pos = sorted((v for k, v in t.items() if v["cost"] > 0 and k not in age_ids), key=lambda v: (-v["cost"], v["name"]))

    write("conditions", title="Conditions", cols=3, gap=12, box=60, img=54, ds=15,
          h1="The conditions <span>you can start with</span>",
          sub="Every one plugs into the health systems: blood, infection, pain, medication, sleep and Vitality.",
          cells="\n".join(trait_cell(v) for v in neg),
          note="Also reworked from vanilla: Smoker and Fear of Blood.")

    write("perks", title="Perks", cols=2, gap=30, box=72, img=54, ds=18,
          h1="The perks <span>that pay for them</span>",
          sub="Some fold a vanilla trait in; most lean on the same health systems the conditions do.",
          cells="\n".join(trait_cell(v, n=3) for v in pos),
          note="Also reworked from vanilla: Resilient, Iron Gut, Keen Cook, Outdoorsman and Cat's Eyes.")

    cells = ['<div class="head">Pick a decade first</div>']
    cells += [trait_cell(t[a], n=1) for a in AGE]
    cells += ['<div class="head">Then the traits only that age can take</div>']
    cells += [trait_cell(t[a], band=b, n=1) for a, b in AGE_ONLY]
    write("age", title="Age", cols=4, gap=22, box=64, img=54, ds=15,
          h1="Age: <span>the young recover, the old know their trade</span>",
          sub="Every character carries an Age. It changes how the body heals, trains and handles drink and pills, and what other traits cost.",
          cells="\n".join(cells),
          note="Strong, Athletic, Stout, Fit, Fast and Slow Learner and Hearty Appetite are priced by age.")

    mo = load("Moodles.json")
    moodles = []
    for f in sorted(os.listdir(os.path.join(MEDIA, "ui"))):
        if not f.endswith(".png"):
            continue
        key = f[:-4]
        sides, single = [], None
        for side in ("Good", "Bad"):
            levels = []
            for lvl in range(1, 5):
                v = mo.get("Moodles_%s_%s_lvl%d" % (key, side, lvl), "")
                if v and v not in levels:
                    levels.append(v)
                    single = single or mo.get("Moodles_%s_%s_desc_lvl%d" % (key, side, lvl), "")
            if levels:
                sides.append(levels)
        if not sides:
            continue
        title = MOODLE_TITLES.get(key) or re.sub(r"(?<=[a-z])(?=[A-Z])", " ", key).capitalize()
        if len(sides) == 1 and len(sides[0]) == 1:
            desc = sides[0][0] + ": " + single
        else:
            desc = "  |  ".join(" → ".join(levels) for levels in sides)
        moodles.append((title, desc, f))
    write("moodles", title="Moodles", cols=3, gap=10, box=56, img=48, ds=15,
          h1="%d new moodles <span>so you always know why</span>" % len(moodles),
          sub="Every lasting effect shows up beside the game's own, level by level. Moodle Framework draws them.",
          cells="\n".join(cell(icon_url("ui", f), title, desc=desc) for title, desc, f in moodles),
          note="The vanilla Angry moodle now has teeth too: rough on weapons, sloppy, loud.")

    names, tips = load("ItemName.json"), load("Tooltip.json")
    items = []
    for f in sorted(os.listdir(os.path.join(MEDIA, "textures"))):
        m = re.match(r"Item_(\w+)\.png$", f)
        if not m:
            continue
        iid = m.group(1)
        name = names.get("DanTraits." + iid, iid)
        tip = lines(tips.get("Tooltip_DanTraits_" + iid, ""))
        n = 2
        while n < len(tip) and tip[n - 1].endswith(","):
            n += 1
        items.append(cell(icon_url("textures", f), name, desc=ITEM_DESC.get(iid) or " ".join(tip[:n])))
    write("items", title="Items", cols=3, gap=26, box=64, img=54, ds=16,
          h1="The pharmacy <span>and what to carry it in</span>",
          sub="Medicine you have to find, ration and keep on you. Found in pharmacies, cabinets, hospitals and bathrooms.",
          cells="\n".join(items),
          note="Every vanilla medicine works through the same system: build-up, wearing off, side effects and overdoses.")


if __name__ == "__main__":
    main()

"""Draw the Historical Weather Workshop pictures: charts of the record and of what the mod
makes of it, rendered with headless Chrome.

    python workshop/weather/make_images.py

writes, beside this script:
    preview.png   256x256   the Workshop thumbnail (also copied to HistoricalWeather/42/poster.png)
    record.png    1600x900  the two years: every day's low to high, the rain, snow and thunderstorms
    day.png       1600x900  one day hour by hour: 2 August 1993, a thunderstorm afternoon
    january.png   1600x900  the blizzard and the cold of January 1994, hour by hour

The daily values come from HistoricalWeather/data/daily.csv; the hour-by-hour ones from the
mod itself (hours.lua run through tests/run_all.js), so the pictures show what plays in game.
"""
import csv
import datetime as dt
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
MOD = os.path.join(REPO, "HistoricalWeather")
CHROME = os.environ.get("CHROME", r"C:\Program Files\Google\Chrome\Application\chrome.exe")
FIRST = dt.date(1993, 7, 9)

# colours: the game's panels (black, translucent), its yellow, a warm-to-cold scale
INK, DIM, FAINT = "#f3ead2", "#a59d88", "#4a463d"
YELLOW, RAIN, SNOW, THUNDER = "#ffd933", "#5aa0e6", "#e8f2ff", "#ffd933"

CSS = """
* { box-sizing: border-box; margin: 0; padding: 0; }
body { width: %(w)dpx; height: %(h)dpx; overflow: hidden; font-family: "Segoe UI", Arial, sans-serif;
       background: radial-gradient(ellipse at 30%% 0%%, #2b3138 0%%, #15181c 70%%); color: #f3ead2; position: relative; }
.head { position: absolute; left: 0; right: 0; top: 0; height: 44px; background: rgba(28,24,18,.92);
        border-bottom: 3px solid #ffd933; padding: 0 18px; line-height: 42px; font-size: 21px; font-weight: 600; }
.head span { color: #ffd933; }
.head small { float: right; font-size: 13px; color: #a59d88; font-weight: 400; }
.note { position: absolute; background: rgba(28,24,18,.92); border-left: 3px solid #ffd933; padding: 5px 9px;
        font-size: 12.5px; line-height: 17px; color: #f3ead2; }
.note b { color: #ffd933; font-weight: 600; }
.foot { position: absolute; left: 18px; right: 18px; bottom: 9px; font-size: 12px; color: #a59d88; }
.foot i { font-style: normal; color: #f3ead2; }
svg { position: absolute; left: 0; top: 0; }
svg text { font-family: "Segoe UI", Arial, sans-serif; }
"""


def page(w, h, body):
    return '<!doctype html><html><head><meta charset="utf-8"><style>%s</style></head><body>%s</body></html>' % (
        CSS % {"w": w, "h": h}, body)


def render(html, out, w, h, scale):
    tmp = tempfile.mkdtemp(prefix="weather-")
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


# the data -------------------------------------------------------------------------------
def daily():
    rows = []
    with open(os.path.join(MOD, "data", "daily.csv"), newline="") as f:
        for r in csv.DictReader(f):
            num = lambda k: float(r[k]) if r[k] != "" else None
            rows.append({"date": dt.date.fromisoformat(r["date"]), "high": num("high_c"), "low": num("low_c"),
                         "rain": num("rain_in"), "snow": num("snow_in")})
    return rows


def thunder_days():
    """Rows (1-based) the data file marks as thunderstorms (the last field of a row)."""
    path = os.path.join(MOD, "42", "media", "lua", "shared", "HistoricalWeather_Data.lua")
    text = open(path, encoding="utf-8").read()
    rows = re.findall(r"^\s*\{ (.*) \}, -- \d{4}-\d\d-\d\d$", text, re.M)
    return {i for i, fields in enumerate(rows, 1) if fields.split(",")[-1].strip() == "true"}


def day_name(d):
    return "%d %s" % (d.day, d.strftime("%b %Y"))


def hourly():
    """The mod's own values every ten minutes: {row: [(hour, temp, share, rain, clouds, fog, wind, snowline, storm)]}"""
    proc = subprocess.run(["node", "run_all.js", "../workshop/weather/hours.lua"], cwd=os.path.join(REPO, "tests"),
                          capture_output=True, text=True, check=True)
    result = json.loads(proc.stdout)[0]
    if not result["ok"]:
        raise SystemExit("\n".join(result["lines"][-5:]))
    out = {}
    for line in result["lines"]:
        cells = line.split(",")
        num = [float(c) if c != "" else None for c in cells[1:]]
        out.setdefault(int(cells[0]), []).append(num)
    return out


def row_of(date):
    return (date - FIRST).days + 1


# drawing helpers --------------------------------------------------------------------------
def temp_colour(c):
    """A cold-to-hot colour for a temperature in C."""
    stops = [(-30, (120, 140, 255)), (-10, (110, 190, 255)), (0, (170, 225, 240)), (10, (190, 220, 150)),
             (20, (245, 200, 90)), (30, (245, 120, 60)), (38, (220, 60, 50))]
    if c <= stops[0][0]:
        r, g, b = stops[0][1]
    elif c >= stops[-1][0]:
        r, g, b = stops[-1][1]
    else:
        for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
            if t0 <= c <= t1:
                k = (c - t0) / (t1 - t0)
                r, g, b = (round(a + (b_ - a) * k) for a, b_ in zip(c0, c1))
                break
    return "rgb(%d,%d,%d)" % (r, g, b)


def text(x, y, s, size=11, fill=DIM, anchor="start", weight=400):
    return '<text x="%.1f" y="%.1f" font-size="%g" fill="%s" text-anchor="%s" font-weight="%d">%s</text>' % (
        x, y, size, fill, anchor, weight, s)


def bolt(x, y, s=1.0, fill=THUNDER):
    pts = [(0, -7), (-4, 1), (-0.5, 1), (-2, 7), (4, -1), (0.5, -1), (2, -7)]
    return '<polygon points="%s" fill="%s"/>' % (" ".join("%.1f,%.1f" % (x + px * s, y + py * s) for px, py in pts), fill)


def flake(x, y, r=4, stroke=SNOW):
    lines = []
    for a in (0, 60, 120):
        import math
        dx, dy = r * math.cos(math.radians(a)), r * math.sin(math.radians(a))
        lines.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="1.3"/>' % (
            x - dx, y - dy, x + dx, y + dy, stroke))
    return "".join(lines)


# the two years ------------------------------------------------------------------------------
def record_page(days, storms):
    W, H = 800, 450
    x0, x1 = 52, 782
    ty0, ty1 = 64, 288          # the temperature panel
    ry0, ry1 = 312, 392         # the rain panel (bars grow down from ry0)
    tmin, tmax = -32, 40
    n = len(days)
    dx = (x1 - x0) / n
    X = lambda i: x0 + (i + 0.5) * dx
    Y = lambda c: ty1 - (c - tmin) / (tmax - tmin) * (ty1 - ty0)
    svg = []
    # the gap: the game's own temperature
    gap = [i for i, d in enumerate(days) if d["high"] is None or d["low"] is None]
    if gap:
        g0, g1 = x0 + min(gap) * dx, x0 + (max(gap) + 1) * dx
        svg.append('<defs><pattern id="hatch" width="6" height="6" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">'
                   '<line x1="0" y1="0" x2="0" y2="6" stroke="#5a5446" stroke-width="2"/></pattern></defs>')
        svg.append('<rect x="%.1f" y="%d" width="%.1f" height="%d" fill="url(#hatch)" opacity=".8"/>' % (g0, ty0, g1 - g0, ty1 - ty0))
    # grid
    for c in range(-30, 41, 10):
        y = Y(c)
        dash = "" if c else ' stroke-dasharray="4 3"'
        svg.append('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="%s" stroke-width="%s"%s/>' % (
            x0, y, x1, y, "#8fb6d8" if c == 0 else FAINT, "1" if c == 0 else "0.6", dash))
        svg.append(text(x0 - 6, y + 4, "%d&#176;C" % c, 10.5, "#8fb6d8" if c == 0 else DIM, "end"))
    # months
    d = dt.date(1993, 8, 1)
    while d <= days[-1]["date"]:
        i = (d - FIRST).days
        x = x0 + i * dx
        svg.append('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="%s" stroke-width="0.6"/>' % (x, ty0, x, ry1, FAINT))
        if d.month in (1, 4, 7, 10):
            label = d.strftime("%b") + (" %d" % d.year if d.month == 1 else "")
            svg.append(text(x + 3, ry1 + 13, label, 10.5, INK if d.month == 1 else DIM))
        m = d.month + 1
        d = dt.date(d.year + (m > 12), (m - 1) % 12 + 1, 1)
    # the days: a line from the low to the high, coloured by the middle of the day
    for i, day in enumerate(days):
        if day["high"] is None or day["low"] is None:
            continue
        lo, hi = min(day["low"], day["high"]), max(day["low"], day["high"])
        svg.append('<line x1="%.2f" y1="%.1f" x2="%.2f" y2="%.1f" stroke="%s" stroke-width="%.2f" stroke-linecap="round"/>' % (
            X(i), Y(lo), X(i), Y(hi), temp_colour((lo + hi) / 2), max(dx, 1.0)))
    # rain, snow, thunder
    svg.append('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="%s"/>' % (x0, ry0, x1, ry0, FAINT))
    for i, day in enumerate(days):
        r = day["rain"] or 0
        if r > 0.004:
            hgt = min(1.0, r / 2.0) * (ry1 - ry0 - 6)
            snowy = (day["snow"] or 0) > 0.005
            svg.append('<rect x="%.2f" y="%d" width="%.2f" height="%.1f" fill="%s"/>' % (
                x0 + i * dx, ry0, max(dx, 1.1), max(hgt, 1), SNOW if snowy else RAIN))
        if (i + 1) in storms:
            svg.append(bolt(X(i), ry0 - 7, 0.8))
    svg.append(text(x0 - 6, ry0 + 10, "rain", 10.5, RAIN, "end"))
    svg.append(text(x0 - 6, ry0 + 23, "2 in", 9.5, DIM, "end"))
    # notes
    notes = []
    def at(date): return X((date - FIRST).days)
    cold = min((d for d in days if d["low"] is not None), key=lambda d: d["low"])
    hot = max((d for d in days if d["high"] is not None), key=lambda d: d["high"])
    blizzard = max(days, key=lambda d: d["snow"] or 0)
    cx, cy = at(cold["date"]), Y(cold["low"])
    svg.append('<circle cx="%.1f" cy="%.1f" r="4" fill="none" stroke="%s" stroke-width="1.5"/>' % (cx, cy, YELLOW))
    notes.append('<div class="note" style="left:%dpx; top:%dpx; width:280px"><b>%.0f&#176;C (%.0f&#176;F)</b>, %s: the '
                 'coldest morning of the two years</div>' % (cx + 10, cy - 34, cold["low"], cold["low"] * 9 / 5 + 32,
                                                            day_name(cold["date"])))
    bx = at(blizzard["date"])
    svg.append(flake(bx, ry0 + 50, 5, YELLOW))
    notes.append('<div class="note" style="left:%dpx; top:%dpx; width:170px"><b>%.1f in of snow</b>, %s, '
                 'then the big freeze</div>' % (bx + 10, ry0 + 34, blizzard["snow"], day_name(blizzard["date"])))
    hx, hy = at(hot["date"]), Y(hot["high"])
    svg.append('<circle cx="%.1f" cy="%.1f" r="4" fill="none" stroke="%s" stroke-width="1.5"/>' % (hx, hy, YELLOW))
    notes.append('<div class="note" style="left:%dpx; top:%dpx; width:150px"><b>%.1f&#176;C (%.0f&#176;F)</b>, %s</div>' % (
        hx + 9, hy - 12, hot["high"], hot["high"] * 9 / 5 + 32, day_name(hot["date"])))
    if gap:
        # a label up the hatching's empty lower half; the footer says what it means
        gx, gy = (g0 + g1) / 2 + 4, Y(-29)
        svg.append('<text x="%.1f" y="%.1f" font-size="11.5" fill="%s" font-weight="600" letter-spacing="1" '
                   'transform="rotate(-90 %.1f %.1f)">NO READINGS</text>' % (gx, gy, YELLOW, gx, gy))
    body = ('<svg width="%d" height="%d">%s</svg>' % (W, H, "".join(svg)) + "".join(notes) +
            '<div class="head"><span>Two real years</span> in Knox County <small>NOAA daily record, Barbourville, KY &#183; 9 Jul 1993 to 9 Jul 1995</small></div>'
            '<div class="foot">Each line is a day, low to high &#183; rain <i style="color:%s">&#9632;</i> and snow '
            '<i style="color:%s">&#9632;</i> &#183; <i style="color:%s">&#9889;</i> summer thunderstorms (%d) &#183; '
            'hatched: no readings, the game\'s own temperature</div>'
            % (RAIN, SNOW, THUNDER, len(storms)))
    return page(W, H, body)


# one day, hour by hour --------------------------------------------------------------------------
def hours_chart(rows, x0, x1, y0, y1, tmin, tmax, ticks, label_every):
    """A temperature line over ten-minute rows (several days side by side), with rain or snow
    bars along the bottom, clouds as a band along the top and thunder marked. Returns svg."""
    n = len(rows)
    dx = (x1 - x0) / n
    X = lambda k: x0 + k * dx
    Y = lambda c: y1 - (c - tmin) / (tmax - tmin) * (y1 - y0)
    svg = []
    for c in ticks:
        y = Y(c)
        z = c == 0
        svg.append('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="%s" stroke-width="%s"%s/>' % (
            x0, y, x1, y, "#8fb6d8" if z else FAINT, 1 if z else 0.6, ' stroke-dasharray="4 3"' if z else ""))
        svg.append(text(x0 - 6, y + 4, "%d&#176;C" % c, 10.5, "#8fb6d8" if z else DIM, "end"))
    # clouds: a grey band along the top, as thick as the sky is grey
    for k, r in enumerate(rows):
        c = r[4]
        if c:
            svg.append('<rect x="%.2f" y="%d" width="%.2f" height="%.1f" fill="#9aa3ad" opacity="%.2f"/>' % (
                X(k), y0 - 18, dx + 0.3, 14, 0.15 + 0.75 * c))
    svg.append(text(x0 - 6, y0 - 7, "clouds", 10, DIM, "end"))
    # rain / snow bars from the bottom
    for k, r in enumerate(rows):
        p = r[3]
        if p and p > 0:
            t = r[1]
            snowy = t is not None and t <= r[7]
            hgt = p * 70
            svg.append('<rect x="%.2f" y="%.1f" width="%.2f" height="%.1f" fill="%s" opacity=".85"/>' % (
                X(k), y1 - hgt, dx + 0.3, hgt, SNOW if snowy else RAIN))
        if r[8]:
            svg.append('<rect x="%.2f" y="%d" width="%.2f" height="%d" fill="%s" opacity=".12"/>' % (X(k), y0, dx + 0.3, y1 - y0, THUNDER))
    # the temperature
    pts = ["%.1f,%.1f" % (X(k) + dx / 2, Y(r[1])) for k, r in enumerate(rows) if r[1] is not None]
    svg.append('<polyline points="%s" fill="none" stroke="#f5a04a" stroke-width="2.2" stroke-linejoin="round"/>' % " ".join(pts))
    return svg, X, Y


def day_page(hours):
    W, H = 800, 450
    date = dt.date(1993, 8, 2)
    i = row_of(date)
    rows = hours[i]
    x0, x1, y0, y1 = 56, 770, 92, 360
    svg, X, Y = hours_chart(rows, x0, x1, y0, y1, 5, 35, range(5, 36, 5), 3)
    for hr in range(0, 25, 3):
        x = x0 + hr * 6 * (x1 - x0) / len(rows)
        svg.append('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="%s" stroke-width="0.6"/>' % (x, y0, x, y1, FAINT))
        svg.append(text(x, y1 + 14, "%02d:00" % (hr % 24), 10.5, DIM, "middle"))
    low = rows[36][1]
    high = rows[90][1]
    svg.append('<circle cx="%.1f" cy="%.1f" r="4" fill="#f5a04a"/>' % (X(36) + (x1 - x0) / len(rows) / 2, Y(low)))
    svg.append('<circle cx="%.1f" cy="%.1f" r="4" fill="#f5a04a"/>' % (X(90) + (x1 - x0) / len(rows) / 2, Y(high)))
    storm = [k for k, r in enumerate(rows) if r[8]]
    s0 = storm[0]
    svg.append(bolt(X(s0) + 30, y0 + 22, 1.6))
    svg.append(bolt(X(s0) + 70, y0 + 40, 1.2))
    t = lambda k: "%02d:%02d" % (k // 6, (k % 6) * 10)
    notes = [
        '<div class="note" style="left:%dpx; top:%dpx; width:170px"><b>06:00 low, %.1f&#176;C</b><br>the record\'s minimum</div>' % (
            X(36) - 40, Y(low) + 14, low),
        '<div class="note" style="left:%dpx; top:%dpx; width:170px"><b>15:00 high, %.1f&#176;C</b><br>the record\'s maximum</div>' % (
            X(90) - 200, Y(high) - 22, high),
        '<div class="note" style="left:%dpx; top:%dpx; width:200px"><b>1.72 in of rain</b> that day: a thunderstorm from %s, '
        'thunder and lightning for as long as it rains</div>' % (X(s0) - 40, y0 + 64, t(s0)),
        '<div class="note" style="left:%dpx; top:%dpx; width:190px"><b>Clouds</b> (the band above) gather three hours '
        'before the rain and clear two after</div>' % (x0 + 10, y0 + 8),
    ]
    body = ('<svg width="%d" height="%d">%s</svg>' % (W, H, "".join(svg)) + "".join(notes) +
            '<div class="head"><span>One day, hour by hour</span>: 2 August 1993 <small>what the mod plays from one line of the record</small></div>'
            '<div class="foot">Temperature <i style="color:#f5a04a">&#9644;</i> from the day\'s low and high &#183; rain '
            '<i style="color:%s">&#9632;</i> as hard as the day\'s total says &#183; the yellow wash is the thunderstorm</div>' % RAIN)
    return page(W, H, body)


def january_page(hours, days):
    W, H = 800, 450
    first, last = dt.date(1994, 1, 15), dt.date(1994, 1, 23)
    rows = []
    for k in range(row_of(first), row_of(last) + 1):
        rows += hours[k]
    x0, x1, y0, y1 = 56, 770, 92, 360
    svg, X, Y = hours_chart(rows, x0, x1, y0, y1, -32, 8, range(-30, 9, 10), 1)
    per_day = 144
    for k in range(0, len(rows) + 1, per_day):
        x = X(k)
        svg.append('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="%s" stroke-width="0.6"/>' % (x, y0, x, y1, FAINT))
        if k < len(rows):
            date = first + dt.timedelta(days=k // per_day)
            svg.append(text(x + (x1 - x0) / 9 / 2, y1 + 14, "%s %d" % (date.strftime("%a"), date.day), 10.5, INK, "middle"))
    coldest = min(range(len(rows)), key=lambda k: rows[k][1] if rows[k][1] is not None else 99)
    snow_day = next(d for d in days if d["date"] == dt.date(1994, 1, 17))
    sx = X(2 * per_day + 6 * 17)
    notes = [
        '<div class="note" style="left:%dpx; top:%dpx; width:190px"><b>%.1f in of snow</b> on the 17th, from late afternoon through the night</div>' % (
            sx - 90, y0 + 6, snow_day["snow"]),
        # under the day labels, with a line up to the point
        '<div class="note" style="left:%dpx; top:%dpx; width:430px"><b>%.0f&#176;C at dawn</b> two mornings running, '
        'the coldest of the two years</div>' % (X(coldest) - 40, y1 + 24, rows[coldest][1]),
    ]
    svg.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%d" stroke="%s" stroke-width="1.2"/>' % (
        X(coldest), Y(rows[coldest][1]) + 4, X(coldest), y1 + 24, YELLOW))
    svg.append('<circle cx="%.1f" cy="%.1f" r="4" fill="none" stroke="%s" stroke-width="1.5"/>' % (
        X(coldest), Y(rows[coldest][1]), YELLOW))
    # the first afternoon above freezing after the cold
    thaw = next(d for d in days if dt.date(1994, 1, 19) < d["date"] <= last and (d["high"] or -99) > 0)
    tk = (thaw["date"] - first).days * per_day + 90
    notes.append('<div class="note" style="left:%dpx; top:%dpx; width:140px"><b>Above freezing</b> again on the %s</div>' % (
        X(tk) - 150, Y(thaw["high"]) - 46, "%d%s" % (thaw["date"].day, "nd" if thaw["date"].day == 22 else "th")))
    body = ('<svg width="%d" height="%d">%s</svg>' % (W, H, "".join(svg)) + "".join(notes) +
            '<div class="head"><span>January 1994</span>: the blizzard and the big freeze <small>15 to 23 Jan, hour by hour</small></div>'
            '<div class="foot">Temperature <i style="color:#f5a04a">&#9644;</i> &#183; snow <i style="color:%s">&#9632;</i> and rain '
            '<i style="color:%s">&#9632;</i> &#183; the dashed line is freezing</div>'
            % (SNOW, RAIN))
    return page(W, H, body)


# the thumbnail -----------------------------------------------------------------------------------
def preview_page(days, storms):
    S = 256
    x0, x1, y0, y1 = 14, 242, 112, 214
    tmin, tmax = -32, 40
    dx = (x1 - x0) / len(days)
    svg = []
    y = y1 - (0 - tmin) / (tmax - tmin) * (y1 - y0)
    svg.append('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#8fb6d8" stroke-width="1" stroke-dasharray="3 2"/>' % (x0, y, x1, y))
    for i, d in enumerate(days):
        if d["high"] is None or d["low"] is None:
            continue
        lo, hi = min(d["low"], d["high"]), max(d["low"], d["high"])
        Y = lambda c: y1 - (c - tmin) / (tmax - tmin) * (y1 - y0)
        svg.append('<line x1="%.2f" y1="%.1f" x2="%.2f" y2="%.1f" stroke="%s" stroke-width="1"/>' % (
            x0 + i * dx, Y(lo), x0 + i * dx, Y(hi), temp_colour((lo + hi) / 2)))
    svg.append(bolt(214, 128, 1.5))
    svg.append(flake(108, 222, 6, SNOW))
    body = ('<svg width="%d" height="%d">%s</svg>' % (S, S, "".join(svg)) +
            '<div style="position:absolute; left:0; right:0; top:0; height:84px; background:rgba(28,24,18,.92);'
            ' border-bottom:3px solid #ffd933; text-align:center">'
            '<div style="color:#ffd933; font-weight:700; font-size:25px; letter-spacing:1.5px; padding-top:9px; line-height:30px">HISTORICAL<br>WEATHER</div></div>'
            '<div style="position:absolute; left:0; right:0; top:88px; text-align:center; font-size:12.5px; color:#f3ead2">'
            'Knox County &#183; 1993 to 1995</div>'
            '<div style="position:absolute; left:0; right:0; bottom:9px; text-align:center; font-size:11px; color:#a59d88">'
            'the real record, day by day</div>')
    return page(S, S, body)


def main():
    days = daily()
    storms = thunder_days()
    hours = hourly()
    render(record_page(days, storms), os.path.join(HERE, "record.png"), 800, 450, 2)
    render(day_page(hours), os.path.join(HERE, "day.png"), 800, 450, 2)
    render(january_page(hours, days), os.path.join(HERE, "january.png"), 800, 450, 2)
    big = os.path.join(HERE, "preview-512.png")
    render(preview_page(days, storms), big, 256, 256, 2)
    img = Image.open(big).convert("RGB").resize((256, 256), Image.LANCZOS)
    os.remove(big)
    img.save(os.path.join(HERE, "preview.png"))
    img.save(os.path.join(MOD, "42", "poster.png"))
    print("wrote workshop/weather/preview.png and HistoricalWeather/42/poster.png (256, 256)")


if __name__ == "__main__":
    sys.exit(main())

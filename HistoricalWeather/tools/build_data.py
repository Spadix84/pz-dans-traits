"""Turn NOAA's daily record for Barbourville, KY (Knox County) into the mod's Lua data.

    python -I HistoricalWeather/tools/build_data.py            PDF -> data/daily.csv -> Lua
    python -I HistoricalWeather/tools/build_data.py --csv      data/daily.csv -> Lua (after hand edits)

The source is the NCEI "Record of Climatological Observations" PDF in data/ (station
USC00150381, 9 Jul 1993 to 9 Jul 1995). It needs pypdf (pip install pypdf).

The station is a co-op observer who read the instruments at 07:00. So the line for a date
holds the 24 hours up to 07:00 that morning:
    Max    the warmest of those 24 hours, nearly always the afternoon before: the PREVIOUS day's high
    Min    the coldest, nearly always just before dawn that morning: the SAME day's low
    At Obs the reading at 07:00 that morning
    Rain   fell between 07:00 the day before and 07:00 that morning
This script moves each value onto the day it belongs to, so in daily.csv `high` and `rain`
for a date are that date's afternoon and that date's 07:00-to-07:00-next-morning total.

Gaps: a missing high or low is filled in from the days around it when the gap is short
(three days or less); a longer gap stays empty and the mod leaves the temperature to the
game on those days. A day with no rain figure at all is left to the game's own sky.

The rain itself is only a daily total, so the hours it fell in are made up here, once, with a
fixed seed: a summer day's rain is a short afternoon shower (heavier), a winter day's a long
spell at any hour. The result is written into the data, so every game sees the same weather.

Thunder: the record does not say which rain was a thunderstorm, but in a Kentucky summer a
heavy day's rain nearly always is, so a May-September day with half an inch or more is marked
as one (35 days in the two years).
"""
import csv
import datetime as dt
import math
import os
import random
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.dirname(HERE)
PDF = os.path.join(MOD, "data", "knoxCountyHistoricalWeatherData.pdf")
CSV = os.path.join(MOD, "data", "daily.csv")
LUA = os.path.join(MOD, "42", "media", "lua", "shared", "HistoricalWeather_Data.lua")

FIRST = dt.date(1993, 7, 9)
LAST = dt.date(1995, 7, 9)
COLS = ["max", "min", "obs", "rain", "snow", "depth"]
TRACE = 0.005          # inches; "T" in the record
MAX_FILL = 3           # longest temperature gap (days) filled in from its neighbours
SUMMER = (5, 6, 7, 8, 9)
THUNDER = 0.5          # inches in a summer day's rain that make it a thunderstorm
SEED = 19930709


# -- reading the PDF -----------------------------------------------------------------
def value(tok):
    """A cell as a number: 's' (failed QC) and 'A' (multi-day total) flags dropped, T = trace."""
    tok = tok.rstrip("sSA")
    if tok == "T":
        return TRACE
    try:
        return float(tok)
    except ValueError:
        return None


def read_pdf(path):
    """{date: {col: value}} from the record's daily lines.

    The text comes out in layout mode, which keeps each cell under its heading, and the
    columns are right-aligned. Blank cells are common (October 1993 has no temperatures at
    all), so a cell is put in the column whose right edge is nearest its own, the edges
    taken from the page's complete lines."""
    import pypdf
    out = {}
    pages = []
    for page in pypdf.PdfReader(path).pages:
        lines = []
        for line in page.extract_text(extraction_mode="layout").splitlines():
            m = re.match(r"^\s*(199\d)\s+(\d\d)\s+(\d\d)(.*)$", line)
            if m:
                cells = [(t.group(0), m.start(4) + t.end()) for t in re.finditer(r"\S+", m.group(4))]
                lines.append((dt.date(int(m.group(1)), int(m.group(2)), int(m.group(3))), cells))
        pages.append(lines)

    def edges_of(lines):
        full = [cells for _, cells in lines if len(cells) == len(COLS)]
        return full and [sum(c[i][1] for c in full) / len(full) for i in range(len(COLS))]
    # a page without one complete line (a month with no temperatures, or no snow column)
    # uses the edges of every complete line in the record
    everywhere = edges_of([l for lines in pages for l in lines])
    for lines in pages:
        edges = edges_of(lines) or everywhere
        for day, cells in lines:
            row = {}
            for tok, end in cells:
                col = min(range(len(COLS)), key=lambda i: abs(edges[i] - end))
                if abs(edges[col] - end) > 4 or COLS[col] in row:
                    raise SystemExit("%s: cannot place %r (end %d, edges %s)" % (day, tok, end, edges))
                row[COLS[col]] = value(tok)
            out[day] = row
    return out


def f_to_c(f):
    return None if f is None else round((f - 32) * 5 / 9, 1)


def shift(raw):
    """Each value onto the day it belongs to (see the module notes)."""
    days = []
    d = FIRST
    while d <= LAST:
        today, tomorrow = raw.get(d, {}), raw.get(d + dt.timedelta(days=1), {})
        days.append({
            "date": d,
            "high": f_to_c(tomorrow.get("max")),
            "low": f_to_c(today.get("min")),
            "rain": tomorrow.get("rain"),            # inches, 07:00 today to 07:00 tomorrow
            "snow": tomorrow.get("snow"),            # inches of snowfall in the same 24 hours
            "depth": today.get("depth"),             # inches on the ground at 07:00 today
        })
        d += dt.timedelta(days=1)
    return days


def fill(days, key):
    """Short gaps in a temperature column filled in on a straight line; long ones left empty."""
    i = 0
    while i < len(days):
        if days[i][key] is not None:
            i += 1
            continue
        j = i
        while j < len(days) and days[j][key] is None:
            j += 1
        gap = j - i
        before = days[i - 1][key] if i > 0 else None
        after = days[j][key] if j < len(days) else None
        if gap <= MAX_FILL and (before is not None or after is not None):
            a = before if before is not None else after
            b = after if after is not None else before
            for k in range(gap):
                days[i + k][key] = round(a + (b - a) * (k + 1) / (gap + 1), 1)
                days[i + k][key + "_filled"] = True
        i = j


def write_csv(days):
    with open(CSV, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["date", "high_c", "low_c", "rain_in", "snow_in", "depth_in"])
        for d in days:
            w.writerow([d["date"].isoformat()] + ["" if d[k] is None else d[k] for k in ("high", "low", "rain", "snow", "depth")])


def read_csv():
    days = []
    with open(CSV, newline="") as f:
        for r in csv.DictReader(f):
            num = lambda k: float(r[k]) if r[k] != "" else None
            days.append({"date": dt.date.fromisoformat(r["date"]), "high": num("high_c"), "low": num("low_c"),
                         "rain": num("rain_in"), "snow": num("snow_in"), "depth": num("depth_in")})
    return days


# -- when the rain fell ----------------------------------------------------------------
def spell(day, rng):
    """(start, hours, intensity) for a day's rain, start in hours after 07:00 that day.

    Intensity is the game's precipitation 0..1: about 0.2 a drizzle, 0.5 steady rain, 0.9 a
    downpour. A rate in inches an hour maps onto it as 0.15 + 2.5 x rate."""
    inches = day["rain"]
    if not inches or inches <= 0:
        return None
    month = day["date"].month
    summer = month in SUMMER
    if inches <= TRACE:
        hours = 1
    elif summer:
        hours = min(6, max(1, round(1 + inches * 2.5 + rng.uniform(-0.5, 1))))
    else:
        hours = min(18, max(2, round(2 + inches * 8 + rng.uniform(-1, 3))))
    if summer and inches > TRACE:
        start = rng.uniform(13, 18) - 7          # an afternoon storm
    else:
        start = rng.uniform(0, 24 - min(hours, 23))
    rate = inches / hours
    intensity = max(0.1, min(1.0, 0.15 + 2.5 * rate))
    return round(start, 1), hours, round(intensity, 2)


def lua(days):
    rng = random.Random(SEED)
    out = ["-- Generated by HistoricalWeather/tools/build_data.py from data/daily.csv; do not edit by hand.",
           "-- One row a day from " + FIRST.isoformat() + " (row 1) to " + LAST.isoformat() + ".",
           "-- { high C, low C, rain start (hours after 07:00), rain hours, rain intensity 0..1, snow, thunder }",
           "-- high/low nil: the game's own temperature that day; rain start false: the game's own sky.",
           "-- snow true: the record has measurable snowfall in the 24 hours from 07:00.",
           "-- thunder true: a summer day (May-September) with %s in or more of rain: a thunderstorm." % THUNDER,
           "HistoricalWeather_Data = {"]
    stats = {"rain": 0, "sky": 0, "temp": 0, "thunder": 0}
    for d in days:
        s = spell(d, rng)
        if d["rain"] is None:
            rain = "false, 0, 0"
            stats["sky"] += 1
        elif s is None:
            rain = "nil, 0, 0"
        else:
            rain = "%s, %d, %s" % (s[0], s[1], s[2])
            stats["rain"] += 1
        if d["high"] is None or d["low"] is None:
            stats["temp"] += 1
        # a trace of snow on a wet day is not a snow day; real snowfall lets it snow a little above freezing
        snow = "true" if (d["snow"] or 0) > TRACE else "false"
        # the record does not say which rain was a thunderstorm; a heavy summer day's nearly always is
        thunder = s is not None and d["date"].month in SUMMER and d["rain"] >= THUNDER
        stats["thunder"] += thunder
        out.append("    { %s, %s, %s, %s, %s }, -- %s" % (
            "nil" if d["high"] is None else d["high"], "nil" if d["low"] is None else d["low"], rain, snow,
            "true" if thunder else "false", d["date"].isoformat()))
    out.append("}")
    with open(LUA, "w", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    return stats


def main():
    if "--csv" in sys.argv:
        days = read_csv()
    else:
        days = shift(read_pdf(PDF))
        fill(days, "high")
        fill(days, "low")
        write_csv(days)
    stats = lua(days)
    print("%d days; rain on %d (thunder on %d); no rain figure (game's sky) %d; no temperature (game's) %d"
          % (len(days), stats["rain"], stats["thunder"], stats["sky"], stats["temp"]))


if __name__ == "__main__":
    main()

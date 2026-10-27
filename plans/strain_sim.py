"""Strain day simulator (plans/strain.md). Players see it as Burnout (2026-10-27).

Runs play patterns day by day so the strain numbers can be tuned before any
Lua is written. Every number lives in P; change one and run again:

    python plans/strain_sim.py

Strain runs 0..100. A day is the outing (kills, panic, hits, shocks) and then
the rest of the day (calm hours, comforts, a drink, the night's sleep).
Not modelled: the alcoholism and nicotine meters filling (a daily drinker
becomes an Alcoholic in a few weeks), sleep quality, MDD episodes.
"""

P = {
    # outing
    "kill": 0.1,            # per melee kill
    "kill_ramp": 100,       # kill k of the day costs kill x (1 + k / kill_ramp); resets on sleep
    "vehicle_kill": 1 / 3,  # a vehicle kill counts as this share of a kill (cost and count)
    "far_share": 0.4,       # a kill 12+ tiles away counts this share (full within 3; linear between)
    "panic_min": 0.1,       # per minute with panic over 40
    "hit": {"scratch": 1, "laceration": 2, "deep": 3, "grab": 1.5},
    "bite": 50,             # each bite
    "low_health": 50,       # health under 25, once a day
    # illness, per hour awake or asleep
    "fever": 0.25,          # at full fever (wound infection spreading)
    "sepsis": 0.5,
    "food_sick": 0.15,      # Sick moodle at its worst from food
    "pain": 0.15,           # at full pain
    "sick_rest_cut": 0.5,   # calm hours and sleep ease this share while feverish
    # rest of the day
    "calm_hour": 0.375,     # an hour awake with no fight in the last two, anywhere
    "sleep": {"bed": 4, "rough": 2},   # x the night's quality in game (Vitality)
    "comfort": {"shower": 2, "laundry": 2, "meal1": 2, "meal2": 3, "meal3": 4, "read": 2, "pumped": 2, "game": 2, "breathe": 2, "walk": 2, "pet": 2},
    "home": 1.5,            # comforts at home count this much
    "variety_n": 4,         # this many different comforts in a day...
    "variety": 1.25,        # ...multiply the day's comforts by this
    # drink and smoke
    "drunk_hour": 2.0,      # an hour at Drunk 2+
    "tipsy_hour": 0.75,     # an hour tipsy (Drunk 1)
    "drink_cap": 8,         # most a day of drinking can take off
    "hangover": 2,          # the morning after a night past Drunk 2
    "cig": 0.75,
    "cig_cap": 3,
    "addict_relief": 0.25,  # Alcoholic's drink, Smoker's cigarette, relief x this
    "alc_withdraw": {"craving": 0.15, "shakes": 0.3, "delirium": 0.5},   # per hour awake
    "nic_withdraw": 0.1,    # per hour awake at full withdrawal
    # global
    "early_days": 7,        # strain gained x early_mult for the first week
    "early_mult": 0.5,
    "break_reset": 60,      # Breaking Point: shutdown, then strain drops to this
    # hardened (2026-10-27): combat strain x (1 - kill_cut x min(1, kills / kills_full))
    #                                       x (1 - day_cut x min(1, days / days_full))
    "harden_kills": 2000, "harden_kill_cut": 0.4,
    "harden_days": 90, "harden_day_cut": 0.2,
}


def hardening(lifetime_kills, days_survived):
    by_kills = 1 - P["harden_kill_cut"] * min(1, lifetime_kills / P["harden_kills"])
    by_days = 1 - P["harden_day_cut"] * min(1, days_survived / P["harden_days"])
    return by_kills * by_days

TRAITS = {
    "levelheaded": {"gain": 0.5},
    "highlystrung": {"gain": 1.5},
    "unwinds": {"ease": 1.5},
    "cantswitchoff": {"ease": 0.67},
    "homebody": {"home": 2.0},
    "desensitized": {"combat": 0.6},
}


def xp_mult(s):
    """Combat XP multiplier at strain s; other skills take half the penalty, only above 50."""
    if s < 10:
        return 1.1
    if s < 25:
        return 1.0
    pts = [(25, 1.0), (50, 0.75), (75, 0.4), (100, 0.15)]
    for (a, ma), (b, mb) in zip(pts, pts[1:]):
        if s <= b:
            return ma + (mb - ma) * (s - a) / (b - a)
    return 0.15


def tier(s):
    if s >= 100:
        return "Breaking"
    if s >= 75:
        return "Burnt Out"
    if s >= 50:
        return "Worn Down"
    if s >= 25:
        return "Frayed"
    if s < 10:
        return "At Ease"
    return "-"


def outing_cost(day, traits, harden=1.0):
    t = {k: 1.0 for k in ("gain", "combat")}
    for name in traits:
        for k, v in TRAITS[name].items():
            if k in t:
                t[k] *= v
    # "far": the share of the day's kills made from 12+ tiles (a shooter)
    far = day.get("far", 0)
    kills = day.get("kills", 0) * (1 - far + far * P["far_share"]) + day.get("vkills", 0) * P["vehicle_kill"]
    k_cost = 0.0
    n = int(round(kills))
    for k in range(1, n + 1):
        k_cost += P["kill"] * (1 + k / P["kill_ramp"])
    combat = k_cost + day.get("panic", 0) * P["panic_min"]
    combat += sum(P["hit"][h] for h in day.get("hits", []))
    combat *= t["combat"] * harden
    shock = day.get("bites", 0) * P["bite"] + (P["low_health"] if day.get("low_health") else 0)
    ill = 24 * (day.get("fever", 0) * P["fever"] + day.get("sepsis", 0) * P["sepsis"]
                + day.get("food_sick", 0) * P["food_sick"] + day.get("pain", 0) * P["pain"])
    return (combat + shock + ill) * t["gain"]


def rest_ease(day, traits, alcoholic=False, smoker=False):
    ease, home = 1.0, P["home"]
    for name in traits:
        ease *= TRAITS[name].get("ease", 1.0)
        home = TRAITS[name].get("home", home)
    sick = day.get("fever", 0) > 0 or day.get("sepsis", 0) > 0
    rest_k = (1 - P["sick_rest_cut"]) if sick else 1.0
    calm = day.get("calm", 0) * P["calm_hour"] * rest_k
    sleep = P["sleep"][day.get("sleep", "bed")] * rest_k
    comforts = day.get("comforts", [])
    c = sum(P["comfort"][x] for x in comforts)
    if day.get("at_home", True):
        c *= home
    if len(set(comforts)) >= P["variety_n"]:
        c *= P["variety"]
    drink = min(P["drink_cap"], day.get("drunk", 0) * P["drunk_hour"] + day.get("tipsy", 0) * P["tipsy_hour"])
    cigs = min(P["cig_cap"], day.get("cigs", 0) * P["cig"])
    if alcoholic:
        drink *= P["addict_relief"]
    if smoker:
        cigs *= P["addict_relief"]
    return (calm + sleep + c) * ease + drink + cigs


def withdrawal_gain(day, alcoholic, smoker):
    g = 0.0
    if alcoholic and day.get("alc_stage"):
        g += 16 * P["alc_withdraw"][day["alc_stage"]]
    if smoker:
        g += 16 * P["nic_withdraw"] * day.get("nic_withdraw", 0)
    return g


def run(pattern, days=21, start_day=8, traits=(), alcoholic=False, smoker=False, s=0.0, lifetime=0, harden=True):
    rows, breaks = [], 0
    prev_drunk = False
    for i in range(days):
        day = pattern[i % len(pattern)]
        game_day = start_day + i
        h = hardening(lifetime, game_day) if harden else 1.0
        gain = outing_cost(day, traits, h) + withdrawal_gain(day, alcoholic, smoker)
        lifetime += day.get("kills", 0)
        if prev_drunk:
            gain += P["hangover"]
        if game_day <= P["early_days"]:
            gain *= P["early_mult"]
        s = min(100.0, s + gain)
        peak = s
        xp = xp_mult(s)   # XP is earned out on the outing, at the day's peak
        if s >= 100:
            breaks += 1
            s = P["break_reset"]
        s = max(0.0, s - rest_ease(day, traits, alcoholic, smoker))
        prev_drunk = day.get("drunk", 0) > 0
        rows.append((game_day, day["name"], peak, s, xp, day.get("kills", 0)))
    return rows, breaks


# Standard days ---------------------------------------------------------------
SUPPLY = {"name": "supply run", "kills": 25, "panic": 10, "hits": ["scratch"], "calm": 10}
BUSY = {"name": "busy day", "kills": 75, "panic": 30, "hits": ["scratch", "scratch", "laceration"], "calm": 6}
HORDE = {"name": "horde day", "kills": 150, "panic": 60,
         "hits": ["scratch", "scratch", "scratch", "laceration", "laceration", "grab"], "calm": 3}
ROUTINE = ["shower", "meal2", "read"]
BUSY_R = dict(BUSY, name="busy + evening routine", comforts=ROUTINE)
HORDE_R = dict(HORDE, name="horde + shower, meal", comforts=["shower", "meal2"])
HORDE_GUN = dict(HORDE, name="horde, half the kills shot from range", far=0.5)
DAY_OFF = {"name": "full day off at home", "calm": 16,
           "comforts": ["shower", "laundry", "meal2", "read", "pumped"]}
LAZY = {"name": "lazy day at home", "calm": 16}
FIELD = {"name": "field, no fighting", "calm": 16, "at_home": False}
FIELD_ROUGH = dict(FIELD, name="field, sleeping rough", sleep="rough")
BITTEN_HORDE = dict(HORDE, name="horde day, bitten", bites=1)
FEVER_DAY = {"name": "home with a fever", "calm": 16, "fever": 1.0, "pain": 0.3}
DRINKING = dict(LAZY, name="lazy day + a night drinking", drunk=3)
BUSY_DRINK = dict(BUSY, name="busy + a night drinking", drunk=3)

PATTERNS = [
    ("Horde every day, no routine", [HORDE], ()),
    ("Horde every day, shower + meal", [HORDE_R], ()),
    ("Busy every day + evening routine", [BUSY_R], ()),
    ("Busy every day, nothing after", [BUSY], ()),
    ("Horde, then 1 day off", [HORDE, DAY_OFF], ()),
    ("Horde, then 2 days off", [HORDE, DAY_OFF, DAY_OFF], ()),
    ("Rough week: 4 horde days, then home", [HORDE, HORDE, HORDE, HORDE, DAY_OFF, DAY_OFF, DAY_OFF], ()),
    ("Supply run every other day", [SUPPLY, DAY_OFF], ()),
    ("Busy every day + drinking every night", [BUSY_DRINK], ()),
    ("Horde every day, Level Headed", [HORDE], ("levelheaded",)),
    ("Horde every day, Desensitized", [HORDE], ("desensitized",)),
    ("Rough week, Level Headed", [HORDE, HORDE, HORDE, HORDE, DAY_OFF, DAY_OFF, DAY_OFF], ("levelheaded",)),
    ("Rough week, High Strung", [HORDE, HORDE, HORDE, HORDE, DAY_OFF, DAY_OFF, DAY_OFF], ("highlystrung",)),
    ("Horde every day, half shot from range", [HORDE_GUN], ()),
]


def standard_days():
    print("## Standard days (from 0 strain, day 8+)\n")
    print("| Day | Gained | Eased | Net |")
    print("|---|---|---|---|")
    for d in [SUPPLY, BUSY, HORDE, BITTEN_HORDE, BUSY_R, DAY_OFF, LAZY, FIELD, FIELD_ROUGH, FEVER_DAY, DRINKING]:
        g, e = outing_cost(d, ()), rest_ease(d, ())
        print(f"| {d['name']} | +{g:.1f} | -{e:.1f} | {g - e:+.1f} |")
    print()


def patterns():
    print("## Patterns over three weeks (days 8-28, from 0)\n")
    print("| Pattern | Day 3 | Day 7 | Day 14 | Day 21 | Peak | Breaks | Kills | Combat XP per kill | Kill-XP earned |")
    print("|---|---|---|---|---|---|---|---|---|---|")
    for name, pat, traits in PATTERNS:
        rows, breaks = run(pat, traits=traits)
        at = lambda n: f"{rows[n - 1][3]:.0f}"
        peak = max(r[2] for r in rows)
        kills = sum(r[5] for r in rows)
        avg = sum(r[4] * r[5] for r in rows) / kills   # per kill: rest days earn no combat XP
        print(f"| {name} | {at(3)} | {at(7)} | {at(14)} | {at(21)} | {peak:.0f} | {breaks} | {kills} | x{avg:.2f} | {kills * avg:.0f} |")
    print()


def first_week():
    print("## The first week (half strain), horde every day with shower + meal\n")
    print("| Game day | Peak | End of day | Tier | Combat XP |")
    print("|---|---|---|---|---|")
    rows, _ = run([HORDE_R], days=10, start_day=1)
    for d, _, peak, end, xp, _k in rows:
        print(f"| {d} | {peak:.0f} | {end:.0f} | {tier(peak)} | x{xp:.2f} |")
    print()


def alcoholic_week():
    print("## Alcoholic: drinking vs going dry (busy days with the evening routine)\n")
    wet = dict(BUSY_R, name="busy + routine + drinking", drunk=3)
    dry = [dict(BUSY_R, alc_stage=s) for s in ("craving", "craving", "shakes", "shakes", "delirium", "delirium", "delirium")]
    for label, pat in (("Drinks every night", [wet]), ("Goes dry", dry)):
        rows, breaks = run(pat, days=7, alcoholic=True)
        print(f"- {label}: " + ", ".join(f"{r[3]:.0f}" for r in rows) + f" (breaks: {breaks})")
    print()


def long_run():
    print("## Hardened: three months from day 8 (lifetime kills from 0)" + chr(10))
    print("| Pattern | Day 30 | Day 60 | Day 98 | Peak after day 60 | Breaks | Kills | Hardening at the end |")
    print("|---|---|---|---|---|---|---|---|")
    for name, pat in (("Busy every day, nothing after", [BUSY]),
                      ("Horde every day, shower + meal", [HORDE_R]),
                      ("Rough week: 4 horde days, then home", [HORDE, HORDE, HORDE, HORDE, DAY_OFF, DAY_OFF, DAY_OFF])):
        rows, breaks = run(pat, days=91)
        end = lambda d: f"{next(r[3] for r in rows if r[0] == d):.0f}"
        kills = sum(r[5] for r in rows)
        late = max(r[2] for r in rows if r[0] > 60)
        print(f"| {name} | {end(30)} | {end(60)} | {end(98)} | {late:.0f} | {breaks} | {kills} | x{hardening(kills, 98):.2f} |")
    print()


if __name__ == "__main__":
    standard_days()
    patterns()
    long_run()
    first_week()
    alcoholic_week()

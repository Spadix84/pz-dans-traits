# Dan's Traits

A Project Zomboid (Build 42) mod: realistic, balanced traits that add complications to work around, plus a Vitality system that makes fresh food, exercise and sleep matter for everyone.

## Traits

| Trait | Cost | What it does |
|---|---|---|
| Dependent | -6 | Withdrawal after a day without a drink: stress, then pain. |
| Brittle | -8 | Solid hits can fracture a limb. |
| Fumbler | -8 | Swings can throw the weapon out of your hands; worse when panicked, hurt or tired. |
| Jinxed | -4 | Freshly generated containers near you sometimes lose an item. |
| Major Depressive Disorder | -8 | Episodes that hold mood down for days; drink, cigarettes, comfort food, exercise, time outdoors and a real antidepressant regimen all matter. |
| A Really Bad Day | -12 | CDDA-style start: drunk, sick, a shard wound, no clothes, house on fire. |
| Hallucinations | -2 | Phantom zombies, sounds, thumps, whispers and panic bouts. |
| Brittle Asthma | -8 | Airway irritation from cold, corpses, exertion and panic; four tiers up to an attack; rescue inhaler item. |
| Gluten Intolerance | -4 | Wheat brings on a flare: cramps, nausea, low mood. |
| Vegetarian | -4 | Meat, fish, insects and anything cooked with them are refused. |
| Diabetes Type 1 | -10 | Hidden blood sugar model; insulin pen, glucose meter, test strips. |
| Diabetes Type 2 | -5 | Same model with the body's own insulin, limited by weight; metformin. |
| Renaissance Faire Geek | +10 | +1 Spear, Long Blade, Axe and Blacksmithing. |
| Gym Regular | +1 | Every exercise starts at regularity 50 (a Fitness Instructor's head start); Vitality's exercise score starts neutral instead of empty. |

**Vitality** (everyone): diet, exercise and sleep roll into one slow score. Fit and Thriving give faster endurance recovery, mood and stress relief, slow healing and cold resistance, and Thriving adds a kilo of base carry weight and double Fitness and Strength experience; Run Down and Sluggish the reverse. The conditions above read it too. A bad night's sleep sets a same-day "Slept Badly" moodle.

The airway, vitality and sleep moodles need [Moodle Framework](https://steamcommunity.com/sharedfiles/filedetails/?id=3396446795); everything else works without it.

## Layout

```
DanTraits/42/            the mod as the game sees it (mod.info, media/...)
  media/lua/shared/      one file per trait + DanTraits.lua (core helpers, eat/pill hooks)
  media/lua/client/      context menus, moodles, telemetry for the dashboard
  media/scripts/         trait and item definitions
DanTraits/tools/         dashboard.py + Dashboard.bat (live readout and command console)
tests/                   offline tests (fengari); python tests/run_tests.py
deploy.py                copy the mod to ~/Zomboid/mods (or --pull edits back)
```

## Workflow

1. Edit in this repo.
2. `python tests/run_tests.py`
3. `python deploy.py` then restart the game (traits, items and Lua are read at boot).
4. `DanTraits/tools/Dashboard.bat` for a live readout at http://127.0.0.1:8642 with buttons to trigger any trait's events.

Lua files are limited to 200 locals each by the game's Kahlua; new traits go in their own file (`require "DanTraits"` for the shared helpers). Kahlua also lacks `next` and parts of `string.format`; the offline tests run on standard Lua and will not catch that.

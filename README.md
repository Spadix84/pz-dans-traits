# Project Zomboid Vitality Project

A Project Zomboid (Build 42) mod (internal id `DanTraits`, kept for save compatibility): realistic, balanced traits that add complications to work around, plus a Vitality system that makes fresh food, exercise and sleep matter for everyone.

## Traits

| Trait | Cost | What it does |
|---|---|---|
| Alcoholic | -2 | Withdrawal after a day without a drink: craving, low mood and poor sleep, then pain, nausea and the shakes, and for heavy drinkers hallucinations and seizures; sooner and harder the deeper the habit. Anyone who drinks too often gains it; a month without alcohol loses it, and any drink after that is a coin flip to relapse. |
| Brittle | -8 | Solid hits can fracture a limb. |
| Arthritis | -10 | Stiff joints: slower to move and swing, flares in the cold and damp, and swings can throw the weapon out of your hands. |
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
| Caffeine Dependent | -2 | Half a day without coffee, tea, cola or chocolate brings a headache, tiredness and low mood; a week dry breaks the habit. |
| Migraines | -6 | Attacks brought on by bad sleep, thirst, stress, hangovers and bright daylight: hours of pain and nausea. |
| Hemophilia | -8 | Bleeding never stops on its own and costs far more health; open wounds bleed again until bandaged. |
| Anaemic | -4 | Needs fresh meat, fish, greens, eggs or iron pills; short of iron, endurance, energy and cold resistance suffer. |
| Iron Stomach | +1 | Rotten and burnt food does half the harm; food sickness climbs half as fast. |
| Early Riser | +1 | Starts well rested; every night scores a little better. |
| Meal Prepper | +1 | Starts on a good diet; variety counts over five days. |
| Smoker (vanilla, reworked) | -4 | Cravings build faster the heavier the habit; withdrawal brings irritability (the vanilla Angry moodle), hunger and restless sleep, and a cigarette only relieves the craving it answers. To anyone else a cigarette is a buzz that fades as tolerance builds. Damaged lungs recover endurance slower and cough, worse on exertion and in the morning. Anyone who smokes regularly gains it; three weeks without tobacco loses it; after that drink and stress bring cravings back, and a smoke is a coin flip to relapse. Smoking speeds up caffeine clearance. Rare nicotine gum eases quitting. |
| Deep Sleeper | +6 | Wakeful folded in (needs less sleep); light rarely wakes you and costs half the rest; the dark does more good. Wakeful is hidden at character creation. |

**Vitality** (everyone): diet, exercise and sleep roll into one slow score. Fit and Thriving give faster endurance recovery, mood and stress relief, slow healing and cold resistance, and Thriving adds a kilo of base carry weight and double Fitness and Strength experience; Run Down and Sluggish the reverse. The conditions above read it too. A bad night's sleep sets a same-day "Slept Badly" moodle.

**Sleep and light** (everyone): the light on your square while asleep sets how deep the sleep is. In the dark, tiredness drains faster and the night scores better; in a lit room it drains slower, the night scores worse, and anything brighter than reading light can wake you (up to about half the hours fully lit). Exhaustion, drink and sleeping pills sleep through it. Close the curtains, turn off the lights.
Light wakes some people more easily: Restless Sleeper, Night Owl and Cat's Eyes (re-costed from 3 to 1 for it), anyone within six hours of a mug of coffee, and during a depressive episode or a migraine. Restless Sleeper's two halves of a night, up to three hours apart, score as one night. Desensitized characters have nightmares. A bad night makes a depressive episode more likely; sleeping with the light on makes a migraine more likely and stops sleep from shortening an attack as much.

**Hangovers** (everyone): drink past a light buzz and a hangover waits for you to sober up, or to wake: at least six hours of headache, low mood, thirst and tiredness, longer and with nausea after a heavy night. A drink hides it and stops the clock, and counts toward the next one. Alcoholics carry the habit as tolerance: more drink to feel it, withdrawal sooner and harder, hangovers a little milder.

**Drink relief** (everyone): vanilla treats any sip of alcohol as a full dose of beta blockers and painkillers, however small. That is undone, and the relief follows the Drunk moodle instead: pain reduction of 20, 40, 60 or 80 by level, and panic that settles at a quarter, half, three quarters or the full beta-blocker rate.

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

The game's Lua (Kahlua) allows 200 locals and 60 upvalues per function, the file's top level included, so new traits go in their own file (`require "DanTraits"` for the shared helpers). It also lacks `next`, `assert`, `xpcall`, `string.gmatch` and `string.rep`. The offline tests run on standard Lua and would not notice any of that, so `tests/lint_kahlua.py` (run first by `run_tests.py`) checks for it, and checks the translation files too: valid JSON, no duplicate keys, and no bare `%` (the game formats UI strings; write `%%` for a percent sign, `%1` for a placeholder).

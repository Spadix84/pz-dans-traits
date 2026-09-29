# Project Zomboid Vitality Project

A Project Zomboid (Build 42) mod (internal id `DanTraits`, kept for save compatibility): realistic, balanced traits that add complications to work around, plus a Vitality system that makes fresh food, exercise and sleep matter for everyone.

## Traits

| Trait | Cost | What it does |
|---|---|---|
| Alcoholic | -2 | Withdrawal after a day without a drink: craving, low mood and poor sleep, then pain, nausea and the shakes, and for heavy drinkers hallucinations and seizures (a seizure can concuss); sooner and harder the deeper the habit. Anyone who drinks too often gains it; a month without alcohol loses it, and any drink after that is a coin flip to relapse. |
| Brittle | -8 | Solid hits can fracture a limb. |
| Arthritis | -10 | Stiff joints: slower to move and swing, flares in the cold and damp, and swings can throw the weapon out of your hands. |
| Jinxed | -4 | Freshly generated containers near you sometimes lose an item. |
| Major Depressive Disorder | -8 | Episodes that hold mood down for days; drink, cigarettes, comfort food, exercise, time outdoors and a real antidepressant regimen all matter. |
| A Really Bad Day | -12 | CDDA-style start: drunk, sick, a shard wound, no clothes, house on fire. |
| Hallucinations | -2 | Phantom zombies, sounds, thumps, whispers and panic bouts. |
| Brittle Asthma | -8 | Airway irritation from cold, corpses, exertion and panic; four tiers up to an attack (an attack that empties you can black you out); smoking, and a smoker's lungs, make it worse; rescue inhaler item. |
| Gluten Intolerance | -4 | Wheat brings on a flare: cramps, nausea, low mood. |
| Vegetarian | -4 | Meat, fish, insects and anything cooked with them are refused. |
| Diabetes Type 1 | -10 | Hidden blood sugar model; insulin pen, glucose meter, test strips; a bad low can put you on the floor. |
| Diabetes Type 2 | -5 | Same model with the body's own insulin, limited by weight; metformin; a bad low can put you on the floor. |
| Renaissance Faire Geek | +10 | +1 Spear, Long Blade, Axe and Blacksmithing. |
| Gym Regular | +1 | Every exercise starts at regularity 50 (a Fitness Instructor's head start); Vitality's exercise score starts neutral instead of empty. |
| Caffeine Dependent | -2 | Half a day without coffee, tea, cola or chocolate brings a headache, tiredness and low mood; a week dry breaks the habit. |
| Migraines | -6 | Attacks brought on by bad sleep, thirst, stress, hangovers and bright daylight: hours of pain and nausea. |
| Hemophilia | -8 | Bleeding never stops on its own and open wounds bleed again until bandaged. With **Blood**: bleeds lose half as much again, and a bandage only slows one to two fifths, so stitches are what stop it (without Blood, open bleeds cost extra health). |
| Anaemic | -4 | Needs fresh meat, fish, greens, eggs or iron pills; short of iron, endurance, energy and cold resistance suffer. After blood loss, red cells rebuild at half speed, slower still short of iron, and rebuilding them spends iron. |
| Iron Stomach | +1 | Rotten and burnt food does half the harm; food sickness climbs half as fast. |
| Early Riser | +1 | Starts well rested; every night scores a little better. |
| Meal Prepper | +1 | Starts on a good diet; variety counts over five days. |
| Smoker (vanilla, reworked) | -4 | Cravings build faster the heavier the habit; withdrawal brings irritability (the vanilla Angry moodle), hunger and restless sleep, and a cigarette only relieves the craving it answers. To anyone else a cigarette is a buzz that fades as tolerance builds. Damaged lungs recover endurance slower and cough, worse on exertion and in the morning. Anyone who smokes regularly gains it; three weeks without tobacco loses it; after that drink and stress bring cravings back, and a smoke is a coin flip to relapse. Smoking speeds up caffeine clearance. Rare nicotine gum eases quitting. |
| Fear of Blood (vanilla, reworked) | -6 | Vanilla's panic at your own bleeding and stress when bloody stay. Treating a wound takes a quarter longer, and stitching (25%), pulling out a bullet (35%) or glass (20%), or dressing a bleeding wound (10%) can make you faint (about eight seconds, woken by anything that wounds you); so can losing blood fast. Still can't perform first aid on others. |
| Deep Sleeper | +6 | Wakeful folded in (needs less sleep); light rarely wakes you and costs half the rest; the dark does more good. Wakeful is hidden at character creation. |
| In Their 20s | -2 | No extra profession level; can't take Handy or Arthritis; Gym Regular starts at 65. See **Age**. |
| In Their 40s | +1 | One extra profession level; Handy gives +1 Carpentry more; Arthritis flares sooner. See **Age**. |

**Age** (everyone, prototype): every character is in their 20s, 30s or 40s. The 30s are the default and have no trait; the two age traits pick the others. A new character gets extra levels in their profession's main skill (the one it boosts most): none in the 20s, one in the 30s and 40s. Trait costs are fixed, so age changes what traits do instead: Handy and Arthritis are locked out in the 20s, Gym Regular starts higher; in the 40s Handy gives another Carpentry level and Arthritis flares sooner. Sandbox options (Vitality Project page) turn age off, set the default age and the levels per decade.

**Vitality** (everyone): diet, exercise and sleep roll into one slow score. Fit and Thriving give faster endurance recovery, mood and stress relief, slow healing and cold resistance, and Thriving adds a kilo of base carry weight and double Fitness and Strength experience; Run Down and Sluggish the reverse. The conditions above read it too. A bad night's sleep sets a same-day "Slept Badly" moodle.

**Sleep and light** (everyone): the light on your square while asleep sets how deep the sleep is. In the dark, tiredness drains faster and the night scores better; in a lit room it drains slower, the night scores worse, and anything brighter than reading light can wake you (up to about half the hours fully lit). Exhaustion, drink and sleeping pills sleep through it. Close the curtains, turn off the lights.
Light wakes some people more easily: Restless Sleeper, Night Owl and Cat's Eyes (re-costed from 3 to 1 for it), anyone within six hours of a mug of coffee, and during a depressive episode or a migraine. Restless Sleeper's two halves of a night, up to three hours apart, score as one night. Desensitized characters have nightmares. A bad night makes a depressive episode more likely; sleeping with the light on makes a migraine more likely and stops sleep from shortening an attack as much.

**Blood** (everyone; health overhaul, phase 1): bleeding drains blood instead of health. How fast depends on how bad the bleed is (the game's own bleeding clock), where (neck three times, head, thigh and groin half as much again, chest and belly a little more, hands and feet less) and the dressing: a bandage slows it to a tenth, a shard or bullet left in bleeds through the bandage, stitches stop it. Lose 15% and you are Pale (endurance recovers slower); 30%, Light-headed (no sprinting, anxious); 40%, Shock (endurance capped, health draining, and you can pass out for 5 to 15 game minutes); 45%, Bleeding Out (passing out more often); half your blood is death. Blood volume comes back in about a day if you drink, and makes you thirsty; red cells take about a week, faster fed and asleep and with good Vitality, and while short you tire sooner. The wound itself still hurts until it is dressed and stitched, as in vanilla. A sandbox option turns it off (vanilla bleeding).

**Wound infection** (everyone; health overhaul, phase 2): replaces vanilla's. Each hour a wound may take an infection: more likely for a deep wound or bite than a scratch, much more with a shard or bullet left in, open or under a spent bandage, or under dirty or bloody clothes; far less once the wound has been disinfected, and not at all while disinfectant or garlic is still on it (or under a fresh alcohol bandage). Prone to Illness and Resilient count. It incubates unseen for 8 to 16 hours, and cleaning the wound then ends it. Then it shows as the wound's infection level (the health panel, the pain) and climbs about 2 a day, and the wound stops healing; disinfectant and garlic still push it back. At level 5 it spreads: fever (the body's temperature rises, the Sick moodle, tiredness, thirst) and only antibiotics work. Past that, sepsis drains health, faster the worse it gets; untreated it kills in a couple of days. Antibiotics are the game's own pills, one a dose: each tops up a level in the blood that halves every six hours, and while it is high enough the infection falls back. A dose every eight hours keeps it there; a box of 12 is a course. Stop before ten doses once it is gone and it has a coin flip to come back. Vanilla's one-pill cure is gone. Zombie infection is untouched. Infection moodle; a sandbox option turns it off.

**Wound care** (everyone; health overhaul, phase 3): a bandage wears out over about a day, faster wet and faster still as blood soaks through it (vanilla's own drain, which spends a bandage in minutes over a bleeding deep wound, is replaced); spent, it only halves a bleed and invites infection, and you are told to change it. An unstitched deep wound heals at about a third of the speed, and hard use of the limb can open it again. Fresh stitches can tear: swinging a weapon with a stitched arm (both arms two-handed), sprinting or running on a stitched leg, less on the torso, less under a bandage; they hold better as they heal and are sound once the game's stitch time passes 40. Torn, the wound is open and bleeding again. Setting a splint is a First Aid roll (half the time at level 0, 6% less a level, never under 2%): set badly, the bone heals at half the speed and hurts, and only a setter at level 3 or more can tell; take it off and set it again. Moving on a broken leg with no splint makes the break worse. A sandbox option turns it off.

**What First Aid tells you** (everyone; health overhaul, phase 4): the health panel's wound list is written for the examiner's First Aid level (your own, or the doctor's for a patient, read live; vanilla kept the level from game start). At 0 to 2 it is what anyone can see: scratched, cut, a bad cut, bitten, bleeding, something stuck in it, a dressing, "might be broken", and an infection only once it is red and swollen; no severities. From 3 the game's own detail, plus infected, a dressing wearing thin and a badly set bone. From 6, how far an infection has got and how stitches are holding. At 9 and 10, an infection that hasn't shown yet and how far a break has healed. It wraps whichever list drawing is installed, so it works over mods that replace it (NestedHealthInfo), and leaves the debug view alone.

**Concussion** (everyone; health overhaul, phase 5): a hard landing (a fall from about the second floor up has a chance, one a little higher more), a car crash, being hit by a car, or a weapon hit that takes health off the head can concuss. A helmet (army helmet, hard hat) makes it less likely and less bad. Dazed: a headache, drowsy. Concussed: sick to the stomach too, bright daylight makes the headache worse, slower to get your breath back, and running can bring on a dizzy fall; a quarter of the time it knocks you out briefly. Badly concussed: knocked out on the spot for 5 to 15 game minutes. Rest heals it, sleep twice as fast; running and fighting stop it healing. A second knock lands on top of the first. It brings on migraine attacks and makes light wake you more easily. Shown on the head in the health panel. A sandbox option turns it off.

**Passing out** (shock, concussion, Fear of Blood): you fall, end up sitting on the floor, the screen goes black and you can't do anything until you come round, in real time (no time skip), for game minutes but never under eight real seconds. Zombies can still get to you. A faint is shallow: anything wounding you jolts you awake. A concussion knockout is not.

**Hangovers** (everyone): drink past a light buzz and a hangover waits for you to sober up, or to wake: at least six hours of headache, low mood, thirst and tiredness, longer and with nausea after a heavy night. A drink hides it and stops the clock, and counts toward the next one. Alcoholics carry the habit as tolerance: more drink to feel it, withdrawal sooner and harder, hangovers a little milder.

**Drink relief** (everyone): vanilla treats any sip of alcohol as a full dose of beta blockers and painkillers, however small. That is undone, and the relief follows the Drunk moodle instead: pain reduction of 20, 40, 60 or 80 by level, and panic that settles at a quarter, half, three quarters or the full beta-blocker rate.

The airway, vitality, sleep, blood loss, infection and concussion moodles need [Moodle Framework](https://steamcommunity.com/sharedfiles/filedetails/?id=3396446795); everything else works without it.

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

The game's Lua (Kahlua) allows 200 locals and 60 upvalues per function, the file's top level included, so new traits go in their own file (`require "DanTraits"` for the shared helpers). It also lacks `next`, `assert`, `xpcall`, `string.gmatch` and `string.rep`. The offline tests run on standard Lua and would not notice any of that, so `tests/lint_kahlua.py` (run first by `run_tests.py`) checks for it, and checks the translation files too: valid JSON, no duplicate keys, and no bare `%` (the game formats UI strings; write `%%` for a percent sign, `%1` for a placeholder). Calling a Java method an object doesn't have fails quietly inside `pcall` but dumps a stack trace to the log every time, and the tests' stand-ins can't notice, so `tests/check_api.py` (also run by `run_tests.py`) checks the method names called on body parts, body damage, players, stats and weapons against the installed game's jar.

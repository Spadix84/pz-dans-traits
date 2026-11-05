# Illness tests for 2026-11-04 (debug)

In-game checks for the six illnesses, the one fever and the symptom medicine. Each test has a **Do** and an **Expect**; tick it or note what really happened. Allow about three hours. The order goes cheap checks first, then the long timing ones.

## Setup

1. Launch with `-debug`. Make a **throwaway sandbox world** (single player): one of the tests changes the month.
   - Health page: Illness on, all six illnesses on, Illness Frequency 100.
   - Infection on.
2. Commands go in the companion's **Console** tab, or one per line in `Zomboid/Lua/DanTraits_Commands.txt`. The reply comes back in the console.
3. Handy commands:

   | Command | What it does |
   |---|---|
   | `ill` | what is running: hours done / course length (rounded), severity, fever. Exact hours done: `lua return d.ill.<id>.t` |
   | `ill <id>` / `ill <id> now` | catch it (hidden first) / start the symptoms at once |
   | `ill clear` | end everything, immunity included |
   | `fever` | the raw total fever and each source (before fever reducers). Felt total: `lua return DanTraits_FeverTotal(player)` |
   | `firstaid <0-10>` | set First Aid (the health panel reading changes with it) |
   | `give <Module.Item>` | spawn an item |
   | `trait add <id>` / `trait remove <id>` | |
   | `stat <NAME> <value>` | |
   | `lua <code>` | run a line; `player` and `d` (the mod data) are in scope; `return x` reports x |

   The ids are `cold`, `flu`, `pneumonia`, `strep`, `stomach` and `food`.
4. **Jump to the peak:** `lua d.ill.<id>.t = d.ill.<id>.len * <x>`, where x is:

   | cold | flu | pneumonia | strep | stomach | food |
   |---|---|---|---|---|---|
   | 0.35 | 0.25 | 0.4 | 0.3 | 0.3 | 0.25 |

   Then let one game minute pass.
5. **Jump to the end:** `lua d.ill.<id>.t = d.ill.<id>.len - 0.05`, then let about 5 game minutes pass.
6. **Force a catch route:** the chances are live constants in `DanTraits_ILL`, so `lua DanTraits_ILL.FLU_BASE_H = 60` makes the flu certain within a minute. Every such change is undone by quitting to the menu and loading again; do that after each forced test.
7. Keep `console.txt` open in the companion's Live tab for errors.

---

## General

- [ ] **G1** Load an existing save from before this build.
  - Expect: no errors.
  - `fever` lists the sources: infection, then cold, flu, pneumonia, strep, stomach and food, all 0.00.
- [ ] **G2** Open the health panel while well.
  - Expect: no Illness section.

## Common cold

- [ ] **C1** `ill cold`, then `firstaid 10` and open the panel.
  - Expect: "Coming down with: Common cold (viral), in …".
  - At `firstaid 7` the brewing line is gone (only 9+ sees it).
- [ ] **C2** `ill cold now`.
  - Expect: the notice "Your throat's scratchy", and the game's cold moodle within a minute.
  - Sneezes and coughs over the next game hour.
- [ ] **C3** Jump to the peak.
  - `lua return player:getBodyDamage():getColdStrength()`. Expect: about 20 + 50 × severity, with the severity from `ill`.
  - `fever` shows cold at about 0.25 × (sev − 0.6) / 0.4, or 0 below sev 0.6.
- [ ] **C4** The panel by First Aid level:

  | First Aid | Expect |
  |---|---|
  | 1 | "a runny nose and a cough" (and "feverish" if there is a fever) |
  | 4 | "a cold, by the look of it" |
  | 7 | "Common cold (viral), day N, getting worse / easing" + "fever, 3x.x C" |
  | 10 | the same + "over in …" |

- [ ] **C5** Medicine. `give DanTraits.NightColdLiquid` and take a dose. Once it's working, repeat C3's cold-strength line.
  - Expect: the part above 20 is halved (×0.5), with fewer coughs.
  - Repeat with each of these, using `ill clear` + `ill cold now` + jump to the peak between them, or wait them out:

    | Medicine | Expect |
    |---|---|
    | `DanTraits.DayColdCapsules` | ×0.6 |
    | `DanTraits.CoughSyrup` | ×0.5 |
    | `DanTraits.Antihistamines` | ×0.8 |

  - Night-time liquid: you get drowsy. Daytime capsules: jittery (stress).
- [ ] **C6** Jump to the end.
  - Expect: "The cold's cleared up", the cold moodle goes, and `ill` says nothing running.
  - `lua return d.illImmune.cold - DanTraits_WorldHours()` is 504-840 (3-5 weeks in hours).
- [ ] **C7** The wet-and-cold route. `ill clear`, then `lua player:getBodyDamage():setCatchACold(89)`, then stand in the rain or get soaked in the cold. Check `lua return player:getBodyDamage():getCatchACold()` every few minutes.
  - Expect: once it passes 90 it drops to 0 at once, and `ill` shows "cold in N min" three times in four.
  - The game's own cold must **not** start at once.
  - Repeat 3-4 times to see the misses.
- [ ] **C8** Adopting a cold. `ill clear`, then `lua player:getBodyDamage():setHasACold(true); player:getBodyDamage():setColdStrength(50)`.
  - Expect: next minute `ill` shows a cold running with sev ≥ 0.6, and the notice.
- [ ] **C9** A tissue in the inventory muffles the sneezes (vanilla behaviour, still working with us driving the cold).

## Flu

- [ ] **F1** `ill flu now`.
  - Expect: "You ache all over and you can't stop shivering", the cold moodle and coughing.
- [ ] **F2** Jump to the peak.
  - `fever`: flu ≈ 0.7 × sev.
  - A pain moodle.
  - `lua return player:getStats():get(CharacterStat.ENDURANCE)` stays ≤ 1 − 0.5 × sev, even after resting. Sprinting runs out fast.
- [ ] **F3** The at-risk groups.
  - Run `ill clear` + `ill flu now` and note `lua return d.ill.flu.peak`.
  - Then `trait add asthma` + `ill clear` + `ill flu now`.
  - Expect: the peak about ×1.3 (capped at 1; repeat a few times, since it is rolled).
  - `trait remove asthma` after.
- [ ] **F4** The season (forced). Run `lua DanTraits_ILL.FLU_BASE_H = 60` in July and wait 10 game minutes.
  - Expect: no flu.
  - Then `lua getGameTime():setMonth(0)` (January). Expect: "flu in N min" within a minute or two.
  - Reload after.
- [ ] **F5** Immunity. Jump to the end.
  - Expect: "The flu's let go of you", the cough goes.
  - `lua return d.illImmune.flu - DanTraits_WorldHours()` is 2880-3600.
  - (`ill flu` from the console clears immunity on purpose, so it can't test this.)
- [ ] **F6** The panel at First Aid 1 / 4 / 7.
  - Expect: "aches all over, chills and a cough" / "the flu, by the look of it" / "Influenza (viral), day N, …".
- [ ] **F7** Fever reducers at the peak. Note `lua return DanTraits_FeverTotal(player)`, take a painkiller (`give Base.Pills`), and check again once it works.
  - Expect: the felt total ×0.6.
  - `lua return DanTraits_FeverRaw(player)` (and `fever`) unchanged.

## Pneumonia

- [ ] **P1** The route (forced).
  - Set it up: `ill clear`, `ill flu now`, jump the flu to its peak, then `lua DanTraits_ILL.PNEU_FLU_H = 1`.
  - Standing still, dry: it may take several minutes; note how long.
  - Then `ill clear` and repeat with `stat WETNESS 80` and sprinting. Expect: it comes much faster (×6).
  - Reload after.
- [ ] **P2** `ill pneumonia now`.
  - Expect: "Every breath rattles in your chest", the cough, chest pain.
  - `fever` pneumonia ≈ 0.8 × sev.
  - Endurance stays ≤ 1 − 0.6 × sev.
- [ ] **P3** The panel at First Aid 1 / 4 / 7.
  - Expect: "a deep, rattling cough, short of breath" / "something on the chest" / "Pneumonia (bacterial), day N, …".
- [ ] **P4** The health drain (the one we have no number for).
  - Run `lua d.ill.pneumonia.peak = 1; d.ill.pneumonia.t = d.ill.pneumonia.len * 0.4`.
  - Fed and watered, note `lua return player:getBodyDamage():getOverallBodyHealth()` each game hour for 4 hours.
  - Designed: about 4.8 an hour at severity 1, before the game's own healing. **Write down the real loss per hour.**
- [ ] **P5** Antibiotics. Do P4's setup, then `give Base.Antibiotics` and take one.
  - Expect: `lua return d.infAbx` ≈ 1.
  - Over one game hour, `ill` shows the hours done going up by about 2.5, against 1 before.
  - Fever ×0.7, and the health drain stops (0.7 × 1 = 0.7 is the line).
  - After about 6 h the level is 0.5. `lua return d.infAbx`, then take another.
- [ ] **P6** The stack.
  - `ill clear`, then `ill flu now` and `ill pneumonia now`.
  - Set both peaks to 1 and both to their peak points: `lua d.ill.flu.peak=1; d.ill.flu.t=d.ill.flu.len*0.25; d.ill.pneumonia.peak=1; d.ill.pneumonia.t=d.ill.pneumonia.len*0.4`.
  - Expect:
    - `fever` about 1.15;
    - the notice "This fever is dangerous", once;
    - the panel at First Aid 7: "fever, 3x.x C: dangerous" in red, and at 4: "a dangerous fever";
    - health falling faster than in P4.
  - Take a painkiller: the felt fever (`lua return DanTraits_FeverTotal(player)`) drops, but the danger stays (`fever` still > 1).
  - Take an antibiotic: within a minute `fever` falls under 1 and the danger stops.
- [ ] **P7** Untreated survival (the balance question). A fresh healthy character, P6's setup, no medicine, fed, watered, sleeping when tired, at 4× speed.
  - **Does the character live through the overlap?** Note the lowest health, or the time to death.
  - Repeat with `trait add smoker`.

## Strep throat

- [ ] **S1** The route (forced).
  - `ill clear`, then `lua DanTraits_ILL.STREP_COLD_H = 60` with no cold. Wait 5 minutes. Expect: strep **could** still come from the small background chance, but rarely.
  - Then `ill cold now`. Expect: "strep in N min" within a minute or two.
  - Reload after.
- [ ] **S2** `ill clear`, `ill strep now`.
  - Expect: "Swallowing is like swallowing glass", a pain moodle and a fever (`fever` ≈ 0.4 × sev at its peak).
  - **No** cold moodle and no cough.
- [ ] **S3** The panel at First Aid 1 / 4 / 7.
  - Expect: "a very sore throat" / "a bad sore throat" / "Strep throat (bacterial), day N, …".
- [ ] **S4** Black Sage at the peak (`give Base.BlackSage`, eat it).
  - Expect: "That helps, a little".
  - The pain moodle eases and **stays** eased for 3 game hours: the illness's pain floor is ×0.8.
  - `ill` lists "herb ache x0.80 …".
- [ ] **S5** Antibiotics. As in P5, the hours done go about 2.5× faster.

## Stomach bug

- [ ] **St1** The route (forced).
  - Set it up: `ill clear`, `lua DanTraits_ILL.STOMACH_MEAL = 1`, then `lua player:getHumanVisual():setDirt(BloodBodyPartType.Hand_L, 1); player:getHumanVisual():setDirt(BloodBodyPartType.Hand_R, 1)`.
  - Eat a full meal. Expect: "stomach in N min" (12-48 game hours).
  - `ill clear`, wash yourself at a sink or river, and eat again. Expect: nothing caught.
  - Also check that the dirty hands look dirty and that washing cleans them.
  - Reload after.
- [ ] **St2** `ill stomach now` and jump to the peak.
  - Expect: "Your stomach's turning".
  - The nausea moodle climbs (food sickness rising about 1 a minute toward 50 × sev): check with `lua return player:getStats():get(CharacterStat.FOOD_SICKNESS)`.
  - Thirst climbs and the cramps show as pain.
- [ ] **St3** Medicine at the peak, one at a time: `give DanTraits.BismuthLiquid` / `DanTraits.Dimenhydrinate` / `DanTraits.Promethazine`.
  - Expect the food sickness floor to fall to:

    | Medicine | Floor | Also |
    |---|---|---|
    | Bismuth | ×0.6 | cramps ×0.6, thirst ×0.7 |
    | Dimenhydrinate | ×0.5 | drowsy, dry mouth |
    | Promethazine | ×0.25 | very drowsy |

- [ ] **St4** Lemongrass (`give Base.LemonGrass`, eat it).
  - Expect: "That helps, a little".
  - Food sickness drops 12 at once (the game's own effect), then settles at about 0.7 of where it was, and stays there for 3 game hours.
  - Then eat mint (`give Base.MintHerb`). Expect: still ×0.7 (a weaker herb doesn't replace a stronger one).
  - Chamomile (`give Base.Chamomile`): the cramps (pain) ×0.8.
- [ ] **St5** The panel at First Aid 1 / 4 / 7.
  - Expect: "an upset stomach" / "a stomach bug, or something eaten" / "Stomach bug (viral), day N, …".
- [ ] **St6** An antibiotic does nothing: the hours done stay about 1 per game hour.

## Food poisoning

- [ ] **Fo1** The route (forced).
  - `ill clear`, then `lua DanTraits_ILL.FOOD_RAW = 1`.
  - Eat a raw steak (`give Base.Steak`). Expect: "food in N min" (6-24 h).
  - `ill clear`, cook a steak and eat it. Expect: nothing.
  - With a rotten item from the world and `lua DanTraits_ILL.FOOD_ROTTEN = 1`, eating it gives food poisoning **and** the game's own food sickness at once.
  - Reload after.
- [ ] **Fo2** `ill food now` and jump to the peak.
  - Expect: "Something you ate isn't sitting right".
  - Food sickness heads for 70 × sev, with cramps.
  - Note thirst over one game hour without drinking: `lua return player:getStats():get(CharacterStat.THIRST)`. Designed: about +0.07 an hour on top of normal at sev 1.
- [ ] **Fo3** Don't drink. Expect: the game's thirst moodles climb to Dying of Thirst and health falls. That is the killer, and it should feel like one.
- [ ] **Fo4** Antibiotics: the hours done go about 2.5× faster (the course is under a day).
- [ ] **Fo5** Food poisoning and the stomach bug at once (`ill stomach now` + `ill food now`).
  - Expect: at First Aid 1 the panel shows **one** "an upset stomach" line, not two.
  - At 7, both named.

## Herbs

- [ ] **H1** Herbal tea. `ill cold now`, jump to the peak.
  - Make a mug of hot water, add Common Mallow (`give Base.CommonMallow`) through the hot drink evolved recipe, and drink it.
  - Expect: "That helps, a little", the cold strength (C3's line) shows ×0.8, and `ill` lists "herb cold x0.80 …".
  - **This checks that a herb added as a spice is seen.** If nothing happens, note what the mug is called. It may store the herb under a list we don't read.
- [ ] **H2** Wear-off. After 3 game hours, `ill` no longer lists the herb, and the symptom is back to full.
- [ ] **H3** A herb while well (eat Black Sage with nothing running). Expect: no notice, no errors.

## Across the illnesses

- [ ] **X1** The one fever with a wound. Run `infect Hand_L`, let it grow until `fever` shows the infection, then `ill flu now`.
  - Expect: total = the bigger + half the smaller.
  - The infection grows faster than without the flu: compare the infection's line in `fever` over an hour.
- [ ] **X2** Sleep pace. `ill cold now`, note the hours done, sleep 8 h away from home, and check again.
  - Expect: about +10.4 h.
  - At an established home (3+ nights slept there): about +12 h.
  - As a Nomad: always +10.4 h.
- [ ] **X3** Running. Over one game hour of running, the hours done go up by about 0.8.
- [ ] **X4** Save and reload mid-illness (one hidden, one running).
  - Expect: both resume where they were, and the cold moodle is back.
- [ ] **X5** If debug lets you change the sandbox in game: turn Illness off with a cold running.
  - Expect: the cold moodle goes and `fever` is 0.
  - Turn it back on: the cold resumes.

## What to bring back

- P4's health loss per hour and P7's result (whether an untreated flu plus pneumonia is survivable).
- Whether stamina held down (F2, P2) feels right or too punishing.
- Whether the cold moodle and coughing look right driven by the flu and pneumonia.
- Any errors in `console.txt`, with the test id.

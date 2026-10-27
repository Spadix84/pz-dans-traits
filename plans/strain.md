# Strain: the cumulative cost of fighting

Design note, 2026-10-24. Talked through with the user the same day. Phase 1 built the same
day (see "As built" at the end); phase 2 built 2026-10-25.

## Why

The mod's idea is to slow the player down. The first days go on supplies and
a base; then the base becomes a home, and you go out when you need something.
Nothing in the game pushes that today. Stress is a bar that empties itself,
so a character who fought hordes for three days straight is fine after one
quiet afternoon, and every comfort the mod has built (reading, cooking,
laundry, home, workouts) is racing a bar that would have emptied anyway.

Strain is the memory. It is a slow tank (0..100) that fills with combat and
shocks and drains with rest, sleep and comforts, over days. It does **not**
make you fight worse: a stressed character who swings weaker takes more hits
and gets more stressed, a spiral. It makes the fighting **teach less**.
Grinding stops paying; going home pays.

Every character has it (sandbox `StrainEnabled`, on by default), as every
character has sleep debt and wound infection.

## The tank

Numbers below are the user's targets (2026-10-24) and the per-event values
`plans/strain_sim.py` solved for them. Change them in the simulator first,
then here.

### What fills it

| Source | Strain | Notes |
|---|---|---|
| A melee kill | 0.1 x (1 + k/100) | k = kills so far today, reset by sleep. The 150th kill costs 2.5 times the first. Short trips beat long ones |
| A vehicle kill | a third of a kill | Cost and count, so running hordes over is not free |
| A minute with panic over 40 | 0.1 | Vanilla panic already rises with the crowd, and Brave, Cowardly, Desensitized and Seen It All change it |
| Hit: scratch / laceration / deep wound / grabbed or knocked down | 1 / 2 / 3 / 1.5 | |
| A bite | **50** | Each bite |
| Health under 25 | **50** | Once a day |
| Fever (a spreading wound infection) | 0.25 an hour at full fever | About 6 a day |
| Sepsis | 0.5 an hour | |
| Sick from food, at the Sick moodle's worst | 0.15 an hour | |
| Pain, at full | 0.15 an hour | Grit lowers it for free |
| Alcoholic, sober: craving / shakes / delirium | 0.15 / 0.3 / 0.5 an hour awake | Sobriety ticks it up; see Drink and smoke |
| Smoker, full nicotine withdrawal | 0.1 an hour awake | Scaled by the withdrawal stat |
| A hangover | 2 | The morning after a night past Drunk 2 |

**The first week counts half** (days 1-7, sandbox `StrainEarlyDays` and `StrainEarlyRate`), for the
supply rush before there is a home to rest in.

The outing targets, from 0 (with the scratches and panic a day like that
brings):

| Day | Gained |
|---|---|
| Quiet supply run, 25 kills | +5 |
| Busy day, 75 kills | +17 |
| Horde day, 150 kills, surrounded several times | +41 |
| Horde day and bitten | +91 |

### What drains it

| Source | Strain off | Notes |
|---|---|---|
| An hour awake with no fight in the last two, anywhere | 0.375 | Six over a calm day |
| A night in a bed | 4 | x the night's quality (Vitality's sleep score), so Slept Badly halves it |
| A night sleeping rough (ground, car seat) | 2 | Also x quality |
| A shower or bath | 2 | |
| Laundry: a load done, or changing into clean clothes | 2 | |
| A Good Meal | 2 / 3 / 4 | By the cooking overhaul's dish tier |
| A Good Read (an hour of it) | 2 | |
| Pumped (after a workout) | 2 | |
| Drunk 2+, an hour | 2 | Up to 8 a day. Tipsy (Drunk 1) 0.75 an hour |
| A cigarette | 0.75 | Up to 3 a day |

- **Comforts count once a day.** The second shower gives half, the third
  nothing. A well-rounded day beats spamming one thing.
- **Comforts at home count x1.5** (Homebody x2). Sleep and calm hours count
  the same anywhere: a calm day in the field is as restful as a lazy day at
  home (user, 2026-10-24). Home's edge is its comforts.
- **Four or more different comforts in a day: that day's comforts x1.25.** The
  shower, laundry, cook, read, work out day, as a mechanic.
- Fever halves what calm hours and sleep take off: you cannot rest it away.

The recovery targets:

| Day | Strain |
|---|---|
| Full day off at home: sleep, shower, laundry, Good Meal, read, workout | -30 |
| Lazy day at home: sleep and eat | -10 |
| Out in the field, no fighting | -10 |
| Out in the field, sleeping rough | -8 |
| Home with a fever | +2 (it creeps) |

### Drink and smoke

Getting drunk takes strain off, enough to be a reason to drink most nights
(a real night is about -8, the hangover gives 2 back). The alcoholism meter
already fills with a daily habit, so a character who drinks every night to
cope becomes an Alcoholic in a few weeks. That is the price, and it is the
existing system doing it.

For an **Alcoholic** a drink takes a quarter as much off, and being sober
puts strain on by withdrawal stage. Drinking just holds them level; going dry
on busy days with the evening routine climbs about 3, 6, 11, 17, 25, 34, 43
over a week. **Smoker** works the same way: a cigarette a quarter, withdrawal
ticks strain up. Both traits get harder, so their prices go up: Alcoholic
from 4 points to 6, Smoker from 4 to 5 (display sign; settle in play).
**Straight Edge** loses both outlets and should give more than its 1 point:
2 or 3.

## Tiers and the XP curve

| Strain | Tier (moodle) | Combat XP | Other XP | Also |
|---|---|---|---|---|
| 0-10 | **At Ease** (good moodle) | x1.1 | x1.0 | |
| 10-25 | none | x1.0 | x1.0 | |
| 25-50 | **Frayed** | x1.0 to x0.75 | x1.0 | |
| 50-75 | **Worn Down** | x0.75 to x0.4 | half the combat penalty | Unhappiness floor 15 |
| 75-100 | **Burnt Out** | x0.4 to x0.15 | half the combat penalty | Unhappiness floor 30 |
| 100 | **Breaking Point** | | | A shutdown, then strain drops to 60 |

- **Combat skills** take the full curve: every weapon skill, Aiming,
  Reloading, Strength and Fitness. **Every other skill** takes half the
  penalty, and only above 50 (user, 2026-10-24). Cooking or reading at home is
  the recovery, and strain is falling while you do it.
- **At Ease** is the carrot, not a bank: it holds while strain is under 10 and
  the first hard day takes it away. (Not "Settled": that is the 40s sleep
  trait.)
- **Breaking Point**: the character sits where they are for a while and
  cannot act, then strain drops to 60 (user, 2026-10-24). Sandbox
  `StrainBreakdown` turns it off (multipliers only). (The first draft said it
  reused Sensory Issues' shutdown; that shutdown is no sprinting and low mood,
  not a loss of control, so it got its own action. See "As built".)
- The moodle shows the tier, not the number, as sleep debt does. The health
  panel gets a Strain line with the trend (rising, easing).
- Strain does not touch damage, accuracy, endurance or swing speed.

## What the simulator says

`python plans/strain_sim.py`, three weeks from day 8, from 0. "Kill-XP earned"
is kills x the multiplier at the day's peak: what the fighting actually taught.

| Pattern | Peak | Breaking points | Kills | XP per kill | Kill-XP earned |
|---|---|---|---|---|---|
| Horde every day, no routine | 100 | 10 | 3150 | x0.21 | 670 |
| Horde every day, shower + meal | 100 | 9 | 3150 | x0.25 | 790 |
| **Busy every day + evening routine** (shower, meal, read) | 29 | 0 | 1575 | x0.99 | **1562** |
| Busy every day, nothing after | 100 | 4 | 1575 | x0.41 | 651 |
| Horde, then 1 day off | 92 | 0 | 1650 | x0.53 | 877 |
| Horde, then 2 days off | 41 | 0 | 1050 | x0.84 | 884 |
| Rough week: 4 horde days, then 3 at home | 100 | 3 | 1800 | x0.39 | 706 |
| Busy every day + drinking every night | 100 | 2 | 1575 | x0.50 | 793 |
| Horde every day, Level Headed | 100 | 5 | 3150 | x0.36 | 1144 |
| Rough week, Level Headed | 66 | 0 | 1800 | x0.79 | 1418 |
| Rough week, High Strung | 100 | 9 | 1800 | x0.26 | 469 |

What it means:

- **The paced player learns twice as much from half the kills.** Busy days
  with an evening routine earn 1562 against the horde grinder's 670. That is
  the whole design working.
- **Two horde days in a row are fine; the third breaks you.** A rough week
  heals in three days at home.
- A busy day with the evening routine nets about +0.6: a daily fighter who
  looks after themselves can keep it up for weeks, and needs a quiet stretch
  now and then.
- **The first week:** horde every day with a shower and a meal reaches Worn
  Down by day 5 even at half strain, and Burnt Out on day 8 when the full
  rate starts. Clearing a town in week one is still possible; doing it every
  day is not.
- High Strung at x1.5 breaks every rough week three times. x1.33 may be
  kinder; settle in play.

## Traits

New (display sign: -N costs N points):

| Trait | Price | Effect |
|---|---|---|
| **Level Headed** | -8 | Gains strain half as fast (user, 2026-10-24) |
| **High Strung** | +6 | Gains strain x1.5 (or x1.33). Excludes Level Headed |
| **Unwinds Easily** | -4 | Everything that takes strain off counts x1.5 |
| **Can't Switch Off** | +4 | Everything that takes strain off counts x0.67, and the variety bonus needs five comforts |

Existing traits that link in (phase 2):

| Trait | Link |
|---|---|
| Homebody | Comforts at home x2 (its "home does you twice the good") |
| Nomad | No home bonus; any bed slept in twice counts as home for comforts |
| Desensitized (vanilla) | Combat strain x0.6, not zero |
| Brave, Cowardly, Seen It All | Through panic minutes, no new code |
| Grit | Through pain, no new code |
| Alcoholic, Smoker, Straight Edge | As in Drink and smoke, with the new prices |
| Major Depressive Disorder | Episode chance reads strain; during an episode comforts count half, but its own helpers (exercise, fresh air, comfort food) count full |
| Hallucinations | Episode chance reads strain |
| Migraine | The stress trigger reads strain |
| Multiple Sclerosis | Flares come sooner with strain |
| Sensory Issues | A meltdown adds 5; its fast load meter stays its own |
| Endorphin Junkie | Pumped counts x2 |
| Homemaker | Laundry counts x2; line-dried clothes count as a comfort of their own |
| Keen Cook | A Good Meal counts one tier higher |
| Vitality | Burnt Out blocks Thriving; At Ease counts towards it |

## Building it

A new shared module, `DanTraits_Strain.lua`, owning `d.strain` and the day
bookkeeping, with a small API so every system feeds one place:

    DanTraits_StrainAdd(player, source, amount)      -- source names the row ("kill", "bite", "fever")
    DanTraits_StrainEase(player, comfort, amount)    -- once-a-day, home and variety rules applied here
    DanTraits_StrainLevel(player)                    -- 0..100, for the systems that read it
    DanTraits_StrainTier(player)

- **Kills:** `Events.OnZombieDead`, attacker the player (vehicle kills by the
  player's car). Verify the attacker reads in B42 first.
- **Panic minutes, illness, withdrawal, calm hours:** `DanTraits_Every`
  minute, as the other meters do.
- **Hits and bites:** the existing `OnPlayerGetDamage` attribution
  (`DanTraits_Attrib.lua`).
- **Comforts:** the systems already know when they happen: washing, the
  laundry credit, the cooking afterglow, the Good Read moodle, Pumped. Each
  calls `DanTraits_StrainEase`.
- **XP:** `Events.AddXP`, taking the share back with `DanTraits_AgeXpAdjust`
  (never below the level held). It has to run after Vitality's Thriving x1.5
  and respect `DanTraits_AgeXpBusy`, or the two fight.
- **Sleep:** on waking, x the night's quality from Vitality.
- **Telemetry:** log each source's daily total, so play-tests can tune the
  table from real days instead of guesses.
- Sandbox: `StrainEnabled`, `StrainGain` (%), `StrainEase` (%), `StrainXpFloor`
  (the lowest combat multiplier, default 15%), `StrainEarlyDays` (7), `StrainEarlyRate` (50%),
  `StrainBreakdown` (on).
- MP: strain lives in the player's mod data and runs where the player runs,
  like sleep debt. Nothing to relay until a doctor needs to see it.

## Phase 2: wiring the rest of the mod to it

The user's call (2026-10-24): once strain is in, refactor the existing
systems onto it. Many of them read momentary stress today (MDD's
`MDD_STRESS_WEIGHT`, Hallucinations' `SCHIZO_STRESS_WEIGHT`, Migraine's stress
trigger, MS flares); the comforts each lower stress on their own (Home,
reading, cooking, laundry, Pumped). Phase 2 goes system by system:
what it reads (stress or strain), what it feeds (a comfort through
`DanTraits_StrainEase`, a cost through `DanTraits_StrainAdd`), and whether its
own stress nudge stays. A review pass first lists every stress and
unhappiness touch (about 40 modules) so nothing double-counts.

## Open

- Whether calm hours should pause while hungry, thirsty or soaked.
- The per-kill escalator resets on sleep; a nap could reset it. Reset on a
  night's sleep only (4 hours+)?
- High Strung x1.5 or x1.33.
- Prices for Alcoholic, Smoker and Straight Edge once strain is in.
- Panic over 40 is a guess at "surrounded"; check in play how many minutes a
  real horde day gives.

## As built (phase 1, 2026-10-24)

`DanTraits_Strain.lua` (minute order 45, frame `StrainKnock` for knockdowns),
`TimedActions/ISStrainBreakdownAction.lua`, the Strain moodle, a Strain
section in the health panel, the four traits, six sandbox options,
`tests/test_strain.lua`. Differences from the design above:

- **Breaking Point** is its own timed action, not Sensory's shutdown. At 100
  strain holds (nothing eases it) until a safe moment: awake, ten minutes
  without a fight, no zombie within 12 tiles. Then the queue is cleared and
  the character sits down (`EventSitOnGround`) for about 30 seconds of real
  time (maxTime 1800), says a line, unhappiness floor 50. Walking, running,
  aiming or a zombie within 4 tiles stops it; it comes again at the next safe
  moment. Finished: strain 60. Never mid-fight, so it can't get anyone
  killed on its own.
- **The API**: `DanTraits_StrainAdd(player, source, amount, combat)`,
  `DanTraits_StrainEase(player, source, amount)` (raw, with the ease
  multipliers) and `DanTraits_StrainComfort(player, kind, amount)` (the
  once-a-day, home and variety rules). Phase 1 watches the other systems'
  mod data for its comforts instead of editing them: a new `ckGlow`
  (Good Meal), `ftPumpMin` starting (Pumped), `lnMoodle` going fresh (fresh
  clothes), the head of the action queue being `ISReadABook` for 60 minutes
  (an hour of reading), `hoActive` starting (hangover); washing wraps
  `ISWashYourself` and listens for Take A Bath And Shower's `OnBathingEnd`;
  tobacco uses the core's `eat` and `prePill` hooks with `DanTraits_NicotineOf`.
  Phase 2 can move each into its own system.
- **Wounds** are a per-part scan each minute (new scratch, cut, deep wound or
  bite), so wounds from NPC mods count too. "Grabbed" is not detected; being
  knocked down is (`isKnockedDown`, every frame).
- **Kill count** resets on a night's sleep only (Vitality's `nightScored`, not
  a nap): settles the open question.
- **Prices**: Alcoholic -6 and Smoker -5 applied (display sign: they give 6
  and 5). Straight Edge left at -1 for now.
- **Not yet**: Nomad gets no home bonus anywhere (phase 2: any bed slept in
  twice), and none of the phase 2 trait links are in (MDD, Hallucinations,
  Migraine, MS, Sensory, Endorphin Junkie, Homemaker, Keen Cook, Vitality).
- **Unverified in game**: `zombie:getAttackedBy()` naming the player for
  melee and car kills, `isKnockedDown`, `ISWashYourself`'s method, the sit
  animation, and the breakdown's length in real seconds.

## As built (phase 2, 2026-10-25)

A survey of every stress and unhappiness touch came first (40-odd sites).
Its main finding: nothing double-counts in the way the design feared.
Stress and unhappiness are the moment, strain is the week; a comfort that
eases both is two different tanks, by design. What did need fixing was
panic: asthma attacks, hallucinated panic bouts, bleeding and diabetic lows
all push panic over 40, which counted as combat strain and reset the calm
clock.

Decided by the user: conditions about x2 at Burnt Out, panic only with
zombies near, Straight Edge gives 3.

- `DanTraits_StrainFactor(player)` = 1 + 4/3 x strain/100, multiplied onto
  the whole chance or rate in MDD, Hallucinations, Migraine, MS and Epilepsy
  (Epilepsy was not in the table above; the survey found it reads stress the
  same way). A Burnt Out ex-smoker gets the cue cravings.
- Panic costs strain only with a zombie within 15 tiles.
- Sensory: an overload starting adds 5.
- Vitality: a new `vitalityTarget` hook; Burnt Out holds the target at 0.79
  (Thriving is 0.8), At Ease adds 0.05.
- Comforts: Endorphin Junkie's Pumped x2, Homemaker's fresh clothes x2 and
  Line-Dried as a comfort of its own, Keen Cook (and `base:cook2`) a meal
  tier up, a depressive episode x0.5 on everything but a meal or Pumped,
  Nomad's home bonus in any bed slept in twice of the last seven nights.
- Not done, on purpose: the comfort watchers stay in `DanTraits_Strain.lua`
  rather than moving into Cooking, Fitness, Laundry and Hangover. They work,
  they are tested, and moving them buys tidiness only.
- Still open: Desensitized nightmares could add strain; the stress and
  unhappiness the conditions add themselves are unchanged.

## Burnout, hardening and distance (2026-10-27)

From Workshop comments. One commenter pointed out the game already has a muscle strain, so
players now see the system as **Burnout**: the moodle's section in the health panel, the
sandbox labels, the trait descriptions, the README and the Steam notes. The code, sandbox keys
(`Strain*`) and mod data (`strain`, `st*`) keep the old name, so settings and saves carry over.

Another (Arkantos Eli) argued that killing gets easier with practice and that a shot from
across the street is not a brawl. Two changes, both on the Lua side and in `strain_sim.py`:

- **Hardened.** Combat strain (kills, panic, wounds, knockdowns; not bites, low health,
  illness or withdrawal) is x (1 - 0.4 x min(1, lifetime kills / 2000)) x (1 - 0.2 x
  min(1, days survived / 90)): x0.48 at both. Lifetime kills are the game's own count
  (`getZombieKills`), days survived `getHoursSurvived`. `DanTraits_StrainHardening`; the
  health panel adds "Hardened: the fighting wears on you N% less" under the tier once it is
  5% or more.
- **Distance.** A kill counts in full within 3 tiles (melee, a spear), falling linearly to
  0.4 at 12 tiles and beyond, cost and count, like a vehicle kill
  (`DanTraits_StrainDistanceShare`, `zombie:DistTo(player)` in `OnZombieDead`). Panic and
  hits are unchanged, so a shooter mostly saves on the kills themselves.

Skill level reducing strain was suggested and left out: strain exists to slow what grinding
teaches, and a skill discount would make grinding pay again.

What the simulator says now (lifetime kills from 0 at day 8):

| Pattern, three weeks | Before | After |
|---|---|---|
| Horde every day, no routine: breaks | 10 | 8 |
| Busy every day + evening routine: peak | 29 | 17 |
| Rough week (4 horde days, 3 home): breaks | 3 | 2 |

Over three months, a horde every day with a shower and a meal still breaks 19 times and a
busy day with nothing after 7 times, at full hardening (x0.48). Hardening helps the paced
player and the veteran; it does not make the grind free.

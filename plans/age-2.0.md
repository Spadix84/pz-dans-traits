# Age 2.0

Design note, 2026-10-30. The second pass over age, after the user played the
built system (`plans/age-v2.md`, built 2026-10-05 to 2026-10-16; how it works
is in `docs/age.md`). Naming: the docs call what is built "Age v2"; this pass
is "Age 2.0". Where this note and the code differ before the build, the code
is right; after it, `docs/age.md` is updated to match.

Signs: this note uses the player's points ("costs 5" takes 5, "gives 6"
hands 6 back). The trait script uses the game's sign, the other way round.

## What play showed (the user, 2026-10-30)

- **The 50s felt good.** The negative traits and the slower endurance
  recovery matter, but large groups are still clearable, Arthritis included,
  with the right weapons. No change asked for.
- **The 40s is the best pick.** Good profession skills, few drawbacks. That
  shape is right; the points are wrong.
- **The 20s are too generous** and need their own traits looked at. The goal
  for the young: learn faster, grow Fitness and Strength faster, maybe gain
  combat skills faster, but start far less skilled in the profession.
  Physical recovery (endurance, healing) is the most important part of the
  band and stays.
- **Lock-outs need a relook**, positive and negative.
- **Decouple from vanilla traits.** No conflicts hit yet, but the good trait
  mods leave vanilla alone and so should we.

## Decisions (2026-10-30)

1. **The 40s give 0 points** (was 2). The 30s stay as decided on 2026-10-09:
   0 points, no level. If a free 40s makes the 30s pointless in play, the 30s
   get their original +1 main level back; not before.
2. **The 20s start less skilled**: the main skill 2 levels lower, every other
   skill the profession boosts 1 lower, never below 0. The profession's
   experience rate is untouched (see "Why the rate survives"). Green retires:
   its job is the band's now. Hobby traits that give levels (Hunter,
   Gardener, Cook, Fisher and the rest) keep theirs; Handy stays the one
   exception already built (no levels in the 20s, those skills train x1.5).
3. **All five head rows** from "The 20s, the other side" (`plans/age-v2.md`)
   go in as band effects: panic x1.15, smoking and drinking habits take hold
   x1.3 with cravings back sooner, anger x1.25, Spiraling episodes x1.3,
   Schizophrenia episodes x1.25. The Smoker and Alcoholic 20s price rows come
   out (the habits are now harder young, not softer).
4. **Lock-outs**: Heart Condition is *not* locked out of the 20s. Type 2 is.
   More candidates in the table below, awaiting the user's ticks.
5. **Decouple from vanilla traits.** Traits that fold a vanilla trait in
   (Steady Hands and Dexterous, Fast Recovery and Fast Healer, Deep Sleeper
   and Wakeful) carry both effects themselves and exclude the vanilla trait,
   instead of granting it. Vanilla traits the mod extends get Vitality
   versions; a sandbox option hides the vanilla ones, and when shown they are
   exclusive with ours. Details below.
6. **Needs and wants**: the menu below, picks pending.
7. **The 20s cost 5** provisionally (from 6), set last, after a play with the
   levels gone and the head rows in.
8. **Physical recovery rows stay as built**: endurance x1.25, Fitness and
   Strength x1.5, healing x1.5, stiffness x1.5, night wakes x0.8, red cells
   x1.15, concussion x1.2, hangover x0.85, heart strain x0.8.

## The bands

| | 20s | 30s | 40s | 50s |
|---|---|---|---|---|
| Points, today | costs 6 | 0 | gives 2 | gives 6 |
| Points, 2.0 | **costs 5** | 0 | **gives 0** | gives 6 |
| Main skill | **-2** | +0 | +2 | +3 |
| Other profession skills | **-1** | +0 | +1 | +2 |
| Profession XP rate | vanilla's | vanilla's | vanilla's | vanilla's |
| Learning | all skills x1.15, under 3 x1.3, combat x1.15, Fitness/Strength x1.5 | 1 | trade x1.1 | trade x1.15, under 3 x0.9 |
| Body | recovers fast (as built) | 1 | a little slower (as built) | slower, keeps the receipts (as built) |
| Head | panic, anger, habits, episodes (new) | 1 | 1 | Seen It All available |
| Metabolism | hunger x1.15, clears x1.2 | 1 | x0.95, x0.9 | x0.9, x0.8 |

Examples of the 20s level cut: a Carpenter starts at Carpentry 1 and nothing
else (vanilla 3 / 1 / 1 / 1 / 1); a Doctor at First Aid 1, Short Blade 0; a
Veteran at Aiming 0 and Reloading 0 (vanilla 2 / 2: both are main skills, so
both lose 2); a Fitness Instructor keeps Fitness and Strength (age never
touches them) and loses 2 Sprinting. Unemployed loses nothing (there is
nothing to lose).

### Why the rate survives

The profession's experience bonus (+75%, +100%, +125%) comes from the
character's XPBoostMap, filled from the profession and trait scripts at
creation and read by the game on every gain. Age changes levels by adding or
taking experience quietly (`DanTraits_AgeXpAdjust`, `loseLevels`) and never
touches that map, which is how Green already works ("the skills still train
at the occupation's faster rate"). The 20s Carpenter at Carpentry 1 still
trains it at +125%. The creation screen shows the lost levels greyed, as it
does for Green and the 20s Handy today.

### The 20s learning rows

| Row | Today | 2.0 | Where |
|---|---|---|---|
| Every skill, any level | 1 | x1.15 | `onAgeAddXP`, a new `learn` field on the band |
| Skills under level 3 | x1.2 | x1.3 | `learn3` |
| Weapon skills, Aiming, Reloading | 1 | x1.15 | new `combat` field; the perk list Burnout already uses |
| Fitness and Strength | x1.5 | x1.5 | `xp` |

The factors multiply (`DanTraits_XpFactor`), so a 20s character on a fresh
weapon skill trains it at 1.15 x 1.3 x 1.15 = x1.72 until level 3, then
x1.32. Quick Study (x1.4 under 5) stays the big version on top.

### The 20s traits

Green retires (a save with it keeps nothing; the trait is removed on load
and the levels are not given back, since the band now takes them). Quick
Study and Bottomless Pit stay. Candidates for the slot Green leaves, one
perk and one flaw, both of the head frame:

- **Natural** (perk, costs 3): weapon skills, Aiming and Reloading train
  another x1.25. Fits "gains combat skills a bit faster" for the player who
  wants that as their build.
- **Hot-Headed** (flaw, gives 3): anger builds x1.5 on top of the band and
  falls x0.7; the angry-swing wear and curse rows Anger already has bite
  more often.
- **Restless** (flaw, gives 3): the Itchy Feet want (below) builds twice as
  fast and the mood dip is doubled. Only if Itchy Feet is built.

Picked (the user, 2026-10-30, "do them"): all three. Natural and Hot-Headed
fill Green's slot; Restless rides on Itchy Feet, which is in.

## Lock-outs, one table

Today the gating is split three ways: script exclusions (the 20s against
Arthritis), the Lua age-only table (`DanTraits_AgeOnly`, 15 traits), and the
price table doing lock-out work by stealth. 2.0 folds them into one table,
`DanTraits_AgeRules`, one row per trait: the bands that may take it, its
price per band, and the exclusions that implies. The creation screen hides a
trait the band cannot take (the age-only code already does this) and the
description names the bands. The two-way exclusion wrap stays for the
trait-to-trait exclusions that are not about age.

### Rows (ticked by the user 2026-10-30; all of them go in)

| Trait | Not in | Why | Replaces |
|---|---|---|---|
| Arthritis (ours) | 20s | built | script exclusion |
| Type 2 Diabetes (ours) | 20s | decided 2026-10-30 | the "+1" price row |
| Hard of Hearing (vanilla) | 20s | age-related hearing loss; ticked | nothing |
| Brittle (ours) | 20s | bone density is a later-life loss; ticked | nothing; the x1.25 / x1.5 rows stay |
| Gout, Underactive Thyroid (new) | 20s | decided with the disease picks | new |
| Reading Glasses, Bad Back, Bad Knees, Old Hand, Delicate Stomach | 20s, 30s | built | age-only table |
| Old Injury, Set in Their Ways, Seen It All, Cast Iron, Old Bones Know Rain | not 50s | built | age-only table |
| Pace Yourself, Settled | not 40s | built | age-only table |
| Quick Study, Bottomless Pit, Natural, Hot-Headed | not 20s | built / new | age-only table |

Kept as prices, not lock-outs: Multiple Sclerosis, Asthma, Hemophilia,
Anaemic (conditions the young do have; the 20s band softens them, so they
give fewer points there), Heart Condition (the user's call: stays available
at full price in every band). The 50s stay locked out of nothing, as decided
on 2026-10-05: Athletic at 55 is allowed, just dearer.

Positive candidates were looked for and none fit: the skill-level hobby
traits are kept for the young (decision 2), and nothing vanilla offers is
implausible at 25 or at 55. If the user has traits in mind, they go in this
table.

## Decoupling from vanilla traits

The sweep of 2026-10-30 (every `base:` key, grant, exclusion and script
block; the installed game's Lua and a string scan of the jar for where each
vanilla effect lives) found the mod touches vanilla traits in six ways, not
five. The one the first draft missed is the largest.

### What the sweep found

| Touch | Where | Count |
|---|---|---|
| **Redefine** a vanilla trait's whole definition in the script | `scripts/DanTraits.txt`: Night Vision (cost 3 to 1, line 262), Fear of Blood (-5 to -6, 510), Smoker (-3 to -5, 531), Iron Gut (2 to 4, Iron Stomach folded in, 552), Resilient (4 to 10, the Knox roll, 573), Cook (3 to 4, +1 Small Blade, recipes copied, 593), Blacksmith (6 to 7, +1 Small Blunt, 80-odd recipes copied, 615). The DTEM adapter re-creates six of them at runtime (`DanTraits_DTEM.lua:139-162`) | 7 |
| **Grant** a vanilla trait once per character (fold-ins, `DanTraits_GrantFoldIn`, mod-data flag) | Steady Hands grants Dextrous (`DanTraits_SteadyHands.lua:117`), Deep Sleeper grants Wakeful (`DanTraits_Sleep.lua:355`; Wakeful hidden at creation, `DanTraits_Client.lua:537`), Fast Recovery grants Fast Healer (`DanTraits_Positives.lua:247`), retired Iron Stomach swapped for Iron Gut (`DanTraits.lua:292`) | 4 |
| **Flip** a vanilla trait on and off in play, relying on its Java effect | Smoker by habit (`DanTraits_Smoker.lua:242, 451`), Deaf by noise-cancelling headphones (`DanTraits_Sensory.lua:390, 396`), Hard of Hearing and Keen Hearing by tinnitus (`DanTraits_Tinnitus.lua:46-54`), Short Sighted by a migraine aura (`DanTraits_Migraine.lua:294`) | 4 |
| **Rescale a vanilla stat** the trait drives | Smoker: vanilla's NICOTINE_WITHDRAWAL rise rescaled each minute, the cigarette's vanilla effect allowed to land first (`DanTraits_Smoker.lua:461-473, 326-355`) | 1 |
| **Read** the flag (vanilla's effect untouched) | Smoker (Strain), Fear of Blood (Hemophobia, Laundry), Iron Gut (Positives), Resilient and Prone to Illness (Knox, Infection), Cook (Strain), Night Vision, Night Owl, Insomniac, Wakeful, Needs More Sleep, Desensitized (Sleep, Vitality, Strain), Deaf, Hard of Hearing, Keen Hearing (Sensory), Outdoorsman (Sunburn), Handy (Age, Client), Illiterate (Reading), Short Sighted (Migraine) | about 20 |
| **Price** by band (the surcharge wrap, additive) and **exclude** (declared on our traits) | `AGE_PRICE` rows (`DanTraits_Age.lua:103-123`); 14 of our traits exclude vanilla ones | many |

Where the vanilla effect lives, for the traits in question:

| Trait | Vanilla's effect | Can a Vitality copy carry it? |
|---|---|---|
| Dextrous | Lua: transfer time x0.5 (`ISInventoryTransferAction.lua:829`, world menu, drop and pick-up actions); Java: IsoGameCharacter, HandWeapon, ClimbState, Transaction (MP transfers) | the Lua half exactly, by wrapping the same actions; the Java bits (whatever HandWeapon and ClimbState read it for) are lost |
| Fast Healer | Java only: BodyPart heal rates, vehicle crash damage | approximately: scale the heal clocks Age already paces |
| Wakeful | Java: fatigue rate; Lua: bed menu "sleep for" x0.75, MP creation gate | sleep need through Vitality's `sleepNeed` (which already reads the trait), the bed menu by a wrap; the Java fatigue rate approximately |
| Smoker | Java only: withdrawal build and stress (BodyDamage), the cigarette's eat code (clears a smoker's withdrawal, sickens a non-smoker) | not cleanly: a Vitality Smoker without the vanilla flag is sickened by every cigarette |
| Fear of Blood | Java: panic from own bleeding, stress from blood on the body; Lua: +50 panic in ten medical timed actions, stress from bloody items, no medical check on others | three layers to copy; the Java two approximately |
| Iron Gut | Java: food poisoning chance; Lua: tainted water poison halved | the Lua half exactly, the Java half through the `foodSicknessRise` hook we already run |
| Resilient | Java only: illness resistance | not today; the catchable-illness system will own illness and can read our trait then |
| Night Vision | Java only: darkness rendering | no |
| Handy | Script XPBoosts; Lua: build time, built health, barricade time; Java: BuildAction | the Lua half by wrapping; the levels we already manage |
| Insomniac | Java: IsoPlayer, the sleep AI director; Lua: bed menu x0.5 | the read stays; nothing to clone |

### The approach, revised

The goal is "leave vanilla alone": no redefinitions, no grants, nothing
doubled, and other trait mods free to rewrite a vanilla trait without
breaking ours. Three moves do it, and the clone list is shorter than first
drafted because most of the effects are Java.

1. **Stop redefining. Re-price with a flat delta instead.** The seven
   script blocks go; vanilla's own definitions stand. The price changes
   move into a flat price table beside the age one (the surcharge wrap
   already draws "+N" and "-N" on the row and takes it off Points to Spend;
   it gains a band-independent column): Smoker gives 2 more, Fear of Blood
   1 more, Iron Gut costs 2 more, Resilient 6 more, Cook and Blacksmith 1
   more, Night Vision 2 less. The row shows why ("Vitality: the Knox roll").
   Cook's +1 Small Blade and Blacksmith's +1 Small Blunt are given at spawn
   through the level code Age uses, and shown on the creation screen's
   Major Skills list the way age levels are. The recipe copies are no
   longer needed. The DTEM mirror of the six definitions goes with them;
   DTEM's screen gets the delta the way it gets the age surcharge today.
   Our extensions (the nicotine system, the Knox roll, the infection hazard,
   the faint roll, the food hooks) keep **reading** the vanilla trait.
2. **Fold-ins carry their own effect and exclude the vanilla trait.**
   Steady Hands wraps the transfer and drop actions for the x0.5 itself and
   excludes Dextrous (already does) and All Thumbs; Fast Recovery scales
   wound healing through the heal clocks (number set from vanilla's
   description, noted in `docs/`) and excludes Fast Healer and Slow Healer
   (already does); Deep Sleeper sets the sleep need Wakeful would and wraps
   the bed menu, excludes Wakeful (new; today Wakeful is only hidden), Needs
   More Sleep and Insomniac. `DanTraits_GrantFoldIn` is retired. On load, a
   character whose flag says we granted the twin loses it once; one line in
   What's New. The Iron Stomach to Iron Gut swap stays as the one-time
   migration it is.
3. **Keep the four in-play flips, and say so.** Deaf by headphones, Hard of
   Hearing and Keen Hearing by tinnitus, Short Sighted by the aura, and
   Smoker by the habit all lean on the vanilla trait's Java effect, which is
   the point of flipping it. They stay, documented in `docs/` as the mod's
   remaining vanilla dependencies, each guarded by its mod-data flag so the
   mod only ever removes what it added.

What this drops from the first draft: **no Vitality clones of Fear of
Blood, Resilient or Night Vision** (the user agreed, 2026-10-30: price deltas
on vanilla's own traits). **Smoker is cloned anyway** (the user: "we jacked
the trait value up for our smoker"), the one trait where the sandbox hide
option survives.

### The Smoker clone

- **Vitality Smoker** (`dantraits:smoker`, gives 5, the price our redefinition
  gave vanilla's): the nicotine system as it is today (habit meter,
  withdrawal, lungs, the Strain rows, Straight Edge's exclusion) reads our
  trait. The redefinition of `base:smoker` goes, so vanilla Smoker is back
  at its own -3 with its own Java behaviour.
- **The cigarette problem.** Vanilla's eat code (Java, `RecipeCodeOnEat`)
  clears withdrawal for a character with the vanilla flag and sickens one
  without it. The mod already wraps the eat before and after vanilla
  (`DanTraits_Smoker.lua:326-355`); for a Vitality Smoker the after-hook
  puts the food-sickness level back to what it was before the drag and does
  the clearing itself (the stat is ours to write; the per-minute rescale at
  461-473 already treats NICOTINE_WITHDRAWAL as our carrier, it now owns the
  rise outright instead of rescaling vanilla's). The vanilla "stress without
  a cigarette" is Java too and is lost for a Vitality Smoker; our withdrawal
  system covers it.
- **Sandbox:** *Vanilla Smoker trait*: Hidden (default) / Shown. Shown lists
  both, exclusive both ways; ours is labelled so the two can be told apart.
- **The habit flip** (`becomeSmoker`, the three-weeks-clean removal) grants
  and removes our trait, not vanilla's. A character who takes up smoking in
  play therefore never carries the vanilla flag.
- **Old saves:** a character with vanilla Smoker and the mod's smoker data
  (`nicMeter` or the withdrawal stat above zero) is converted once on load:
  vanilla off, ours on, a line in What's New. One with vanilla Smoker and no
  mod data (made with the mod off) is left alone and treated as a plain
  vanilla smoker; the readers stop accepting `base:smoker` after the
  conversion step has run once.
- **Dynamic Traits:** the adapter's Smoker mirror goes; our trait is a
  normal mod trait to it.
- Tests: `test_smoker.lua` swaps the trait key; a new case for the cigarette
  after-hook and for the conversion.

Side findings from the sweep, to fix in the same step:

- Fold-in grants run at player-ready, after spawn, so vanilla's spawn key
  rings for Dextrous, Iron Gut and Smoker never reach fold-in characters.
  Moot once the grants go.
- Deep Sleeper does not exclude Wakeful in the script (it is hidden instead).
  The exclusion is added.
- With Dynamic Traits active, DTEM hands out Resilient free in play, which
  triggers our Knox roll for nothing (`DanTraits_DTEM.lua:70-72`). With the
  delta approach the roll should key off a Resilient *chosen at creation*
  (mod data set at spawn), not the live flag.
- `HANDY_SKILLS` (`DanTraits_Age.lua:128`) hard-codes vanilla Handy's boost
  list; read it from the trait definition instead so a mod that changes
  Handy does not break the 20s rule.

## Needs and wants

What "alive with needs and wants" means here: each decade has one or two
things it wants every day, shown as a moodle, with a small reward for
meeting it and a small cost for ignoring it. Nothing lethal; texture. The
menu, with a size and my recommendation:

| Decade | Want | Mechanism | Size | Build now? |
|---|---|---|---|---|
| 20s | **Itchy Feet.** Three days without leaving the home cell (Home already knows it) brings a moodle: boredom builds x1.5 and a small mood dip; new ground (a cell never visited) clears it and gives a few hours of mood lift | Home's cell record + a visited-cells set in mod data; a per-hour tick | M | yes |
| 20s | **Late sleeper.** Slow to wake: the first hour after waking has the Drowsy moodle's edge unless there is coffee; sleep debt from rises before 7 counts x1.25; nights are deeper (the x0.8 wakes, built) | Sleep's wake hook and the night score | S | yes |
| 20s | Head rows (panic, anger, habits, episodes) | decided above | M | yes |
| 40s | **Routine, lightly.** Coffee in the morning and a meal at the usual hour each give a touch of mood | eat and drink hooks with a time-of-day record | S | optional |
| 50s | **Creature of Habit.** The same bed, a meal within an hour of yesterday's, a morning drink: each kept gives a sliver of mood; three disrupted days in a row bring the moodle (stress x1.2, sleep score -0.1) until two kept days clear it | the Routine record above, read harder | M | yes |
| 50s | **Feels the cold.** Comfortable temperature a few degrees higher; cold reaches the joints sooner (Arthritis and Old Injury already read weather); a warm bed or the hot water bottle counts for more | the warmth hooks Hot Water Bottle added | S | yes |
| 50s | **Comfort matters more.** A proper bed and a proper chair pay more for the old: stiffness fades x1.2 on a bed in a house, and sitting in a seat you could sleep on rests Bad Knees faster (built) | Age's stiffness pacing reads the bed | S | optional |
| 50s | **Weight.** Harder to lose, easier to gain | would need a calories-to-weight hook the mod does not have | L | park |
| all | **Show the band**: a line on the health panel, the Chronicle's diary voice, Life Story's decade decks | small UI; Chronicle and Life Story are their own projects | S | the panel line yes |

Picked (the user, 2026-10-30): **all seven** (Itchy Feet, Late sleeper,
Routine lightly, Creature of Habit, Feels the cold, Comfort matters more,
the panel line). Weight stays parked.

**One sandbox switch for the whole suite** (the user: toggleable, not
individually). `DanTraits.AgeWants` = On (default) / Off. Off means no want
ticks, no want moodles, no mood or stress effects from any of the six
wants, and Restless does nothing (its tooltip says so). The panel's band
line is display, not a want, and stays on either way. The band effects
(levels, recovery, head rows) are not behind this switch; they are the age
system itself.

**The Guide** (the user: update the new user guide): the `age` page in
`DanTraits_GuideData.lua` is rewritten for 2.0 (the four bands in a line
each, the level cut and the untouched XP rate, the wants and their switch,
the disease traits by band, the lock-outs), and What's New gets an entry.
A `media/ui/Guide/age.png` picture if one is wanted; the page shows it
when the file exists.

## Build order

1. **Decoupling** (approved 2026-10-30; BUILT 2026-10-31, 106/106 tests, deployed; not yet seen in the game). The
   seven redefinitions out and the flat price table in, Cook's and
   Blacksmith's levels at spawn, the DTEM mirror down to the delta; then the
   fold-ins (own effect, exclusive, one-time removal on load); then the
   side findings. `tests/test_dtem.lua` and `test_client.lua` change with it.
2. **Bands** (BUILT 2026-10-31): the 40s to 0, the 20s to 5, the level cut, Green retired, the
   learning rows. Tests pin the Carpenter, Veteran and Fitness Instructor
   examples and that the XPBoostMap is never written.
3. **Head rows** (BUILT 2026-10-31): the five band effects, the two price rows out, the
   `habitGain` / `cravingOnset`, `angerRise`, `mddEpisode`, `schizoChance`
   hooks named in `plans/age-v2.md`.
4. **The rules table** (BUILT 2026-10-31): `DanTraits_AgeRules` replacing the age-only table,
   the script exclusion and the price table; the ticked lock-out rows.
5. **The 20s traits** (BUILT 2026-10-31; Restless's effect lands with step 7): Natural, Hot-Headed, Restless.
6. **Disease traits** (BUILT 2026-10-31; Smoker's Lungs tuning still open): Gout, Essential Tremor, Underactive Thyroid, Hay
   Fever, Carpal Tunnel (five traits, three new bottles: allopurinol,
   colchicine, levothyroxine, plus antihistamines); Smoker's Lungs lands
   with the Smoker clone in step 1 and is tuned here.
7. **Needs and wants** (BUILT 2026-10-31): all seven, behind the one `AgeWants` sandbox switch;
   Restless with them.
8. **Docs** (DONE 2026-10-31; workshop/description.txt untouched, at its 8000-character limit): `docs/age.md`, README, the Guide's age page
   (rewritten, the user asked) and What's New,
   CHANGELOG, `workshop/changelog.txt`. Deploy after each step; the user
   plays as we go.

## More immersion (2026-10-30; the user picked the same day)

The user asked what else would make age feel real. **Picked:** scars that
remember, Burnout by band, age spoken. **Not:** the starting kit by decade.
Not raised again, so parked: tastes by decade, the rest day, Fitness +1,
chronotype. Grouped by how much they add for what they cost.

### A body with a history

- **Scars that remember.** Today only Old Injury (a 50s trait) carries an
  old wound. Make it dynamic for the 40s and 50s: a deep wound, fracture or
  bite-scratch that heals in play leaves a mark on that part (mod data,
  shown on the health panel as "old break" or "scar"). In cold or damp
  weather it aches and stiffens a little, the way Old Injury does; the 50s
  keep every one, the 40s only fractures, the 20s heal clean. "Keeps the
  receipts" made literal, and it grows out of a run instead of a creation
  pick. Reads: WoundCare and Brittle know when a wound or fracture closes;
  Old Injury's weather read exists. Size M.
- **Burnout by band.** Burnout does not read the band today (only Age and
  Reading do). The 50s should burn out a little faster and recover slower
  (x1.15 / x0.85), the 20s the reverse, and the 50s' hardening should come
  slower. Cheap, and it is the one everyday system age skips. Size S.
- **A rest day.** After a hard day (Burnout's own measure), the 50s wake
  with Sore and a stiffness floor that lasts to noon unless they slept in a
  bed in a house; the 20s wake clear. Size S on top of the stiffness pacing.

### The prime, made visible

- **Fitness +1 in the 20s.** Age never touches Fitness and Strength levels
  (decided 2026-10-05, to keep a 50s Fitness Instructor off Fitness 10). A
  single Fitness level for the 20s is the body in its prime in one number
  players can see on the creation screen, and it costs the band nothing
  else. Against: it is a level, and the band's whole identity so far is
  rates. Size S. Mirror: none for the 50s; the x0.8 training is enough.
- **Chronotype.** The 50s wake with the light: fatigue clears by about six
  and lying in gives nothing after; the 20s sleep late and come to slowly.
  Sleep's wake hook and the night score carry it (the Late Sleeper want
  above is the 20s half). Note the clash with the price table: Early Riser
  costs *more* in the 50s today (a habit kept into middle age is worth
  more) while a built-in early wake would make it worth *less*. One or the
  other. Size S.

### Appetite and comfort

- **Tastes by decade.** The cooking overhaul grades every meal. The 20s get
  a little more mood from junk and lose less of the Vitality penalty for
  it; the 50s get a stronger Good Meal afterglow from a proper dish and
  less from junk. Age in what you want to eat. Size S.
- **Warmth.** The Feels the Cold want above; the hot water bottle and a warm
  bed worth more to the old.

### Age in the world

- **A starting kit by decade**, riding on A Really Bad Day's kit code: the
  50s start with reading glasses and a memento (the Collection system
  already classes mementos; a photo that gives a touch of mood when looked
  at), the 40s a wedding ring or a watch, the 20s a backpack and a bad
  habit's supplies. Small, and it says who the person is in the first
  minute. Size S.
- **Age spoken.** The health panel line (above); the Chronicle's diary voice
  knows the band; the Notes tab's first-morning line ("Your knees remind you
  you are 52"); the Vitality moodle descriptions mention age where it is the
  cause ("stiff, and not as young as you were"). Text only. Size S.
- **Life Story** (`plans/life-story-design.md`): one chapter card per decade
  lived, latents and personality drawn from them. The deepest immersion
  lever there is, and it needs the bands settled first, which 2.0 does. Its
  own project, after this pass.

### Deliberately not

- Hearing and eyesight rows for the 50s as band effects (Hard of Hearing and
  Reading Glasses already exist as picks; a band row would double them and
  make the 50s, which felt right, worse).
- Grey hair or an appearance nudge at creation: the player's own choice.
- Ageing during play, exact ages, a 60s band: as decided in `plans/age-v2.md`.

## Diseases that could be traits (2026-10-30; the user picked the same day)

The user asked which other conditions could be reflected accurately. The
mod already has MS, Heart Condition, Asthma, Hemophilia, Type 1 and Type 2,
Anaemic, Arthritis, Brittle, Migraine, Epilepsy, Tinnitus, Spiraling,
Schizophrenia, Sensory Issues, ADHD, Gluten, Lactose and the age-only Bad
Back, Bad Knees, Old Injury and Reading Glasses. Candidates below are chosen
for three things: common enough to be believable, a real mechanic the mod's
systems can already carry, and something to *do* about it in the game. Age
skew makes most of them natural 40s or 50s lock-outs for the 20s, which
answers the "other traits to lock out" thread with new negatives rather than
by fencing vanilla ones. One caution: the 50s felt right in play, so the
older bands get these as *choices*, never as band effects.

| Trait | Who | What it does in play | Builds on | Points | Size |
|---|---|---|---|---|---|
| **Gout** (IN, gives 8) | 40s, 50s; men more | Rich meals (the meat-heavy and fatty Vitality grades), alcohol and dehydration raise a urate meter; past the line a flare in one foot: two to four days of severe pain, slow walking, no running. Daily allopurinol holds the meter down; NSAIDs shorten a flare; water and plain food lower it. | meal grades, alcohol tracking, thirst, part pain (Bad Knees' legs), the daily-meds system | gives 8 (the user) | M |
| **High Blood Pressure** (OUT) | 40s, 50s | Salt-heavy and junk meals, stress, panic, caffeine and smoking raise it; it adds to Heart Condition's strain if present and gives a plain character a small heart-attack risk of its own after weeks untreated. Daily medication (a new amlodipine or the beta blockers we have) brings it down; there is no moodle until it is high, which is the point: a First Aid 6+ health-panel line shows the number. | Heart's strain, Blood panel, meds, stress and panic pipelines | gives 3 | M |
| **Essential Tremor** (IN, with a pill) | 50s mostly; any age | Hands shake: aiming x0.85, stitching and fine work fail more often, slower careful reading. Caffeine, stress, cold and fatigue worsen it; a drink steadies it for an hour (true, and a trap for Dependent builds); propranolol (the beta blockers) damps it. Not with Steady Hands. | Steady Hands' success rolls, aiming hooks, the Diabetes and Dependent shake code | gives 3 | S |
| **Sleep Apnoea** (OUT) | 40s, 50s; Overweight and Obese worse | Nights score worse (x0.8), wakes x1.5, and daytime drowsiness returns mid-afternoon; sleeping on your side is not in the game, but weight loss below Overweight halves it and alcohol before bed doubles it. No machine in Knox Country. | Sleep's night score and wake hooks, weight, alcohol | gives 4 | S |
| **Smoker's Lungs (COPD)** (IN, inside the Smoker clone) | every Smoker; worse by band | Endurance cap like Asthma's tier two, a cough that makes noise in cold air and on exertion (draws zombies, as Sensory's sound rows do), worse every week still smoking; quitting stops the slide, never reverses it; an inhaler eases a bad spell. | Asthma's cap, Smoker's meter, sound events | gives 5 | M |
| **Underactive Thyroid** (IN) | 40s, 50s; women more | Fatigue builds x1.15, feels the cold (comfort temperature a few degrees up), weight gain easier, mood a little low. One daily pill (levothyroxine, new item in medicine cabinets) removes all of it; running out brings it back over a week. The purest "find your medication" condition. | fatigue, warmth, weight, the daily-meds and reminder system | gives 3 | S |
| **Hay Fever** (IN, cheap) | any age | Spring and summer (pollen by month and weather: dry, windy days worst, rain clears the air): sneezing fits that make noise and interrupt actions, itchy eyes (sight a touch shorter), poor sleep with windows open. Antihistamines fix it and make you drowsy, the non-drowsy kind is rarer. Seasonal, so it is a different game in July than in January. | weather and season reads, sound events, Sleep, meds | gives 2 | M |
| **Bad Teeth** (OUT) | any age; worse old | Sugar and sweets raise a decay meter; past the line a toothache: head pain for a day, hard food hurts to eat, sleep suffers. Painkillers and clove oil (new) mask it; an abscess (a second line) brings fever and needs antibiotics; with First Aid 4 and pliers you can pull the tooth (one less future ache). No dentists after the fall. | eat hooks, part pain, fever owner, antibiotics, the First Aid gating | gives 3 | M |
| **Bad Wrists (RSI)** (OUT; became Carpal Tunnel below) | 40s, 50s; trades | Long stretches of the same work (chopping, sawing, crafting, washing) build wrist pain and a fine-work penalty; rest and a splint ease it; alternating tasks resets the run. The mirror of Bad Back for the hands. | the work-minute counters Bad Back and Laundry already keep, part pain | gives 2 | S |
| **Nerve Damage** (OUT) | not a trait: a progression | Type 2 left untreated for weeks numbs the feet: foot wounds are not felt (no pain, no moodle, found only on the health panel), tripping on rough ground more often. Reversible early, permanent late. Makes "untreated diabetes" a story rather than a number. | Diabetes' untreated-days counter, wound events | none | M |

Thought about and left out for now: menopause (women, 40s to 50s: warmth
swings, broken sleep, mood) is accurate and would use systems the mod has,
but the mod has no sex-specific traits anywhere and that is a design
decision of its own; glaucoma (a narrowed vision cone is possible through the
vision effects Migraine already flips) is rarer and mostly invisible until
late; irritable bowel and prostate trouble need a bathroom the game does not
have; chronic fatigue overlaps MS and Arthritis; Parkinson's begins too late
for a 50s band and Essential Tremor covers the tremor players would see.

The user picked (2026-10-30): **Gout**, **Essential Tremor**, **Underactive
Thyroid**, **Hay Fever** and **Carpal Tunnel** (in place of Bad Wrists) as
traits; **Smoker's Lungs** rolled into the Smoker clone rather than a trait
of its own; **Bad Teeth**, **Nerve Damage**, **High Blood Pressure** and
**Sleep Apnoea** out (the last two on a second ask).

### The five, as picked

**Gout, gives 8.** The user: make a flare hard to deal with and price it
for that. The urate meter rises with meat-heavy and fatty meals (the
Vitality grades), beer and spirits, dehydration (any thirst moodle) and,
accurately, crash dieting (a day of Cut or starving). Past the line a flare
starts in one foot and runs three to five days untreated:

- severe pain in the foot (part pain at the Bad Knees ceiling, so sleep
  suffers and the pain moodle sits at severe);
- walking slowed as a sprained ankle slows it, no running or sprinting, slow
  through windows and over fences;
- the foot cannot bear a boot's weight: shoes off or the pain climbs a step
  (a nudge, not a rule the game enforces);
- a second flare within a month has a one-in-four chance of taking the other
  foot or a knee as well.

Daily allopurinol (new bottle, medicine cabinets and pharmacies, uncommon)
lowers the meter and is the only real control; colchicine (new, rare) cuts a
flare to a day; vanilla painkillers ease the pain one step; water and plain
meals lower the meter slowly. A careless diet flares every ten to fourteen
days, a careful one every month or more, allopurinol kept up nearly never.
A 50s trait that gives 8 and is survivable only by eating and drinking like
a patient: that is the point of it.

**Essential Tremor, gives 3, with a pill.** The user asked which pill. The
real first-line drug is propranolol, which the game already has as **Beta
Blockers** (`Base.PillsBeta`, used by Heart Condition and for panic): one
steadies the hands for about six hours, with its normal panic effect on top.
The second-line drug is **primidone**, which would be a new daily-medication
bottle like levothyroxine. Recommendation: Beta Blockers only. It is
accurate, it is a vanilla item, and a tremor character now competes with
their own panic management for the same bottle, which is a real trade-off
without a new item. Primidone can be added later if Beta Blockers prove too
scarce for a daily user. Alcohol's one-hour steadying stays.

**Smoker's Lungs, inside the Smoker clone.** The user: roll it into Smoker;
it will need tweaking. `dantraits:smoker` gains a lung meter (pack-years):
set at creation by band (20s 0, 30s a little, 40s a third, 50s over half),
raised by every cigarette, never lowered. Thresholds bring Asthma's
endurance cap tier one then tier two, and a cough in cold air and on
exertion that makes a sound zombies hear. Quitting freezes the meter; an
inhaler eases a bad spell. So a 20s smoker is a clean smoker who will ruin
their lungs over a long game, and a 50s smoker starts with the cough. Price:
the clone gives 5; the 50s may need a surcharge row (gives 6 or 7) because
they start damaged. Open for tweaking once played: the starting damage by
band, the thresholds, the cough's sound radius, how fast a heavy smoker
climbs.

**Underactive Thyroid, gives 3.** As in the table. Levothyroxine is a new
daily-medication bottle on the reminder system; running out brings the
fatigue, the cold and the weight gain back over a week.

**Hay Fever, gives 2.** The user: cheap. Two is the floor any trait in the
mod or vanilla sits at, and Hay Fever earns no more: antihistamines (new,
common in bathrooms) fix it for the day at the cost of drowsiness, and from
autumn to spring it does nothing. Sneezing fits still make noise, which is
why it is not free. If 2 still feels too dear in play, the rules table can
price it 1.

**Carpal Tunnel, gives 2** (replaces Bad Wrists; the user: annoying, not
crippling). Any age, more in the 40s and 50s. Long runs of repetitive hand
work (crafting, sawing, chopping, washing, sewing, mechanics) build a wrist
meter; past the line a numb, tingling spell:

- fine actions slower (transfer, stitching, mechanics, electrical: the mirror
  of Dextrous, x1.2 time);
- a small chance that a fine-work roll fails outright and has to be redone;
- when the meter is high it wakes you once in the night with numb hands
  (one extra wake, sleep score a touch down);
- never a weapon penalty and never pain beyond mild: it should nag, not stop
  you.

Rest drains the meter; a vanilla Splint worn while sleeping drains it twice
as fast; alternating kinds of work resets the run so it never builds. Size S.

### Not picked

Bad Teeth, Nerve Damage, High Blood Pressure and Sleep Apnoea (the user:
no to all four). High Blood Pressure stays in this table as the natural
candidate if the Blood panel ever wants a second number to show.

## Open

- The fold-in effect numbers (Fast Recovery's healing, Deep Sleeper's sleep need) from vanilla's descriptions.
- Whether the 30s need their +1 back after the free 40s is played.
- Smoker's Lungs tuning after play (starting damage by band, thresholds, cough radius, 50s surcharge).
- Build start: the user said "do them" on the evening of 2026-10-30 after the
  review session went idle; to confirm whether that is the whole pass (decoupling
  first) or the wants suite ahead of the rest.

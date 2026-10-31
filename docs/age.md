# Age

How the age system works and what it does to every trait it touches. This
describes the code as built for Age 2.0 on 2026-10-31 (`DanTraits_Age.lua`,
`DanTraits_AgeRules.lua`, `DanTraits_AgeTraits.lua`, `DanTraits_AgeWants.lua`,
`DanTraits_VanillaPrices.lua`). The design is in `plans/age-2.0.md`; the
first version's in `plans/age-v2.md`.

## The short version

Every character is in their 20s, 30s, 40s or 50s. The young start barely
trained and learn fast, and their bodies forgive everything; the old arrive
knowing their trade and recover slowly. The 30s are the game as it is. After
a long play-test of the first version, the 40s felt like the best pick and
the 20s too generous, so 2.0 made the 40s free and gave the 20s a level cut
to pay for its learning.

| | In Their 20s | In Their 30s | In Their 40s | In Their 50s |
|---|---|---|---|---|
| Points | costs 5 | free | free | gives 6 |
| Where it shows at creation | positive traits | positive traits (0 points) | positive traits (0 points) | negative traits |
| Main skill | -2 | +0 | +2 | +3 |
| Each other profession skill | -1 | +0 | +1 | +2 |
| The profession's XP rate | kept | kept | kept | kept |

Points are fixed by the trait script (`Cost = 5 / 0 / 0 / -6`; the 20s cost 6
and the 40s gave 2 until 2.0). Age changes what other traits cost in a few
cases (the price rows below) and what they do in many.

## Picking an age

- The four Age traits exclude each other, so a character has exactly one.
- The age comes first. With Age on, the creation screen offers nothing but
  the four Age traits until one is chosen; then the rest of the lists appear.
  Next is greyed until then, with the reason as its tooltip and written on
  the screen. Random picks an age first and rolls the rest after. A saved
  preset loads as it was and is gated after. In Their 30s and In Their 40s
  sit in the positive list at 0 points (vanilla lists only a cost above or
  below zero, so the mod puts them there itself; This Is Your Life's folder
  gets them the same way).
- The sandbox option *Default Age* (20 to 59, rounds down to the decade) is
  the band given to a character who reaches the world with no Age trait: a
  save from before Age had traits, or a character made without the creation
  screen. If that is the 40s or 50s, they are given that trait without its
  points. It never stands in at creation.
- A save from before this version gets the default band's trait the first
  time it loads. Skills are not touched.

## Profession levels

A new character's levels in their profession's **main skill** (the skill the
profession boosts most) move by age: two off in the 20s, two on in the 40s,
three in the 50s. Every **other skill the profession boosts** moves with it:
one off in the 20s, one on in the 40s, two in the 50s. Nothing goes under 0,
and the profession's XP rate is never touched.

| Example | 20s | 30s | 40s | 50s |
|---|---|---|---|---|
| Carpenter (Carpentry 4; Carving, Short Blunt, Masonry, Maintenance 1) | Carpentry 2; the others 0 | as vanilla | Carpentry 6; the others 2 | Carpentry 7; the others 3 |
| Doctor (First Aid 3, Short Blade 1) | First Aid 1, Short Blade 0 | as vanilla | First Aid 5, Short Blade 2 | First Aid 6, Short Blade 3 |
| Veteran (Aiming 2, Reloading 2) | both 0 | as vanilla | both 4 | both 5 |
| Fitness Instructor (Sprinting 2; Fitness, Strength) | Sprinting 0; Fitness and Strength kept | as vanilla | Sprinting 4 | Sprinting 5 |
| Unemployed | nothing to lose | nothing | Maintenance 2 | Maintenance 3 |

- **Why the rate survives.** The profession's experience bonus (+75%,
  +100%, +125%) is the character's XPBoostMap, filled from the profession and
  trait scripts at creation. Age adds or takes levels by adding or taking
  experience quietly (`DanTraits_AgeXpAdjust`) and never touches that map. A
  20s Carpenter at Carpentry 1 still trains it at +125%.
- **Ties.** If several skills share the top boost, each one gets the full
  change. A 50s Veteran starts with +3 Aiming and +3 Reloading; a 20s one
  with 0 and 0.
- **Fitness and Strength never get age's levels**, as a main skill or
  otherwise. Age is years of practice, not a better body.
- **Unemployed** has no main skill, so the main-skill levels go into
  Maintenance in the 40s and 50s. The 20s have nothing to lose.
- Levels stop at 10 and at 0. They are levels, not an XP rate.
- They are applied once, when the character is created.

The creation screen shows them as you pick. In the Major Skills list, a skill
that age adds to has "(+N age)" after its name and its extra bars in blue; a
skill age takes from has "(-N age)" and the lost bars greyed. The XP rate on
the right counts only the game's own levels. The screen and the spawn code
call the same function (`DanTraits_AgeLevels`), so they cannot disagree.
Keen Cook's +1 Short Blade and Blacksmith Knowledge's +1 Short Blunt are
drawn the same way as "(+1 trait)" (`DanTraits_VanillaPrices.lua`).

## The body, every day

These apply to every character in that band, whatever traits they have.
A multiplier above 1 on a recovery row means faster.

| Effect | 20s | 30s | 40s | 50s |
|---|---|---|---|---|
| Endurance recovery | x1.25 | x1 | x0.92 | x0.85 |
| Fitness and Strength experience | x1.5 | x1 | x0.9 | x0.8 |
| Scratches and cuts heal | x1.5 | x1 | x0.9 | x0.8 |
| An unstitched deep wound heals | x1.5 | x1 | x0.9 | x0.8 |
| Stiffness fades | x1.5 | x1 | x0.85 | x0.7 |
| Night wakes counted in the sleep score | x0.8 | x1 | x1.15 | x1.3 |
| Red cells rebuild after blood loss | x1.15 | x1 | x0.8 | x0.65 |
| A concussion heals | x1.2 | x1 | x0.75 | x0.6 |
| Hangover severity | x0.85 | x1 | x1.25 | x1.5 |
| Hunger builds | x1.15 | x1 | x0.95 | x0.9 |
| Caffeine, drink, food sickness and daily or course medication clear | x1.2 | x1 | x0.9 | x0.8 |

## Learning

| Experience on... | 20s | 30s | 40s | 50s |
|---|---|---|---|---|
| Every skill (Fitness and Strength aside) | x1.15 | x1 | x1 | x1 |
| Any skill under level 3 | x1.3 | x1 | x1 | x0.9 |
| The weapon skills, Aiming and Reloading | x1.15 | x1 | x1 | x1 |
| The profession's own skills | x1 | x1 | x1.1 | x1.15 |

The factors multiply (`DanTraits_XpFactor`, one product per gain), with each
other and with the experience traits: a 20s character on a fresh weapon
skill trains it at 1.15 x 1.3 x 1.15 = x1.72 until level 3, then x1.32;
Quick Study (x1.4 under 5) and Natural (x1.25 on the weapon skills) stack on
top. The combat check is Burnout's, by the perk's parent, so a mod's weapon
skill counts.

## The head (the 20s)

The body forgives; the head does not. Every row is the 20s only, read by the
system named through a hook Age answers.

| Effect | 20s | Hook | Read by |
|---|---|---|---|
| Panic builds | x1.15 | `panicRise` (the stat delta pipeline) | the game's panic rise; Seen It All's 50s x0.8 is the mirror |
| The smoking and drinking habit meters build, and their daily caps | x1.3 | `habitGain` | Smoker, Alcoholic |
| Cravings come sooner: a Smoker's withdrawal builds, an Alcoholic's and a Caffeine Dependent's dry hours are divided | x1.25 (24/48/72 dry hours become 19.2/38.4/57.6; coffee's 12 become 9.6) | `cravingOnset` | Smoker, Alcoholic, Caffeine Dependent |
| The irritability a craving holds | x1.25 | `angerFloor` | Smoker, Alcoholic (Hot-Headed's x1.5 reads the same hook) |
| Spiraling's episode chance | x1.3 | `mddEpisode` | Major Depressive Disorder |
| Schizophrenia's episode chance | x1.25 | `schizoChance` | Hallucinations |

With the habits harsher young, Smoker and Alcoholic are full price in the
20s (they gave a point fewer until 2.0).

## Age pricing and the traits an age cannot take: one table

`DanTraits_AgeRules` (in `DanTraits_AgeRules.lua`) has one row per trait that
age treats specially: the bands that may take it and what it costs more or
fewer in a band. The creation screen hides a trait the chosen band cannot
take and takes it back off when the age changes (with its points), on the
vanilla screen and This Is Your Life's alike; a gated trait's description
says so ("Age: 40s, 50s"). A price shows beside the trait's cost in red
(dearer) or green (cheaper) and comes off Points to Spend. A positive number
on a trait that gives points means it gives that many fewer. Existing
characters are not affected; the table is read at creation only.

| Trait | 20s | 30s | 40s | 50s |
|---|---|---|---|---|
| Strong, Athletic | 0 | 0 | +2 | +4 |
| Stout | 0 | 0 | +1 | +2 |
| Fit | -1 | 0 | +1 | +2 |
| Fast Learner | -1 | 0 | 0 | +1 |
| Slow Learner (gives) | +1 | 0 | 0 | +1 |
| Hearty Appetite (gives) | +1 | 0 | 0 | -1 |
| Multiple Sclerosis, Heart Condition (give) | +3 | 0 | 0 | 0 |
| Asthma, Hemophilia (give) | +2 | 0 | 0 | 0 |
| Anaemic (gives) | +1 | 0 | 0 | 0 |
| Gym Regular, Meal Prepper, Early Riser | 0 | 0 | +1 | +2 |
| Arthritis, Brittle, Type 2 Diabetes, Gout, Underactive Thyroid, Hard of Hearing | not offered | | | |
| Quick Study, Bottomless Pit, Natural, Hot-Headed, Restless | | not offered | not offered | not offered |
| Reading Glasses, Bad Back, Bad Knees, Old Hand, Delicate Stomach | not offered | not offered | | |
| Pace Yourself, Settled | not offered | not offered | | not offered |
| Old Injury, Set in Their Ways, Seen It All, Cast Iron, Old Bones Know Rain | not offered | not offered | not offered | |

The conditions the 20s band itself softens (MS, Heart Condition, Asthma,
Hemophilia, Anaemic) give fewer points young rather than being locked out:
the young do have them, and the band's endurance, healing and blood factors
already take part of the sting out. Heart Condition stays available at full
price in every band. The 50s are locked out of nothing: Athletic at 55 is
allowed, just dearer. Hard of Hearing, Brittle and Type 2 (which had a +1
row) joined the 20s lock-outs in 2.0.

## Traits only one age can take

| Trait | Age | Points | What it does |
|---|---|---|---|
| Quick Study | 20s | costs 4 | Any skill below level 5 gains experience x1.4 (on top of the band's x1.3 under 3) |
| Natural | 20s | costs 3 | The weapon skills, Aiming and Reloading gain experience x1.25 (on top of the band's x1.15) |
| Hot-Headed | 20s | gives 3 | The irritability a craving holds is x1.5 (the `angerFloor` hook) and anger falls x0.7 (the `angerFall` hook, applied in `DanTraits_Anger.lua`) |
| Restless | 20s | gives 3 | The Itchy Feet want (below) builds twice as fast and its dip and lift are doubled. Not with Homebody. Does nothing with Age Wants off |
| Bottomless Pit | 20s | gives 6 | Hunger builds x1.3 on top of the band's x1.15; from the Hungry moodle's second level, 0.1 unhappiness a minute awake (0.2 at the third). Not with Light Eater |
| Pace Yourself | 40s | costs 4 | A tenth of the endurance a swing or a sprint spends comes straight back |
| Settled | 40s | gives 4 | A night anywhere but a bed in a house scores 0.2 worse, and so does the first night in any new bed |
| Reading Glasses | 40s, 50s | gives 2 | Starts with a pair. Without reading or prescription glasses on, reading takes x1.5 as long and needs a properly lit room |
| Bad Back | 40s, 50s | gives 8 | The Heavy Load moodle builds lower-back pain and stiff legs; a sore back under load can be thrown out (four hours of severe pain, no running); a trained core eases it |
| Bad Knees | 40s, 50s | gives 5 | Running, sprinting, climbing and stomping build knee pain; walking never rests them, sitting rests them twice as fast, a seat you could sleep on three times (x1.2 more in the 50s with Age Wants on) |
| Old Hand | 40s, 50s | costs 4 | Every skill the occupation boosts gains experience x1.25 |
| Delicate Stomach | 40s, 50s | gives 2 | A junk meal brings food sickness; so does a drink on an empty stomach. Not with Iron Gut |
| Old Injury | 50s | gives 3 | One arm or leg always a little stiff, stiffer and sore in the cold and damp. Not with Arthritis |
| Set in Their Ways | 50s | gives 4 | Skills the occupation does not boost gain experience x0.85 |
| Seen It All | 50s | costs 3 | Panic builds x0.8; Fear of Blood faints half as often; Germaphobe's filth stress half. Not with Cowardly |
| Cast Iron | 50s | costs 2 | Medication side effects half as often; the overdose line a pill higher |
| Old Bones Know Rain | 50s | costs 1 | Once a day from 6 AM: tomorrow's storm, heavy rain, blizzard or freezing night is announced today |

Green (the 20s' old flaw: every occupation skill a level lower) is retired
in 2.0: the band takes the levels itself. A save with it has the trait taken
off and nothing put back; the levels it took are not returned.

## What each age wants (Age Wants)

Each decade wants one or two things every day, shown as a moodle, with a
small reward for meeting it and a small cost for ignoring it. The whole
suite sits behind one sandbox switch, **Age Wants** (on). Off: nothing
ticks, no want moodle shows, no mood or stress moves, and Restless does
nothing. The bands' own effects are not behind it.

| Age | Want | What happens |
|---|---|---|
| 20s | **Itchy Feet** | The map cell (256 tiles square) is noted each minute. Three days in one and the want builds over a day: boredom climbs faster (x1.5 at full), the mood dips a little each waking minute. Stepping into a cell never visited clears it, takes 10 unhappiness and 0.05 stress off at once, and says so. Moodle Itchy Feet / Stir Crazy |
| 20s | **Late sleeper** | A night (not a nap) that ends before 7: tiredness is held at the Drowsy edge for an hour unless half a mug of caffeine is in the system, and the night's sleep debt counts x1.25 |
| 40s | **Routine, lightly** | A coffee or tea before 11, and a meal (0.2 hunger or more) within an hour of yesterday's main meal, each cheer you a touch (2 unhappiness off), once a day |
| 50s | **Creature of Habit** | The same bed as last night, a meal at yesterday's hour and a morning drink each give a sliver of mood as they happen. The day is scored when the night is: kept when two of the three held. Three broken days in a row bring Out of Routine (a mood sink each waking minute, the night 0.1 worse) until two kept days clear it |
| 50s | **Feels the cold** | The joints' weather reading (Arthritis, Old Injury) is x1.2 below 15 C; the mood sinks a little each waking minute out in air under 10 C; a cold night scores 0.05 worse unless the hot water bottle was in the bed |
| 50s | **Comfort matters more** | Stiffness fades x1.2 asleep in a bed in a house; a seat you could sleep on rests Bad Knees x1.2 |
| all | **The band on the health panel** | An Age line names the band and the want that is up (not behind the switch: it is display) |

## What age does to other traits

| Trait | 20s | 40s | 50s |
|---|---|---|---|
| Handy (vanilla) | none of its starting levels (read from Handy's definition, so a mod that changes Handy is followed; shown greyed, taken back at spawn); those skills train x1.5 instead | +1 Carpentry at the start | +1 Carpentry at the start |
| Arthritis | cannot be taken | the cold and damp reach the joints x1.3 as fast | x1.6 |
| Brittle | cannot be taken | fracture chance x1.25 | x1.5 |
| Heart Condition | strain builds x0.8 | x1.25 | x1.5 |
| Diabetes Type 2 | cannot be taken | resistance +0.10 | +0.20 |
| Gout, Underactive Thyroid | cannot be taken | | |
| Smoker (the mod's) | starts with nearly clean lungs (0.05) | a third of the lungs gone (0.33) | over half (0.55) |
| Gym Regular | regularity starts at 65, not 50 | | |
| Alcoholic, Hollow Legs, anyone who drinks | hangovers x0.85 | x1.25 | x1.5 |
| Anaemic, Fast Recovery | red cells rebuild x1.15 as fast | x0.8 | x0.65 |
| Thick Skull | a concussion heals x1.2 as fast | x0.75 | x0.6 |

## Sandbox options

| Option | Default | What it does |
|---|---|---|
| Age | on | Off: the Age traits are hidden at creation, nothing is granted, and every character counts as in their 30s |
| Default Age | 30 | The age given to a character who has no Age trait at spawn (20 to 59) |
| Age Wants | on | The wants suite above, as one switch |
| Profession Levels (20s / 30s / 40s / 50s) | -2 / 0 / 2 / 3 | The main-skill levels per band, -3 to 5 for the 20s and 0 to 5 for the rest. Negative takes levels off (and one off each other profession skill). At 0 the band gets no levels at all. A save made under the old 20s default keeps its stored 0 until changed |

## What changed in 2.0 (2026-10-31)

- The 40s cost 0 (gave 2); the 20s cost 5 (6) and start two levels down on
  the main skill, one on the others, with the XP rate kept.
- The 20s learn faster across the board (every skill x1.15, under 3 x1.3,
  weapon skills x1.15) and the head rows above are new.
- Green is retired; Natural, Hot-Headed and Restless take the 20s' slot.
- One rules table for prices and lock-outs; Hard of Hearing, Brittle and
  Type 2 join Arthritis out of the 20s; the Smoker and Alcoholic 20s price
  rows are gone.
- Five conditions, mostly of later life: Gout, Essential Tremor, Underactive
  Thyroid, Hay Fever, Carpal Tunnel (the README has each).
- The wants suite behind Age Wants.
- The mod no longer redefines any vanilla trait; the re-pricing is a flat
  delta beside the cost (`docs/` and the README: "vanilla, re-priced"), the
  fold-in traits carry their own effects, and Smoker is the mod's own trait.

## For modders

- `DanTraits_AgeBand(player)` returns 20, 30, 40 or 50 (30 with age off).
- `DanTraits_AgeLevels(boosts, band, handy, bonus)` returns `{ perk = levels }`,
  negative for levels off.
- `DanTraits_AgeRules` is the one table; `DanTraits_AgeRuleFor(kind)`,
  `DanTraits_AgeRuleBands(kind)`, `DanTraits_AgeSurcharge(band, kind)` and
  `DanTraits_AgePrices()` read it. `DanTraits_AgeOnly` (registry key to bands)
  is built from it. Add a row to price or gate any trait.
- `DanTraits_TraitExtra(band, kind)` (`DanTraits_VanillaPrices.lua`) is the
  age surcharge plus the flat delta on a re-priced vanilla trait; the
  creation screens draw and charge that.
- Every number is in the `AGE` table at the top of `DanTraits_Age.lua`.
- The effects go through the mod's value hooks (`enduranceRegen`, `woundHeal`,
  `healPace`, `nightWakes`, `bloodCellRebuild`, `concussionHeal`,
  `hangoverSeverity`, `diaResistance`, `brittleChance`, `arthritisJoint`,
  `gymRegularity`, `panicRise`, `habitGain`, `cravingOnset`, `angerFloor`,
  `mddEpisode`, `schizoChance`), the `AddXP` event, and one per-minute step
  (`DanTraits_Every`, order 23.5). The wants use `boredomRise`, `nightScored`,
  `nightQuality`, `stiffFade`, `kneeRest` and their own minute at order 50.
- Mod data: `ageApplied`, `ageBand`, `ageParts`; the wants' `aw` prefix.
- `DanTraits_AgeProfessionSkills(player)` returns the profession's main skills
  and its other boosted skills; `DanTraits_AgeXpAdjust(player, perk, extra)`
  adds or takes experience quietly; `DanTraits_AgeIsCombatPerk(perk)` is the
  combat check.
- Tests: `tests/test_age.lua`, `test_agetraits.lua`, `test_headrows.lua`,
  `test_agewants.lua`, `test_vanillaprices.lua`, `test_diseases.lua`, and
  the creation screen in `test_client.lua`.

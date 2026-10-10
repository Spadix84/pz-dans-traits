# Age

How the age system works and what it does to every trait it touches. This
describes the code as built on 2026-10-05 (`DanTraits_Age.lua`, branch
`age-v2`). The design history is in `plans/age-v2.md`.

## The short version

Every character is in their 20s, 30s, 40s or 50s. Younger bodies recover and
train faster; older characters start with more skill and recover slower. The
30s are the game as it is.

| | In Their 20s | In Their 30s | In Their 40s | In Their 50s |
|---|---|---|---|---|
| Points | costs 6 | free | gives 2 | gives 6 |
| Where it shows at creation | positive traits | positive traits (0 points) | negative traits | negative traits |
| Main skill | +0 | +0 | +2 | +3 |
| Each other profession skill | +0 | +0 | +1 | +2 |

Points are fixed by the trait script (`Cost = 6 / 0 / -2 / -6`; the 50s gave 4 until 2026-10-07). With one
exception (the body traits, below), age never changes what another trait
costs; it changes what the trait does.

## Picking an age

- The four Age traits exclude each other, so a character has exactly one.
- The age comes first. With Age on, the creation screen offers nothing but
  the four Age traits until one is chosen; then the rest of the lists appear.
  Next is greyed until then, with the reason as its tooltip and written on
  the screen. Random picks an age first and rolls the rest after. A saved
  preset loads as it was and is gated after, so one with no age shows its
  traits but cannot start until an age is added. In Their 30s sits in the
  positive list at 0 points (vanilla lists only a cost above or below zero,
  so the mod puts it there itself).
- The sandbox option *Default Age* (20 to 59, rounds down to the decade) is
  the band given to a character who reaches the world with no Age trait: a
  save from before Age had traits, or a character made without the creation
  screen. If that is the 40s or 50s, they are given that trait without its
  points. It no longer stands in at creation.
- A save from before this version gets the default band's trait the first
  time it loads. Skills are not touched.

## Profession levels

A new character gets extra levels in their profession's **main skill**: the
skill the profession boosts most. Every **other skill the profession boosts**
gets one level in the 40s and two in the 50s: years on the job teach the
whole trade, not only the speciality.

| Example | 30s | 40s | 50s |
|---|---|---|---|
| Carpenter | nothing | Carpentry +2; Carving, Short Blunt, Masonry, Maintenance +1 | Carpentry +3; the other four +2 |
| Doctor | nothing | First Aid +2; Short Blade +1 | First Aid +3; Short Blade +2 |
| Electrician | nothing | Electrical +2 | Electrical +3 |
| Veteran | nothing | both +2 | both +3 |

- **Ties.** If several skills share the top boost, each one gets the full
  levels. A 50s Veteran starts with +3 Aiming and +3 Reloading. The widest
  ties in vanilla are Burglar (Nimble, Sneaking, Lightfooted) and Park Ranger
  (five skills), so those two gain the most from age.
- **Fitness and Strength never get age's levels**, as a main skill or
  otherwise. Age is years of practice, not a better body. A Fitness
  Instructor's main skill is Sprinting; a Fire Officer's are Sprinting and Axe.
- **Unemployed** has no main skill, so the main-skill levels go into
  Maintenance. There are no other skills to add to.
- Levels stop at 10. They are levels, not an XP rate: the skill does not
  train faster afterwards.
- They are applied once, when the character is created.

The creation screen shows them as you pick. In the Major Skills list, a skill
that age adds to has "(+N age)" after its name and its extra bars in blue.
The XP rate on the right (+75%, +100%, +125%) counts only the game's own
levels, because age does not change the rate. The screen and the spawn code
call the same function (`DanTraits_AgeLevels`), so they cannot disagree.

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
| Any skill under level 3 trains | x1.2 | x1 | x1 | x0.9 |
| The profession's own skills train | x1 | x1 | x1.1 | x1.15 |
| Hunger builds | x1.15 | x1 | x0.95 | x0.9 |
| Caffeine, drink, food sickness and daily or course medication clear | x1.2 | x1 | x0.9 | x0.8 |

The last four are the mind and the metabolism (2026-10-07): in your 20s you
are learning and the brain is a sponge, the body burns through everything
fast; in your 50s the trade you know keeps coming, new skills do not, and
everything lingers, good and bad. The band's learning factors multiply with
each other; Quick Study, Old Hand and Set in Their Ways run in a handler of
their own, so their factor adds to the band's rather than multiplying (20s
and Quick Study on a skill under 3: x1.2 + x1.4 - 1 = x1.6). The clearance
factor divides a hangover's hours and a daily or course drug's half-life (a
dose holds a fifth longer in the 50s; rescue drugs such as diazepam and
painkillers keep their own), scales caffeine's decay, and stretches or
hurries whatever drunkenness and food sickness fell by each minute.

How each one works:

- **Endurance.** The game's own recovery is scaled as it happens. It stacks
  with everything else that scales recovery (Vitality, blood loss, a
  hangover): the factors multiply.
- **Experience.** Each time Fitness or Strength gains experience, the
  difference is added on top (20s) or taken back (40s, 50s). A slower learner
  never drops below the level they already hold. It stacks with Vitality's
  Thriving bonus.
- **Scratches and cuts.** Once a minute the mod looks at how far each wound's
  healing clock moved and stretches or hurries that step. Bandages, dirt and
  everything else the game counts still apply first. An infected wound that
  the Infection system is holding open stays held.
- **Deep wounds.** Only the unstitched kind, which the Wound Care system
  already slows; age scales that. Stitches, burns and fractures are not
  affected by age.
- **Stiffness.** The same once-a-minute pacing, on the stiffness exercise and
  hard work leave in each body part. A 50-year-old is still sore the morning
  after a long chop when a 25-year-old is not.
- **Night wakes.** Vitality scores each night, and every wake after the first
  costs a little. Age scales the count before it is scored.

## Age pricing

A trait can cost more or fewer points in a band. The trait itself is
unchanged; the difference shows beside its cost on the creation screen (red
for dearer, green for cheaper) and comes off Points to Spend. The body costs
more to keep with age; learning is cheap young and dear old; a hearty
appetite is natural young. The conditions the 20s band itself softens
(through its endurance, healing, blood, strain, resistance and clearance
factors) give fewer points young (2026-10-10), so a 20s character cannot
stack them at full price while the band quietly takes the sting out. (Light Eater had a row until 2026-10-07; it was
taken out as not worth the attention.) A positive number on
a trait that gives points means it gives that many fewer.

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
| Type 2, Anaemic, Smoker, Alcoholic (give) | +1 | 0 | 0 | 0 |

Existing characters are not affected; the table is read on the creation
screen only (`DanTraits_AgeSurcharge`, `DanTraits_AgePrices`).

## Traits only one age can take

Fifteen traits are offered only to the right age: eight from the first
build, and from 2026-10-07 one perk and one flaw of each band's own, so the
40s stop being a lighter 50s and the 50s have perks at all. (The 20s perk,
Bounces Back, was folded into Thick Skull the same day and is open to any
age; a save that has it gets Thick Skull instead.) Pick the age
first; change it and a trait the new age cannot have comes back off, with
its points. With the Age option off none of them is offered.

| Trait | Age | Points | What it does |
|---|---|---|---|
| Green | 20s | gives 4 | Every skill the occupation boosts starts one level lower (not under 0). The skills still train at the occupation's faster rate: experience gain is unchanged (the description says so). Shown greyed on the creation screen |
| Quick Study | 20s | costs 4 | Any skill below level 5 gains experience x1.4 (on top of the band's x1.2 under level 3) |
| Reading Glasses | 40s, 50s | gives 2 | Starts with a pair of reading glasses. Without reading or prescription glasses on, reading takes x1.5 as long and needs a properly lit room (sunglasses do not count) |
| Bad Back | 40s, 50s | gives 4 | The Heavy Load moodle builds lower-back pain, faster the heavier the load (about two hours at the second level to the worst of it). It eases over about four hours with the load off, twice as fast asleep. Not with Strong |
| Bad Knees | 40s, 50s | gives 3 | Running, sprinting (four times as fast), each fence, wall or window climbed (0.08) and each stomp (0.02) build pain in both lower legs. Walking never rests them; standing still eases the load over about three hours, sitting (or sleeping) twice as fast, a seat you could sleep on (a sofa, an armchair) three times. |
| Old Hand | 40s, 50s | costs 4 | Every skill the occupation boosts gains experience x1.25 (Maintenance for the Unemployed); until 2026-10-07 only the main skill |
| Old Injury | 50s | gives 3 | One arm or leg, picked at the start and announced once, always carries a little stiffness; in the cold and damp it stiffens further and hurts. Not with Arthritis |
| Set in Their Ways | 50s | gives 2 | Skills the occupation does not boost gain experience x0.85. Fitness and Strength are left to age |
| Bottomless Pit | 20s | gives 6 | Hunger builds x1.3 on top of the band's x1.15; from the Hungry moodle's second level, 0.1 unhappiness a minute awake (0.2 at the third). Not with Light Eater |
| Pace Yourself | 40s | costs 2 | A tenth of the endurance a swing or a sprint spends comes straight back |
| Settled | 40s | gives 4 | A night anywhere but a bed in a house (a bed object on a square with a room) scores 0.2 worse, and so does the first night in any new bed |
| Delicate Stomach | 40s, 50s | gives 2 | A junk meal (the Vitality grade) brings 15 food sickness for a whole portion; a drink with hunger over half brings 10. Not with Iron Gut |
| Seen It All | 50s | costs 3 | Panic builds x0.8 (the game's own rise, through the stat delta pipeline); Fear of Blood faints half as often; Germaphobe's filth stress half. Not with Cowardly |
| Cast Iron | 50s | costs 2 | Medication side effects half as often; every drug's overdose line one pill higher |
| Old Bones Know Rain | 50s | costs 1 | Once a day from 6 AM: a storm, tropical storm, heavy rain or blizzard tomorrow, or a night below freezing, is announced today |

Notes:

- The experience traits stack with each other and with age's own Fitness and
  Strength factor. A slower learner never drops below a level already held.
- Bad Back, Bad Knees and Old Injury put their pain on the body part, so it
  shows on the health panel and painkillers work on it.
- Old Injury reads the weather the way Arthritis does. Its stiffness is a
  floor; age's slower fading applies to anything above it.
- The age check happens on the creation screen only. A character who has one
  of these traits keeps it.
- Each has its own icon, as do the four Age traits (a disc with the decade
  on it). The creation screen's description lists everything a trait does.

## What age does to other traits

| Trait | 20s | 40s | 50s |
|---|---|---|---|
| Handy (vanilla) | cannot be taken | +1 Carpentry at the start | +1 Carpentry at the start |
| Arthritis | cannot be taken | the cold and damp reach the joints x1.3 as fast, so flares come sooner | x1.6 |
| Brittle | no change | fracture chance x1.25 | x1.5 |
| Heart Condition | strain builds x0.8 | x1.25 | x1.5 |
| Diabetes Type 2 | insulin resistance -0.05 | +0.10 | +0.20 |
| Gym Regular | regularity starts at 65, not 50 | no change | no change |
| Alcoholic, Hollow Legs, anyone who drinks | hangovers x0.85 | x1.25 | x1.5 |
| Anaemic, Fast Recovery | red cells rebuild x1.15 as fast | x0.8 | x0.65 |
| Thick Skull | a concussion heals x1.2 as fast | x0.75 | x0.6 |

Notes on the less obvious rows:

- **Handy and Arthritis** are the only lock-outs among the older traits, and
  only for the 20s. (Until 2026-10-05 this only worked if Arthritis or Handy
  was picked first: the game checks an exclusion from one side. The creation
  screen now checks both sides, for every trait.) The
  50s are locked out of nothing: Athletic or Gym Regular at 55 is allowed,
  just harder to keep up.
- **Blood, concussion and hangover** rows are not trait effects as such. They
  are the everyday rates from the table above, listed here because those
  traits live on the same rates. The factors multiply: a 50s character with
  Fast Recovery rebuilds blood at x1.5 x 0.65.
- **Arthritis and Multiple Sclerosis** hold stiffness at a floor of their
  own. Age cannot push stiffness under that floor; it only changes how fast
  the stiffness above it fades.
- **Anything that scales endurance recovery** (Smoker's lungs, Brittle
  Asthma, Anaemic, Multiple Sclerosis in the heat, chest pain) multiplies
  with age's factor.
- **Heart Condition** used to look at the Age traits directly. It now reads
  the band, so the *Default Age* option and the Age switch count for it too.

## Sandbox options

| Option | Default | What it does |
|---|---|---|
| Age | on | Off: the Age traits are hidden at creation, nothing is granted, and every character counts as in their 30s |
| Default Age | 30 | The age given to a character who has no Age trait at spawn: an old save, or one made without the creation screen (20 to 59) |
| Profession Levels (20s / 30s / 40s / 50s) | 0 / 0 / 2 / 3 | The main-skill levels per band, 0 to 5. At 0 the band gets no levels at all, the other skills included |

There is no separate switch for the everyday effects.

## What changed from the first version

- A fourth band, the 50s.
- The everyday effects (endurance, experience, wound healing, stiffness,
  night wakes) are new. Characters already in their 20s or 40s feel them from
  the first minute after the update.
- Prices swapped sides. Before, In Their 20s gave 2 points and In Their 40s
  cost 1. Now the 20s cost 6 and the 40s give 2, because youth is the
  advantage in play and age is the trade for skill.
- The 40s get two main-skill levels, not one, and the profession's other
  skills get one level each in the 40s and two in the 50s.
- Fitness and Strength no longer get age's levels, and the
  Unemployed get Maintenance.
- Everyone carries an Age trait.
- The creation screen shows age's levels.
- Strong, Athletic, Stout and Fit cost more in the 40s and 50s.
- Eight traits that only one age can take.

## For modders

- `DanTraits_AgeBand(player)` returns 20, 30, 40 or 50 (30 with age off).
- `DanTraits_AgeLevels(boosts, band, handy, bonus, green)` returns `{ perk = levels }`.
- `DanTraits_AgeSurcharge(band, traitType)` returns the extra points a trait
  costs in that band. The creation screen applies it by wrapping vanilla's
  `CharacterCreationProfession:PointToSpend`, which is worked out on demand.
- Every number is in the `AGE` table at the top of `DanTraits_Age.lua`.
- The effects go through the mod's value hooks (`enduranceRegen`, `woundHeal`,
  `nightWakes`, `bloodCellRebuild`, `concussionHeal`, `hangoverSeverity`,
  `diaResistance`, `brittleChance`, `arthritisJoint`, `gymRegularity`), the
  `AddXP` event, and one per-minute step (`DanTraits_Every`, order 23.5).
- Mod data: `ageApplied`, `ageBand` (set at creation), `ageParts` (the last
  scratch, cut and stiffness values per body part).
- `DanTraits_AgeOnly` (in `DanTraits_AgeTraits.lua`) maps a trait's registry
  key to the bands that may take it; add a row to make any trait age-only.
- `DanTraits_AgeProfessionSkills(player)` returns the profession's main skills
  and its other boosted skills; `DanTraits_AgeXpAdjust(player, perk, extra)`
  adds or takes experience quietly.
- Tests: `tests/test_age.lua`, `tests/test_agetraits.lua`, and the creation
  screen in `tests/test_client.lua`.

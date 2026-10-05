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
| Points | costs 6 | free | gives 2 | gives 4 |
| Where it shows at creation | positive traits | hidden (the default) | negative traits | negative traits |
| Main skill | +0 | +1 | +2 | +3 |
| Each other profession skill | +0 | +0 | +1 | +1 |

Points are fixed by the trait script (`Cost = 6 / 0 / -2 / -4`). Age never
changes what another trait costs; it changes what the trait does.

## Picking an age

- The four Age traits exclude each other, so a character has exactly one.
- In Their 30s is never offered at creation. Pick no Age trait and it is
  granted when the character spawns, so the trait list always shows an age.
- The sandbox option *Default Age* (20 to 59, rounds down to the decade) sets
  which band a character with no pick gets. If that is the 40s or 50s, they
  are given that trait without its points.
- A save from before this version gets the default band's trait the first
  time it loads. Skills are not touched.

## Profession levels

A new character gets extra levels in their profession's **main skill**: the
skill the profession boosts most. In the 40s and 50s, every **other skill the
profession boosts** gets one level as well: years on the job teach the whole
trade, not only the speciality.

| Example | 30s | 40s | 50s |
|---|---|---|---|
| Carpenter | Carpentry +1 | Carpentry +2; Carving, Short Blunt, Masonry, Maintenance +1 | Carpentry +3; the other four +1 |
| Doctor | First Aid +1 | First Aid +2; Short Blade +1 | First Aid +3; Short Blade +1 |
| Electrician | Electrical +1 | Electrical +2 | Electrical +3 |
| Veteran | Aiming, Reloading +1 | both +2 | both +3 |

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

## What age does to other traits

| Trait | 20s | 40s | 50s |
|---|---|---|---|
| Handy (vanilla) | cannot be taken | +1 Carpentry at the start | +1 Carpentry at the start |
| Arthritis | cannot be taken | the cold and damp reach the joints x1.3 as fast, so flares come sooner | x1.6 |
| Brittle | no change | fracture chance x1.25 | x1.5 |
| Heart Condition | chest pain chance x0.8 | x1.25 | x1.5 |
| Diabetes Type 2 | insulin resistance -0.05 | +0.10 | +0.20 |
| Gym Regular | regularity starts at 65, not 50 | no change | no change |
| Alcoholic, Hollow Legs, anyone who drinks | hangovers x0.85 | x1.25 | x1.5 |
| Anaemic, Fast Recovery | red cells rebuild x1.15 as fast | x0.8 | x0.65 |
| Thick Skull | a concussion heals x1.2 as fast | x0.75 | x0.6 |

Notes on the less obvious rows:

- **Handy and Arthritis** are the only lock-outs, and only for the 20s. The
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
| Default Age | 30 | The age of a character who picks no Age trait (20 to 59) |
| Profession Levels (20s / 30s / 40s / 50s) | 0 / 1 / 2 / 3 | The main-skill levels per band, 0 to 5. At 0 the band gets no levels at all, the other skills included |

There is no separate switch for the everyday effects.

## What changed from the first version

- A fourth band, the 50s.
- The everyday effects (endurance, experience, wound healing, stiffness,
  night wakes) are new. Characters already in their 20s or 40s feel them from
  the first minute after the update.
- Prices swapped sides. Before, In Their 20s gave 2 points and In Their 40s
  cost 1. Now the 20s cost 6 and the 40s give 2, because youth is the
  advantage in play and age is the trade for skill.
- The 40s get two main-skill levels, not one, and the 40s and 50s get a
  level in each of the profession's other skills.
- Fitness and Strength no longer get age's levels, and the
  Unemployed get Maintenance.
- Everyone carries an Age trait.
- The creation screen shows age's levels.

## For modders

- `DanTraits_AgeBand(player)` returns 20, 30, 40 or 50 (30 with age off).
- `DanTraits_AgeLevels(boosts, band, handy, bonus)` returns `{ perk = levels }`.
- Every number is in the `AGE` table at the top of `DanTraits_Age.lua`.
- The effects go through the mod's value hooks (`enduranceRegen`, `woundHeal`,
  `nightWakes`, `bloodCellRebuild`, `concussionHeal`, `hangoverSeverity`,
  `diaResistance`, `brittleChance`, `arthritisJoint`, `gymRegularity`), the
  `AddXP` event, and one per-minute step (`DanTraits_Every`, order 23.5).
- Mod data: `ageApplied`, `ageBand` (set at creation), `ageParts` (the last
  scratch, cut and stiffness values per body part).
- Tests: `tests/test_age.lua`, and the creation screen in `tests/test_client.lua`.

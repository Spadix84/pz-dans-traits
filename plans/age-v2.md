# Age, version 2

Design note, drafted 2026-10-03, decided and BUILT 2026-10-05 on branch
`age-v2` (unplayed). How the built system works is in `docs/age.md`; this note
is the reasoning. Where the two differ, the code and `docs/age.md` are right.

A note on signs: the costs in this note are the player's points (-3 = the
player pays 3). The trait script uses the game's sign, the other way round:
`Cost = 6` for the 20s, `-2` for the 40s, `-4` for the 50s. The first
version's script had the 20s at `Cost = -2` (it gave 2 points) and the 40s at
`Cost = 1`, the opposite of what "Why" below assumes; the build follows the
pricing reasoning here.

## Why

Age today (`DanTraits_Age.lua`, built 2026-09-28) has three problems:

1. **The 20s are a bad deal.** Against the 30s you pay 2 points and lose a
   profession level, and get gentler red cells, concussions and hangovers:
   things that only matter if you bleed, get knocked out or drink.
2. **The 40s are a good deal.** A point back, the same level as the 30s, and
   costs that only bite if you get hurt or drink.
3. **You never feel your age.** A 22-year-old and a 45-year-old recover from a
   fight, a run or a cut the same way. Age only shows when something rare
   happens.

And two gaps: age stops at the 40s, and after creation you cannot see your
age anywhere unless you picked a trait.

## The idea

Age moves onto the everyday systems: endurance, healing, training, stiffness,
sleep. Younger recovers and trains faster; older knows more and recovers
slower. A fourth band, the 50s, has the most skill and the most baggage.
Every band is a real trade, so the choice is "who is this person", not "which
one is free points".

## The bands

Four bands, mutually exclusive. The 30s stay the vanilla baseline and the
default.

| Band | Trait | Cost | Profession levels | In one line |
|---|---|---|---|---|
| 20s | In Their 20s | -3 (was -2) | +0 | Bounces back, learns the body fast, knows little |
| 30s | In Their 30s (granted, not picked) | 0 | +1 | The game as it is |
| 40s | In Their 40s | +2 (was +1) | +2 (was +1) | Knows the trade, slower to recover |
| 50s | In Their 50s (new) | +4 | +3 | An expert with a body that keeps the receipts |

**Pricing reasoning.** The old rule still holds: age may make a negative
harsher or lock it out, and may make something better only where the Age trait
pays for it. Against the 30s:

- The 20s give up one level and gain five everyday bonuses (below). Vanilla
  Fast Healer alone costs 6; the 20s get a slice of it plus training and
  endurance. -3 with the lost level feels right.
- The 40s gain a level and take five everyday penalties. A level in the main
  skill is worth about 2 points; the penalties about 4. Net +2.
- The 50s gain two levels and take the penalties at about twice the 40s rate,
  plus the harsher versions of everything. Net +4.

## Where the levels go

- **Main skill.** The skill the profession boosts most. On a tie, every tied
  skill gets the band's full levels (as today): a 50s Veteran gets +3 Aiming
  and +3 Reloading. Tied professions get more out of age; accepted.
- **Unemployed.** No main skill, so the levels go into Maintenance (years of
  fixing your own things): +0 / +1 / +2 / +3.
- **Cap.** Level 10, as today.
- One function returns `{ perk = levels }` for a profession, band and trait
  set; the spawn code and the creation screen both call it.

## Everyday effects (new)

| Effect | 20s | 30s | 40s | 50s | How |
|---|---|---|---|---|---|
| Endurance recovery | x1.25 | 1 | x0.92 | x0.85 | `enduranceRegen` hook (exists, Vitality uses it) |
| Fitness and Strength XP | x1.50 | 1 | x0.90 | x0.80 | `Events.AddXP`, the pattern Vitality's Thriving bonus uses |
| Wound healing (scratches, cuts, deep wounds) | x1.50 | 1 | x0.90 | x0.80 | Per-minute heal clocks, the pattern Infection uses to hold them; `woundHeal` (exists) for unstitched deep wounds |
| Stiffness after exertion fades | x1.50 | 1 | x0.85 | x0.70 | New: per-minute check on each part's stiffness, undo part of a fall (or add to it) |
| Night wakes counted in the sleep score | x0.80 | 1 | x1.15 | x1.30 | `nightWakes` hook (exists) |

The 20s numbers in the first four rows are the user's (2026-10-05); the
drafts were x1.10, x1.20, x1.15 and x1.20.

The stiffness row is the one players will notice first: the day after a big
fight or a long chop, a 50-year-old is still sore when a 25-year-old is not.

## Existing effects, extended to the 50s

| Effect | 20s | 30s | 40s | 50s |
|---|---|---|---|---|
| Red cells rebuild | x1.15 | 1 | x0.80 | x0.65 |
| Concussion heals | x1.20 | 1 | x0.75 | x0.60 |
| Hangover severity | x0.85 | 1 | x1.25 | x1.50 |
| Type 2 resistance | -0.05 | 0 | +0.10 | +0.20 |
| Brittle fracture chance | 1 | 1 | x1.25 | x1.50 |
| Arthritis joint factor (flares sooner) | cannot take | 1 | x1.30 | x1.60 |
| Gym Regular starting regularity | 65 | 50 | 50 | 50 |
| Handy | cannot take | | +1 Carpentry | +1 Carpentry |

## Exclusivity

All four Age traits exclude each other, declared both ways in
`scripts/DanTraits.txt`; the vanilla trait screen enforces it, no Lua needed.
In Their 20s keeps excluding Handy and Arthritis. The 50s exclude nothing:
they get harsher, not locked out (see open questions).

## Seeing your age

**In game.** Every character ends up with an Age trait in their trait list.
Picking nothing at creation gives the default band's trait at spawn (In Their
30s unless the sandbox says otherwise). In Their 30s is cost 0 and hidden from
the creation lists, using the hiding wrap `DanTraits_Client.lua` already has
for the Age traits. If the sandbox default is the 40s or 50s, a character who
picks nothing gets that trait for free, as today.

**At creation.** The Major Skills list does refresh live: vanilla
`CharacterCreationProfession:checkXPBoost` rebuilds it on every trait
add/remove and profession change. It just builds it from the trait scripts'
XPBoosts, and age adds levels in Lua at spawn. So:

1. Wrap `checkXPBoost`: let vanilla build the list, then add the band's levels
   to the profession's main skill(s), or Maintenance for the Unemployed (and
   Handy's Carpentry in the 40s/50s).
   The levels come from the same function the spawn code uses, so the screen
   and the game cannot disagree.
2. Draw age levels as a second colour of bar, with a one-line key under the
   Major Skills header ("blue: age"). The XP rate column (+75/100/125%) is
   computed from the vanilla levels only, because age gives levels, not a
   faster rate.
3. Set `doDrawItem` again inside the wrap, so the custom draw is in place even
   if the screen was built before the mod loaded.
4. Each Age trait's description names what it does in a line or two, with the
   level count from the sandbox setting.

## Sandbox

| Option | Change |
|---|---|
| AgeEnabled | unchanged |
| AgeDefault | max 49 → 59 |
| AgeBonus20s / 30s / 40s | defaults 0 / 1 / 2 (40s was 1) |
| AgeBonus50s | new, default 3 |

No switch for the everyday effects on their own: AgeEnabled covers age as a
whole.

## Old saves

- Profession levels are applied once at creation (`d.ageApplied`), so nobody's
  skills change.
- Existing 20s and 40s characters start feeling the everyday effects the
  first time the update runs. Say so in the changelog.
- A character with no Age trait gets the default band's trait the first time
  the mod runs (their band does not change; it is only made visible).

## Build steps

1. **Spike (first, small).** Check in game that `AddXP` with a negative amount
   lowers XP cleanly in 42.21 (needed for the 40s/50s training rate). If not,
   fall back to a running XP debt taken off the next gains.
2. `DanTraits_Age.lua`: replace the per-constant locals with one table per
   band, add the 50s, keep `DanTraits_AgeBand` as the public read.
3. Script: `age30s` (hidden), `age50s`, exclusions both ways. Translations.
4. Everyday hooks: endurance, XP, wound clocks, stiffness, night wakes.
5. Grant the default trait at spawn and for old saves.
6. Creation screen: the `checkXPBoost` wrap and the two-colour bars.
7. Sandbox options, README Age section, changelog, checklist section.

Each step is one commit on the release branch, tests and deploy after each.

## Tests

Offline (`tests/test_age.lua`, extending the existing one):

- Every band's multiplier reaches every hook, and age off returns nil
  everywhere.
- Profession levels per band, capped at 10, tied main skills all get them,
  Unemployed gets them in Maintenance.
- The default trait is granted once, not over a picked trait, and old saves
  get it without a skill change.
- The creation wrap's level maths matches the spawn code for each band (same
  function, tested once).

In game (checklist, ids `age2-*`):

- The four traits exclude each other in both directions.
- Picking each band changes the blue bars at once; the XP rate column does
  not move.
- Spawned levels match what the screen showed.
- A 50s character is still stiff the morning after a long chop; a 20s one is
  not.
- Training XP for Fitness differs between a 20s and a 50s on the same workout.
- An old save loads with no skill change and shows an Age trait.

## Decided (2026-10-05)

1. **Prices.** -3 / 0 / +2 / +4, levels 0 / 1 / 2 / 3.
2. **Tied main skills.** Every tied skill gets the full levels.
3. **Unemployed.** The levels go into a fixed skill: Maintenance.
4. **A visible 30s trait.** Yes: granted at spawn, cost 0, hidden at creation.

5. **Lock-outs for the 50s.** None.
6. **20s numbers.** Endurance x1.25, Fitness and Strength XP x1.5, healing
   x1.5, stiffness x1.5.

7. **The 20s cost 6** (the user, later on 2026-10-05, after the stronger
   numbers): -6 / 0 / +2 / +4.
8. **Side skills.** The user asked for the age levels to reach every skill in
   the occupation, and picked: the main skill keeps 0 / 1 / 2 / 3, and every
   other skill the profession boosts gets +1 in the 40s and, after seeing how
   close the 40s and 50s came out, +2 in the 50s. (Considered:
   sides one step behind the main skill; every skill the full levels; a flat
   +1 from the 30s.)

9. **Body traits cost more with age** (the user's idea, 2026-10-05): Strong
   and Athletic +2 in the 40s and +4 in the 50s, Stout and Fit +1 and +2.
   Reason: the 50s train Fitness and Strength at x0.8, so buying them at
   creation was the best deal for the oldest. Built as a wrap of vanilla's
   `PointToSpend` (computed on demand, like its negative-trait penalty), not
   as an auto-added surcharge trait: nothing to fall out of step with presets
   or the random button. Considered and not built: fewer levels with age,
   lock-outs, an upkeep system.

10. **Age-only traits** (the user picked all eight I drafted, 2026-10-05, and
    wants one more for the 20s, not yet named): Green, Quick Study (20s);
    Reading Glasses, Bad Back, Bad Knees, Old Hand (40s, 50s); Old Injury, Set
    in Their Ways (50s). No existing trait was made age-limited. The age check
    is Lua on the creation screen (`DanTraits_AgeOnly`), because the 30s have
    no trait there.

## What the build did differently

- **Fitness and Strength are never the main skill.** Otherwise a 50s Fitness
  Instructor starts at Fitness 10. Their main skill is Sprinting. Not asked
  for; one condition in `mainSkills` if it should go.
- **No "blue: age" key line** under the Major Skills header. Each row that age
  adds to says "(+N age)" after the skill name instead, and has its bars in
  blue.
- **Trait descriptions are fixed text** with the default level counts; they do
  not follow the sandbox setting.
- **The negative-XP spike was settled from vanilla code**: the debug panel's
  "lower perk" button calls `AddXP(perk, negative, false, false, false,
  false)`. The take-back also stops at the held level's threshold.
- **Stitches, burns and fractures** are not scaled by age; scratches, cuts and
  unstitched deep wounds are.
- **Heart Condition** reads the band (it read the traits), and has a 50s
  factor of x1.5.

## Open questions

1. **Wide ties.** Park Ranger boosts five skills equally, so a 50s Park
   Ranger starts with +3 in all five. Burglar has three.
2. **Age-exclusive traits** (a trait only one band can take): possible with
   the script's exclusions for "not in the 20s" style rules; "only in the
   50s" needs the hidden 30s handled in Lua, since a character who picks no
   age has no trait on the creation screen.

## The 20s, rethought (2026-10-07; BUILT the same day, see "What the second build did")

The eight age-only traits proved the idea; the 20s came out thin (Green and
Quick Study, both skill numbers, nothing about the body or the person). The
user's frame: in your 20s you are learning, the brain is a sponge and you
are not set in your ways; physically you are in your prime; your metabolism
runs higher. Three themes, each on its own layer, so each can be priced on
its own.

### Three dials

1. **The band's own effects and price** (the `AGE[20]` row). The identity.
2. **Age pricing of other traits** (`AGE_BODY` grown into a general table:
   trait -> points more or fewer, per band). "Natural at that age" without
   touching what the trait does. Already built for Strong, Athletic, Stout
   and Fit in the 40s and 50s; negative entries make a trait cheaper.
3. **Band-only traits.** The flavour. Each band should carry at least one
   perk and one flaw of its own, and each should be felt in play.

### Spongey brain (learning)

| Layer | Change |
|---|---|
| Band | Every skill under level 3 trains x1.2. The first levels of anything come quickly because it is all new. Fitness and Strength keep their x1.5 on top. |
| Pricing | Fast Learner costs 1 less in the 20s, 1 more in the 50s. Slow Learner gives 1 less in the 20s. |
| Trait | **Quick Study** becomes the strong version: x1.4 on skills under level 5, still 4 points. The band got its old job. |
| Mirror | Set in Their Ways (50s) is already the other end. |

Mechanism: the XP hook Quick Study uses, with the band read from the Age
trait; a cap at level 3 (band) or 5 (trait) on the perk's level before the
gain.

### Physical prime

| Layer | Change |
|---|---|
| Band | As built: endurance x1.25, Fitness and Strength XP x1.5, healing x1.5, stiffness x1.5, night wakes x0.8, cells x1.15, concussion x1.2, hangover x0.85. |
| Pricing | Fit and Athletic cost 1 less in the 20s (the mirror of the 40s and 50s surcharge). Strong and Stout unchanged: muscle is work at any age. |
| Trait | **Bounces Back** (costs 3): faints, knockouts and shock half as long, a concussion clearing x1.5, the sumatriptan day-after half as long. |

Mechanism: a `passOutMinutes` hook in DanTraits_Faint.lua (new), the
existing `concussionHeal` hook, and the trip-after timer in Migraine.

### Higher metabolism

The one theme with a built-in cost, which is what makes the band priceable.

| Layer | Change |
|---|---|
| Band | Hunger builds x1.15. Alcohol, caffeine, food sickness and every medication clear a fifth faster (x1.2 on the clearance). You eat more and burn through everything faster, good and bad: a 20s character on beta blockers doses more often. |
| Pricing | Hearty Appetite gives 1 less in the 20s (you are halfway there). Light Eater costs 1 more. |
| Trait, perk | **Iron Stomach** (costs 2): rotten and raw food half as sickening, a hangover's nausea gone sooner. |
| Trait, flaw | **Bottomless Pit** (gives 3): hunger x1.3 on top of the band, and the Hungry moodle bites harder (its mood and strength cost x1.5). |

Mechanism: hunger through the stat delta pipeline (a `hungerRate` hook, new,
on the minute step); `caffeineClearance` and `hangoverHours` exist;
medication needs a `medHalfLife` hook in DanTraits_Meds.lua (new); food
sickness a `sickClear` hook (new) where the game's own decay is read.

### Point math

The 20s cost 6 now, for the body alone. Learning adds value, metabolism
takes some back. Proposed: **the 20s cost 7**; revisit after play. Each new
band trait is priced like its nearest vanilla cousin: Bounces Back against
Fast Healer (costs 4), Iron Stomach against Iron Gut (costs 3, vanilla's is
food poisoning only), Bottomless Pit against Hearty Appetite (gives 4).

### The pricing table, in one place

| Trait | 20s | 30s | 40s | 50s |
|---|---|---|---|---|
| Strong, Athletic | 0 | 0 | +2 | +4 (built) |
| Stout, Fit | -1 (Fit only) | 0 | +1 | +2 (built) |
| Fast Learner | -1 | 0 | 0 | +1 |
| Slow Learner (gives) | -1 | 0 | 0 | 0 |
| Hearty Appetite (gives) | -1 | 0 | 0 | 0 |
| Light Eater | +1 | 0 | 0 | 0 |

A "gives 1 less" is written as a surcharge on a negative-cost trait: the
same sign convention as the script (positive takes points).

### What this does not do

- It does not make the 20s strictly better. The metabolism half and the
  missing profession levels are the price, and both have to stay felt.
- It does not touch weight. B42's calories and weight model is the game's
  own; the band changes how fast hunger builds, not how the body stores it.
  (Open: should a faster metabolism also mean weight comes off faster?)

### Open

1. The 40s and 50s next, by the same frame: experience and judgement, a
   body that keeps the receipts, a slower metabolism (hunger x0.9, slower
   clearance, which makes a dose last longer: a real perk for the old).
2. Whether the band's under-3 learning bonus should show on the creation
   screen's XP rate column (it is a rate, not a level).
3. Bottomless Pit's "Hungry moodle bites harder": vanilla's hunger effects
   are in Java; the mod can add its own on top (unhappiness, a strength
   factor), not scale the game's.

### Build order, when it is wanted

1. The pricing table (grow `AGE_BODY` and `DanTraits_AgeSurcharge`; the
   creation screen already draws "+N at this age", add "-N at this age" in
   green). Smallest, and it changes nothing in play.
2. The band's learning effect, and Quick Study's rework.
3. The metabolism band effect with its hooks.
4. Bounces Back, Iron Stomach, Bottomless Pit.
5. The 20s price to 7. Play.

## The 40s and 50s, by the same frame (2026-10-07; BUILT the same day)

The same three themes, turned round: experience and judgement in place of
the sponge; a body that keeps the receipts in place of the prime; a
metabolism that has slowed, which costs in one place and pays in another.
The same three dials. What is already built stays; this adds the layers the
20s got.

### Experience and judgement (learning)

| Layer | 40s | 50s |
|---|---|---|
| Band | Skills the profession boosts train x1.1 (the trade you know keeps coming); skills under level 3 train at the plain rate (nothing new comes easily). | Profession skills x1.15; skills under level 3 train x0.9. |
| Pricing | Fast Learner as it is. | Fast Learner costs 1 more; Slow Learner gives 1 less (it is natural now). |
| Trait, perk | **Old Hand** (as built, 40s and 50s): the main skill x1.25. | **Seen It All** (50s only, costs 3): panic builds x0.6, Fear of Blood faints half as often, the stress of filth and corpses half. Judgement, not nerve. |
| Trait, flaw | | **Set in Their Ways** (as built): skills outside the occupation x0.85. |

Mechanism: the same XP hook as the 20s, reading the band and whether the
perk is a profession boost (`professionBoosts`, already in the age file).
Seen It All reads into the panic floor code Blood already uses, Hemophobia's
faint roll and Germaphobe's stress rate: three hooks, two of them new
(`panicRate`, `filthStress`); the faint roll has `concussionChance`-style
hooks to copy.

### A body that keeps the receipts (physical)

| Layer | 40s | 50s |
|---|---|---|
| Band | As built: endurance x0.92, Fitness and Strength XP x0.9, healing x0.9, stiffness x0.85, wakes x1.15, cells x0.8, concussion x0.75, hangover x1.25, Type 2 +0.1, heart x1.25, Brittle x1.25, Arthritis x1.3. | As built, one step harsher on each. |
| Pricing | Strong and Athletic +2, Stout and Fit +1 (built). | +4 and +2 (built). |
| Trait, perk | **Pace Yourself** (40s only, costs 2): swings and sprinting spend a tenth less endurance. You do not waste effort any more. | **Old Bones Know Rain** (50s only, costs 1): the weather in the joints is felt a day early: a notice when a storm or cold snap is forecast (the storm-forecast code Migraine already has). Flavour, cheap, and only an old body has it. |
| Trait, flaw | **Settled** (40s only, gives 2): a night anywhere but a bed in a house scores a tier worse; the first night in a new bed too. Moving base costs sleep. | **Reading Glasses, Bad Back, Bad Knees** (as built, shared with the 40s); **Old Injury** (as built). |

Mechanism: Pace Yourself through a new `enduranceSpend` hook where Anger
already adds swing cost; Settled through `nightQuality`, which exists, with
the bed's square read at sleep.

### A slower metabolism

The 20s pay here; the 40s and 50s are paid here. A dose lasts longer, a
meal goes further, and the cost is that everything bad lingers too.

| Layer | 40s | 50s |
|---|---|---|
| Band | Hunger x0.95. Alcohol, caffeine, food sickness and medication clear x0.9 (a dose lasts a tenth longer; so does a hangover, which the band already makes x1.25). | Hunger x0.9. Clearance x0.8: a daily pill holds a fifth longer, a bottle lasts a fifth longer, and the shakes, the nausea and the drink take a fifth longer to leave. |
| Pricing | | Hearty Appetite gives 1 more (unnatural now); Light Eater costs 1 less. |
| Trait, perk | | **Cast Iron** (50s only, costs 2): side effects of medication half as often, and an overdose's threshold one pill higher. Decades of pills. |
| Trait, flaw | **Delicate Stomach** (40s and 50s, gives 2): a junk or greasy meal (the Vitality grade the mod already gives every meal) brings mild food sickness; strong drink on an empty stomach too. | the same, shared. |

Mechanism: the same new hooks as the 20s (`hungerRate`, `medHalfLife`,
`sickClear`); Cast Iron reads the medication side-effect roll (`sideChance`
in DanTraits_Meds.lua, a hook to add) and `overAt`; Delicate Stomach reads
the `foodGrade` and `drink` hooks, which exist.

### Point math

The 40s give 2 and the 50s 4 now. The learning band effect (profession
skills x1.1 / x1.15) and the metabolism perk (doses last longer) add real
value to both; the slower clearance of everything bad and the sleep and
stomach flaws take some back. Proposed: **leave the prices** and read them
against play with the 20s at 7. If the 50s turn out too generous once the
trade levels and the long doses are felt together, the first lever is the
50s side-skill levels (2 -> 1), not the band price.

### The pricing table, complete

| Trait | 20s | 30s | 40s | 50s |
|---|---|---|---|---|
| Strong, Athletic | 0 | 0 | +2 | +4 (built) |
| Stout | 0 | 0 | +1 | +2 (built) |
| Fit | -1 | 0 | +1 | +2 (built) |
| Fast Learner | -1 | 0 | 0 | +1 |
| Slow Learner (gives) | -1 | 0 | 0 | -1 |
| Hearty Appetite (gives) | -1 | 0 | 0 | +1 |
| Light Eater | +1 | 0 | 0 | -1 |

### The band-only traits, complete

| Band | Perks | Flaws |
|---|---|---|
| 20s | Quick Study (4), Bounces Back (3), Iron Stomach (2) | Green (4), Bottomless Pit (3) |
| 40s | Old Hand (4), Pace Yourself (2) | Reading Glasses (2), Bad Back (4), Bad Knees (3), Settled (2), Delicate Stomach (2) |
| 50s | Old Hand (4), Seen It All (3), Cast Iron (2), Old Bones Know Rain (1) | Reading Glasses (2), Bad Back (4), Bad Knees (3), Old Injury (3), Set in Their Ways (2), Delicate Stomach (2) |

Every band has a perk and a flaw of its own; the 40s stop being a lighter
50s (Pace Yourself and Settled are theirs alone); the 50s get three perks
where they had none.

### Open

1. **Clearance and the shared medication system.** `medHalfLife` scales
   every drug's half-life by the band. Daily drugs (beta blockers,
   anticonvulsants, metformin) then hold longer for the old, which is the
   perk; rescue drugs (diazepam, painkillers) too, which may be too kind.
   Option: scale daily and course drugs only.
2. **Hunger and the Vitality meal model.** Vitality grades meals; the band
   changes how fast hunger builds, not what a meal is worth. Keep it so.
3. **Seen It All against Brave and Desensitized.** Vanilla Brave and
   Desensitized already cut panic; Seen It All should stack as a factor on
   whatever is left, not replace them, and it is excluded with Cowardly.
4. **Settled and multiplayer safehouses.** "A bed in a house" needs a
   definition the server agrees with: a bed object on a square whose room
   is not nil.

### Build order, when it is wanted

Same as the 20s, one band at a time: the pricing rows first (nothing in
play changes), the band learning effect, the metabolism effect and its
hooks, then the traits. The 50s before the 40s, since the 50s need the
perks most.

## What the second build did (2026-10-07)

Everything in the two sections above, with these decisions and deviations:

- **Clearance applies to daily and course drugs only** (the user); rescue
  drugs keep their half-life. `medHalfLife` is run by DanTraits_Meds.lua for
  those kinds alone.
- **The 20s stay at 6 points** (the user). The 40s and 50s at -2 / -4.
- **No "fast metabolism" trait exists** in vanilla B42 or the mod (the user
  thought one did): the nearest are Hearty Appetite and Light Eater, which
  are now age-priced, and the mod's Iron Stomach, left as it is and unpriced.
  Iron Stomach is therefore not a 20s trait; the 20s' second perk is Bounces
  Back alone, with Bottomless Pit the flaw.
- **Seen It All's panic** is the `panicRise` stat delta pipeline (per frame),
  so it scales the game's own rise and stacks with Brave and Desensitized;
  it excludes Cowardly. Its "corpse stress" half is Germaphobe's filth
  stress only: vanilla's corpse stress is Java and not reachable.
- **Pace Yourself** refunds a tenth of an endurance fall seen while
  `isAttacking()` or `isSprinting()`, per frame, and tells the recovery
  pipeline the new value.
- **Settled** reads `player:getBed()` and its square's room; a bed with no
  room (a tent, outdoors) or no bed at all is "not a house".
- **Old Bones Know Rain** reads tomorrow's forecast (`getForecast(1)`) once a
  day from 6 AM: storm, tropical storm, heavy rain, blizzard, or
  `getTemperature():getTotalMin() <= 0`.
- **Delicate Stomach** reads the Vitality grade's "junk" reason on the eat
  hook, and a new `alcoholDrunk` hook from the drink wrap.
- **Drunkenness and food sickness clearance** stretch or hurry each minute's
  fall in Age's minute step; a fall to nothing still lingers for the old; the
  food sickness pipeline is told the new value.

## The 20s, the other side (2026-10-10, DESIGN ONLY)

The user, after play: a 20s character can be loaded with negatives and
positives and the negatives don't hurt enough. Two causes. First, the band's
recovery factors (endurance x1.25, healing x1.5, red cells x1.15, heart
strain x0.8, Type 2 resistance -0.05, hangovers x0.85, clearance x1.2) quietly
discount most of the big physical negatives, and the band's flat 6 points
buys more the more of them you stack. Second, youth had no downside of its
own. The first was fixed the same day by pricing (BUILT: MS and Heart
Condition give 3 fewer in the 20s, Asthma and Hemophilia 2, Type 2, Anaemic,
Smoker and Alcoholic 1; `AGE_PRICE`, docs/age.md). This section is the
second: what is genuinely worse at 25.

The frame: **the body forgives, the head doesn't.** The young body bounces
back; the young mind gets hooked, swings and panics. Every row below makes a
negative bite harder in the 20s or puts a cost on the band itself, so a
loaded 20s build pays for itself in play rather than at creation.

### Hooked fast (habits)

The fast metabolism already burns through a drink, a smoke or a coffee x1.2.
The other half: the craving comes back sooner, and a habit takes hold faster.

| Effect | 20s | Where |
|---|---|---|
| Smoking and drinking habit meters build (anyone) | x1.3 | Smoker `NIC_GAIN` meter rise, Dependent `ALC_GAIN` meter rise |
| Smoker: withdrawal builds | x1.25 | `NIC_RATE_BASE` / `NIC_RATE_METER` multiplier |
| Alcoholic: dry hours to craving, shakes, delirium | x0.8 (24/48/72 -> 19/38/58) | `DRY_HOURS_*` |
| Caffeine Dependent: dry hours to withdrawal | x0.75 (12 -> 9) | `CAF_ONSET_H` |

A new hook pair, `habitGain` (meter rise) and `cravingOnset` (hours divided,
build rate multiplied), read by the three systems; Age answers in the 20s.
**Pricing:** with cravings harsher, Smoker's and Alcoholic's 20s +1 (from the
softened lungs and hangovers) no longer describes the net. Recommended: take
both rows out, so those two are full price and harder young.

### A volatile mind

Late teens to late twenties are when depression and schizophrenia most often
first show, and when tempers run hottest.

| Effect | 20s | Where |
|---|---|---|
| Spiraling: episode chance | x1.3 | `MDD_EPISODE_BASE` via a new `mddEpisode` hook |
| Schizophrenia: episode chance | x1.25 | `SCHIZO_BASE_CHANCE` via a new `schizoChance` hook |
| Anger builds (anyone) | x1.25 | a new `angerRise` delta pipeline on CharacterStat.ANGER, like `panicRise` |

Anger already has teeth (weapon wear, dearer swings, curses that turn
zombies, sloppy fine work, slow reading), and a smoker's withdrawal is what
raises it, so this stacks with Hooked fast on purpose.

### Inexperience

| Effect | 20s | Where |
|---|---|---|
| Panic builds (anyone) | x1.15 | the existing `panicRise` pipeline (Seen It All's 50s x0.8 is the mirror) |

Lands hardest on Cowardly and Agoraphobic, and on a fight gone wrong. Cheapest
row to build: one number in `AGE[20]`.

### Optional, if the above is not enough

- **Epilepsy: sleep debt and hangovers count x1.3** as seizure triggers
  (juvenile myoclonic epilepsy is a young person's, triggered by exactly
  those). Hook into the trigger sum in DanTraits_Epilepsy.lua.
- **Type 1: carbs land x1.15 faster** (fits the metabolism; a young Type 1
  swings harder and is harder to dose). Hook into Diabetes' absorption.

### Point math

Nothing here changes a creation price except the two rows taken out above.
The band itself gets two everyday costs (anger, panic) and so is a little
worse for everyone; the 20s stay at 6. A plain 20s character barely notices;
a 20s Smoker, Alcoholic, Spiraling, Cowardly build feels every row.

### Build order, when it is wanted

1. Panic x1.15 (one number). 2. `habitGain` / `cravingOnset` and the three
readers, and drop the Smoker and Alcoholic price rows. 3. `angerRise`
pipeline. 4. `mddEpisode`, `schizoChance`. 5. The optional two. Tests per
row in test_age.lua plus the reading system's own test; docs/age.md table
rows; checklist section 24.

### Open

- Whether anger x1.25 is too much on top of a smoker's withdrawal anger.
- Whether the habit meters should also build x0.8 in the 50s (set in their
  ways, slower to pick up a new habit), or stay a 20s-only row.

## Considered and left out

- **Continuous ages (exact years).** Bands are easier to price and explain;
  a number adds nothing the bands do not.
- **Ageing during play.** A run lasts months, not years.
- **Vitality decaying faster when older.** Overlaps with the endurance and
  stiffness rows; one place per effect.
- **Dynamic trait costs.** Still means rewriting ~15 `getCost()` call sites in
  vanilla creation code; fixed costs plus everyday effects do the job.

## Ties

- **Life Story** (`life-story-design.md`) draws one chapter card per decade
  lived: the 50s mean five cards (Upbringing plus four decades) and a Fifties
  deck. Update that doc once this is settled, and give each deck the new
  band-only traits (Bounces Back and Iron Stomach in the Twenties deck,
  Pace Yourself and Settled in the Forties, Seen It All and Cast Iron in the
  Fifties).
- **PZ Chronicle** can mention the band in the diary voice.

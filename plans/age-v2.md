# Age, version 2

Design note, drafted 2026-10-03, decided and BUILT 2026-10-05 on branch
`age-v2` (unplayed). How the built system works is in `docs/age.md`; this note
is the reasoning. Where the two differ, the code and `docs/age.md` are right.

A note on signs: the costs in this note are the player's points (-3 = the
player pays 3). The trait script uses the game's sign, the other way round:
`Cost = 3` for the 20s, `-2` for the 40s, `-4` for the 50s. The first
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

1. **The 20s price.** With the stronger 20s numbers, 3 points buys about what
   Fast Healer (6) and a training bonus would. Raise it?
2. **Wide ties.** Park Ranger boosts five skills equally, so a 50s Park
   Ranger starts with +3 in all five. Burglar has three.
3. **Age-exclusive traits** (a trait only one band can take): possible with
   the script's exclusions for "not in the 20s" style rules; "only in the
   50s" needs the hidden 30s handled in Lua, since a character who picks no
   age has no trait on the creation screen.

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
  deck. Update that doc once this is settled.
- **PZ Chronicle** can mention the band in the diary voice.

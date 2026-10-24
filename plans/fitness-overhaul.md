# Fitness overhaul

Agreed 2026-10-18: build recovery, the cheap and medium exercises and training
plans, plus loot magazines that boost Fitness and Strength gains. Detraining
is out. Traits come after this lands. New animations are welcome later
(section 7).

Not a trait: everyone has it, behind the sandbox option `FitnessEnabled`
(default on). A second option, `FitnessStrain` (default on), turns pulled
muscles off for players who only want the rewards.

## 0. What vanilla does (read from the game, 2026-10-18)

- `FitnessExercises.exercisesType` (shared Lua) lists seven exercises. The
  Java `Fitness` class reads that table in `init()`, so entries added from Lua
  at load time are real exercises with their own regularity.
- `ISFitnessUI:onClick` builds `ISFitnessAction:new(player, key, minutes,
  data, data.type)`. The **key** becomes the animation variable
  `ExerciseType`; `data.type` drives the regularity and the server's rep
  period. A new exercise that borrows an animation has to set `ExerciseType`
  to the borrowed key (a wrap of `start`).
- Each rep (`exeLooped` -> `Fitness.exerciseRepeat`) raises regularity, drains
  endurance, queues stiffness on the exercise's areas (arms, chest, abs, legs;
  it lands 12 hours later) and adds Fitness/Strength XP (`Events.AddXP` fires).
- The window refuses to start past the second endurance moodle, at heavy load
  3, in pain 4, sitting, or in a vehicle.
- The `TiredStretch` ext animation plays from Lua with
  `setVariable("Ext", "TiredStretch")` + `reportEvent("EventDoExt")`, standing
  or sitting on the ground.
- Gym tiles: the weight bench is `CustomName = Fitness_Contraption`, the
  treadmill `Human_Hamster_Wheel` (Moveables.json).

## 1. Recovery and adaptation (`DanTraits_Fitness.lua`)

Four muscle groups, the vanilla stiffness areas: **arms, chest, core, legs**.

**Load.** Each minute spent training adds load to the exercise's groups:
`1/30` a minute (heavy exercises x1.3, as vanilla's `FitnessHeavy`), so 30
minutes of one exercise is a full load of 1.0. Jogging, carrying and hard
work add less (section 2).

**Recovery.** Load falls by `1/36` an hour awake and twice that asleep, times
the `fitnessRecovery` hook: Vitality +-25% (like healing), Age's band (the
stiffness factor: faster in the 20s, slower from the 40s), the plan bonus,
the stretching boost and the Limber magazine. A full load clears in about a
day and a half, a night's sleep included.

**State of a group** (shown in the window, drives XP):

| State | When | Training XP |
|---|---|---|
| Ready | load under 0.15, last trained 20 to 96 hours ago | x1.25 |
| Rested | load under 0.15 otherwise | x1.0 |
| Recovering | 0.15 to 0.6 | x1.0 |
| Sore | 0.6 to 1.0 | x0.6 |
| Overworked | over 1.0 | x0.3 |

The state that sets the XP is the group's **carried** load: what it had when
the session first reached it (as built: soreness is about the last session,
not the one you are in). Within a session, past 1.5 load on a group (45
minutes) its XP halves. An exercise's factor is the lowest of its groups.
Ready is supercompensation: training a group again once it has recovered,
but before the gains fade.

**Pulled muscle** (`FitnessStrain`). Each training minute rolls, for the worst
group, `2% x (carried - 0.6) / 0.4` plus `1% x (session load - 1.5) / 0.5`:
1% a minute coming in Sore at 0.8, 3% Overworked at 1.2, and a fresh hour-long
session only near its end. x1.5 with improvised weights, x0.5 at a weight
bench; hard work never rolls. A strain picks a part in the group: pain floor
25, its stiffness held at 30, that group cannot be trained (the window says
why and a running exercise stops), for 36 hours, twice as fast asleep. One
strain at a time.

**Pumped.** 15 minutes of training within a session (gaps under 10 minutes
join; hard work does not count) and you are Pumped for 3 hours: stress
-0.0004, unhappiness -0.05, boredom -0.1 a minute, and Depression's relief
reads at least 0.8 for exercise.

**Overtrained.** A hard day is one with 20 minutes or more of training.
Seven hard days in a row and you are Overtrained until two days in a row
without one: training XP x0.7, nights score 0.05 worse, endurance regen
x0.9. Any plan's rest days avoid it.

**Stiffness.** Vanilla stiffness stays: it is what soreness feels like.
Stretching hurries its fade (x2 while stretching, x1.25 Loosened Up) through
Age's existing pacing (a new `stiffFade` hook there); Age's band still sets
the rest.

## As built (2026-10-18)

Files: `DanTraits_FitnessData.lua` (groups, exercises added to the game's
list, plans, magazines), `DanTraits_Fitness.lua` (minute order 40: sessions,
load, recovery, strain, Pumped, Loosened Up, overtraining, plans, the moodle
levels, the experience handler), `DanTraits_FitnessActions.lua` (the wraps on
`ISFitnessAction`: borrowed animation at `start` and `serverStart`, the rep
marked in `exeLooped`; the heaviest stand-in carried),
`TimedActions/ISDanTraitsStretchAction.lua`, `client/DanTraits_FitnessUI.lua`
(the window and Work Out). Hooks added: `stiffFade` (Age), `exerciseScore`
(Vitality), `mddExercise` (Depression); Fitness offers `fitnessRecovery`
(Age's band, Vitality +-25%), `fitnessXp` and `fitnessStrain` for the traits
to come, and reads `nightQuality`, `enduranceRegen`, `arthritisJoint`.
Tests: `tests/test_fitness.lua`.

Unverified until played: the borrowed animations with a log or a car battery
in hand, the stretch animation fired from Lua, the window's new section
(layout, the drop-down), whether the game's `init()` takes the new entries
on a save made before them, the regularity steps a minute for jogging (2,
a guess), and the weight-bench tile name on real maps.

## 2. Exercises (`DanTraits_FitnessExercises.lua`)

**Improvised weights** in the fitness window, each borrowing a vanilla
animation and holding the real item:

| Exercise | Animation | Items (heaviest first) | Groups |
|---|---|---|---|
| Improvised Curl | barbell curl, two hands | log, propane tank, full bucket, sandbag, gravel bag, dirt bag, car battery, tyre | arms, chest |
| One-Arm Curl | biceps curl, switching hands | car battery, paint can, vinegar jug, bag of flour | arms |
| Overhead Press | dumbbell press, switching hands | the same | arms, chest |

XP x(item weight / 6 kg for two hands, / 5 kg for one), clamped 0.5 to 1.2;
items under 1.5 kg do not count. Awkward loads: strain risk x1.5.

**Stretching** (in the window, own timed action): plays the stretch animation
every few seconds, standing or sat on the ground. No XP. While stretching,
recovery x2 and stiffness fades twice as fast; afterwards Loosened Up for 4
hours: recovery x1.25 and Arthritis's stiffness floor x0.7. Stress -0.0003 a
minute while at it.

**Counted without the window** (each a hidden exercise with its own
regularity, so Vitality and Depression see it):

- **Jogging**: running, not sprinting, on foot: legs load 1/45 a minute,
  3 regularity steps a minute. Cardio for the plans.
- **Loaded carry**: moving with heavy load 1 or more: legs and core 1/60,
  arms 1/90 a minute. Carry for the plans.
- **Hard work**: metabolic rate 5 or more, not running and not in the window
  (chopping, digging, fighting): arms and core 1/90 a minute. Counts as any
  training for a plan's "full body" day, at half credit.

**Gym equipment.** Barbell and dumbbell exercises within 3 tiles of a weight
bench: XP x1.15 and strain risk x0.5 (spotted, proper form). Right-clicking a
weight bench or treadmill offers "Work Out" (opens the window). The
treadmill as cardio waits for an animation.

## 3. Training plans (`DanTraits_FitnessPlans.lua`)

Pick a plan in the window; its seven-day cycle starts that day. Each day is
a target:

| Target | Done when |
|---|---|
| Upper | 20 min on arms or chest exercises |
| Lower | 20 min on legs or core exercises |
| Push | 20 min on chest exercises (push-ups, presses, burpees) |
| Pull | 20 min on curls |
| Legs | 20 min on legs exercises |
| Full | 20 min of any training (hard work counts half) |
| Cardio | 20 min jogging |
| Carry | 20 min loaded carry |
| Mobility | 15 min stretching |
| Rest | nothing hard (20 min or more of training breaks the rest) |

| Plan | Days | Learned from |
|---|---|---|
| Full Body | Full, Rest, Full, Rest, Full, Mobility, Rest | everyone |
| Upper/Lower | Upper, Lower, Rest, Upper, Lower, Mobility, Rest | Iron Monthly: Upper/Lower |
| Push Pull Legs | Push, Pull, Legs, Rest, Push, Pull, Rest | Iron Monthly: Push Pull Legs |
| First Five Miles | Cardio, Rest, Cardio, Rest, Cardio, Mobility, Rest | Pavement: First Five Miles |
| Strongman | Carry, Full, Rest, Carry, Legs, Rest, Rest | Strongman Quarterly |
| Active Recovery | Mobility, Full, Mobility, Cardio, Mobility, Rest, Rest | Limber |

Fitness Instructors know every plan.

**On plan** (as first built: every target day in the last seven done; since round three, a target day done in the last seven and no miss in the last two days, so a miss costs two days of bonus, not a week): training
XP x1.15, recovery x1.15, and Vitality's exercise score +0.1. A full week
completed says so. Missing a day costs nothing but the bonus.

**Log.** The window shows the last seven days: minutes by kind, each day
marked done, missed, rest or today.

## 4. Magazines (loot)

Five magazines, read like Living With Type 1 (a `LearnedRecipes` knowledge
flag, read with `isRecipeActuallyKnown`). Each teaches its plan and a
permanent bonus to **all** XP for its skill:

| Magazine | Bonus | Plan |
|---|---|---|
| Iron Monthly: Upper/Lower | Strength +10% | Upper/Lower |
| Iron Monthly: Push Pull Legs | Strength +10% | Push Pull Legs |
| Pavement: First Five Miles | Fitness +10% | First Five Miles |
| Strongman Quarterly | Strength +5%, Fitness +5% | Strongman |
| Limber | Fitness +10%, recovery x1.1 | Active Recovery |

At most Strength +25% and Fitness +25% with all five. Loot: gym lockers and
the fitness trainer's things first (as common as vanilla's health magazine
there), then sports shelves of libraries, magazine racks and crates, closets
of sports gear, now and then a living-room shelf.

## 5. XP stacking

The training factors (group state, plan, overtrained, improvised weight,
weight bench) apply only to XP from a rep, known by wrapping `exeLooped`.
The magazine bonus applies to any Fitness or Strength XP. Both go through
Age's quiet adjust (`DanTraits_AgeXpAdjust`), so Age and Vitality do not
stack on top, and they skip Age's own top-ups, as Vitality does. They add as
sums with Age's and Vitality's shares (the convention test_xpstack pins).

## 6. Moodles

- **Pumped** (good): -1 Loosened Up (stretched), -2 Pumped (a session).
- **Sore Muscles** (bad): 1 Sore (a group over 0.6), 2 Overworked (over 1.0),
  3 Pulled Muscle.
- **Overtrained** (bad): one level.

## 8. Traits and links (agreed and built 2026-10-18)

All nine of the proposed traits are in, Endorphin Junkie included; MS left
out of the links on purpose ("MS is hard enough as it is"); both Diabetes
types get the link. Numbers are in the `TR` table of `DanTraits_Fitness.lua`
and in CHANGELOG.md.

| Trait | Cost | Effect |
|---|---|---|
| Well Conditioned | +4 | recovery x1.5, Ready from 14 h, pulls heal x2 |
| Weightlifter | +4 | weights and improvised XP x1.2; improvised no riskier |
| Natural Runner | +3 | jog counts double, legs load x0.5, running Fitness XP x1.25 |
| Regimented | +3 | plan bonus x2, one missed day in seven forgiven |
| Endorphin Junkie | +1 | Pumped 6 h, lift x2; 48 h without: Restless |
| Lingering Soreness | -3 | recovery x0.6, Ready from 30 h |
| Injury Prone | -3 | pull risk x2, 54 h |
| Exercise Averse | -3 | never Pumped; training bores and saddens; plan bonus x0.5 |
| Inflexible | -2 | stretching boosts halved, stiffness fades x0.7, Arthritis x1.1 |

Links: Diabetes (a workout burns sugar during and after), Asthma (burpees),
Heart Condition (heavy lifting), Brittle (leg days), Bad Back (improvised
lifts, core pulls), Gym Regular (knows Upper/Lower).

Not done: the age price table (`AGE_PRICE` in Age) does not re-price these
by band; Well Conditioned in the 20s and Lingering Soreness in the 50s
would be the obvious candidates.

## 9. Round two (2026-10-18, after the first play)

The user played it with Neat Rocco (a UI mod that replaces the fitness
window). Fixed: the section is a child panel, so any replacement shows it;
improvised exercises are named for the item ("Log Curls"); stretching has a
progress bar. Changed: overtraining needs a hard day of 40 + 6 x (Fitness +
Strength) minutes (20 was "barely anything"); Powerlifter is Weightlifter
("not many powerlifters in 1993 Kentucky"), Disciplined is Regimented
(Lifestyle: Hobbies has a Disciplined). Added at the user's request: a fit
body eases Arthritis and MS (up to 20%, never away) and stretching 10% each;
Arthritis and MS can no longer start with Athletic, Fit, Strong or Stout
(costs up: -12, -16); Bad Back -8 with worse pain, stiff legs (slower
walking), a thrown-out back (4 hours), the Back Strain moodle and core
training that eases it.

## 10. Round three (2026-10-18): plans made plain

The user found the plan system hard to follow; the old rule meant one missed
day cost about a week of bonus, with nothing on screen saying why. Now: a
miss costs the bonus for the two days after it (`FIT_MISS_DAYS`), the
window's plan section has a status line ("On plan: +15% experience and
recovery", or "Off plan: missed a day yesterday, back in 2 days", or "Off
plan: finish a training day to start"), and a notice comes on going on or
off. Regimented still forgives the first miss of any seven days.

## 11. Sets in reps (2026-10-18)

From the time-to-level working (vanilla: 6 Strength a push-up, 4 Fitness a squat,
7.2 Strength a curl or press; a set ends at the third endurance moodle, about 50
reps, 38 heavy; levels 5 to 10 need 20, 40, 60, 80 and 100 thousand; Strength x1.5
with protein between 50 and 300): load per minute made slow exercises cost twice
the load for the same experience. Load is now per rep (0.5 effort minutes a rep),
the window asks for reps, the set stops on its last, and the sandbox option
FitnessXp sets the pace. Optimal training (one Ready set per group a day, on plan,
Thriving Vitality, magazines): Strength 5 to 6 in about 17 days, Fitness in about
26; to 10 roughly 8 to 9 months and over a year.

## 7. Later, with animations

Pull-ups (door frames, playground bars), lunges, planks, bench press on the
weight bench, the treadmill as cardio, skipping rope. Traits after this
lands: Fast Recovery, Natural Runner, Weightlifter, Bad Back, Exercise
Averse, Slow Recovery; Gym Regular could start knowing Upper/Lower.

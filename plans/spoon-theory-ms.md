# Spoon theory: an energy budget for Multiple Sclerosis

Design, 2026-10-02. Nothing here is built. Agreed in conversation: the
budget, refill by sleep, small top-ups from rest, debt for pushing on, and
that it must sit on the existing sleep system rather than beside it.

## The problem

MS fatigue is the symptom people with MS name first, and it is a wall, not
sleepiness. The trait today models it as a flat drip into the game's
tiredness stat (a fifth faster, more in a flare, more in the heat). The
player never feels a budget, only a slightly earlier bedtime. Amantadine,
the drug prescribed for exactly this, reads as "a smaller drip".

## The idea

You wake with a number of spoons. Everything you do costs some, faster in
the heat or a flare. When they are gone you have hit the wall for the day,
whatever the clock says. You can keep going, but every hour past the wall
is borrowed from tomorrow at a bad rate. Sleep is what gives them back, and
how many you get back depends on the night, which the mod already scores.

## What exists and what it gives us

The Sleep file (`DanTraits_Sleep.lua`) reads the light on the square every
minute asleep, keeps a running darkness total (`slNightDark`, `slNightMin`),
and wakes the character for light, nightmares and caffeine. It feeds the
night's score through the `nightQuality` hook: darkness, and the fever cut
from Infection.

Vitality (`DanTraits_Vitality.lua`) owns the night:

- segments of sleep accumulate into `vitNightHours` and `vitNightWakes`;
- the night is scored once the character has been awake for the `nightGap`
  (60 minutes; Restless Sleeper stretches it to 180 so two halves are one
  night);
- quality = half hours slept over the need (7, 5 or 9 by trait) + half
  "woke up rested" (1 - fatigue), minus 0.05 per extra wake (max 0.2), then
  the `nightQuality` hooks (darkness, fever);
- a sleep under 3 hours is a nap: it halves the sleep debt and is not scored;
- `vitLastSleepHours`, `vitLastSleepWakes`, `vitLastSleepQuality` are kept;
- `vitSleepDebt` (0..1) drains over 14 awake hours and drives Slept Badly.

So every input the refill wants is already measured, and every sleep trait
already acts on it: Deep Sleeper's darker nights, Night Shift's days,
Restless Sleeper's halves, caffeine and nightmare wakes, a fever, a lit
room. The spoon module must not re-measure any of it.

## The budget

A new shared file, `DanTraits_Spoons.lua`, keeps one pool per character.
MS feeds it; it is written so a later trait can too (hooks below). The
pool only runs for a character with at least one registered user; for
everyone else nothing is stored.

Mod data: `spPool` (spoons now), `spCap` (today's cap), `spDebt` (hours
borrowed, 0..6), `spRest` (spoons got back by resting today), `spWallMin`
(minutes at the wall today), `spMask` (coffee minutes left), `spTier`.

Constants to tune in play:

| | |
|---|---|
| SP_CAP | 12 spoons on a normal day |
| SP_FLARE_CAP | 8 in a flare (`spoonCap` hook from MS) |
| SP_FLOOR | 1/3: the worst night still gives a third of the cap |
| SP_NAP_MAX | 4 spoons from naps, per day |
| SP_REST_MIN | 0.01 a minute of true rest (half a spoon an hour) |
| SP_REST_MAX | 2 a day from rest |
| SP_BASE_MIN | 1/160 a minute awake (an idle 16-hour day costs 6) |
| SP_MET_MIN | 0.0075 per MET-minute above 1.5 |
| SP_DEBT_MAX | 6 hours |
| SP_MASK_MIN | 60 minutes a coffee hides the wall |

## Refill: tying into the night

Two moments matter and the night system has both.

**On waking** (Vitality sees `vitAsleep` go false), Vitality fires a new
hook `wokeUp(player, d, segmentHours, fatigue)`. Spoons sets a *provisional*
pool from what is known then: hours slept so far this night
(`vitNightHours`), rested (1 - fatigue), darkness so far (`slNightDark /
slNightMin`, still unreset at that point), fever. This is so the player
has spoons the moment they get up, not an hour later.

**At scoring** (one gap later), Vitality fires `nightScored(player, d,
quality, hours, wakes, isNap)` after the final quality is known. Spoons
replaces the provisional refill with the real one:

    refill = cap * (SP_FLOOR + (1 - SP_FLOOR) * quality) - debt + drugs
    pool   = clamp(refill - spentSinceWaking, 0, cap)

Anything spent between waking and scoring is honoured, so the correction
can move the pool up (a Restless Sleeper's second half arrives) or down
(more wakes than the provisional assumed). Debt clears when it has been
paid: `spDebt = 0`.

A **nap** (under 3 hours, Vitality's own rule) does not reset. It adds
`4 * hours / 3 * (0.5 + 0.5 * darkness)`, capped so naps give at most
SP_NAP_MAX a day and the pool never exceeds the cap. Two sleeps closer
than the night gap are one night, exactly as Vitality already decides.

What falls out for free: Deep Sleeper gets more spoons (darker nights),
Needs More Sleep needs 9 hours for a full refill, a lit room or a noisy
night gives fewer, a fever gives fewer, caffeine at bedtime gives fewer
through its wakes, Night Shift's daytime sleep scores as it does now.

**Amantadine** stops cutting the fatigue drip (the drip goes away, see
below) and instead adds 2 spoons to the refill once built up (`spoonRefill`
hook from MS, scaled by the drug's effect 0..1).

## Spending

Every minute awake:

    cost = SP_BASE_MIN + SP_MET_MIN * max(0, met - 1.5)
    cost = cost * (1 + heatLoad) * (flaring and 1.5 or 1)
    cost = cost * (1 + 0.3 * pain/100 + 0.3 * panic) * (hungry and 1.2 or 1)
    cost = RunHooks("spoonSpend", cost, player, d)

`met` is the thermoregulator's metabolic rate Vitality already reads (idle
1.5, walking 3, chopping 5.5, sprinting 7 to 8). On these numbers a busy
day (average MET 4) empties 12 spoons in about eight hours; an idle day
costs half the pool. Sprinting is about 3 spoons an hour before heat.

The heat multiplier replaces MS_HEAT_FATIGUE; the flare multiplier replaces
MS_FLARE_FATIGUE; the baseline MS_FATIGUE drip goes. MS fatigue is now
*only* the spoons, so nothing is counted twice. The heat's other effects
(stiff hands, pain, fumbles, hands giving out) are untouched.

**Rest** gives a little back while awake: `met < 1.8`, not carrying over
80% of capacity, not in a vehicle, not hungry. SP_REST_MIN a minute, up to
SP_REST_MAX a day. Sitting, reading, lying on a bed awake all qualify.
Standing in a doorway with a full pack does not.

## Running out

Tiers on the pool as a fraction of the cap, awake only:

| tier | pool | what it does |
|---|---|---|
| 0 | over half | nothing |
| 1 Half gone | at or under half | moodle only; notice once a day |
| 2 Running on empty | 3 spoons or fewer | endurance recovery x0.7; fatigue +0.0004 a minute; legs to 20 stiffness (baclofen halves it, as now) |
| 3 The wall | 0 | endurance recovery x0.4; fatigue +0.0010 a minute; legs at the flare's 35; swing drop +5%; notice "You've hit the wall" |

All of these are things the MS file already knows how to do (its
`enduranceRegen` and `swingDrop` hooks, `setFloors`, `DanTraits_StatAdd`).
The character can always still walk home.

**Borrowing.** Each hour awake at the wall adds one to `spDebt` (max 6) and
comes off tomorrow's refill. While debt is above zero the flare rate is
x(1 + 0.1 * debt) through `DanTraits_MSFlareRate`. Debt does not compound.

**Coffee.** A caffeine dose of 40 or more (the Caffeine file's `dose` is
already called for everyone through the sleep hook; add a `spoonMask`
call there) sets `spMask` to 60 minutes. While it runs, tiers 2 and 3 are
*felt* as one tier lower. No spoons are gained; when it ends the tier lands
with its notice. Smokers clear it faster through the existing
`caffeineClearance` hook.

## What the player sees

- Moodle `Spoons`, three bad levels (Half Gone, Running on Empty, The
  Wall), fed from `DanTraits_Moodles.lua` like the others, icon a spoon.
- Notices: on scoring, "12 spoons today" / "8 spoons today: a bad night" /
  "7 spoons today, paying for yesterday" (one line, the number is the
  point); at half; at the wall; "A coffee is carrying you" when the mask
  starts and "and that's the coffee gone" when it ends.
- Trait description gains a paragraph; the moodle descriptions carry the
  rules (what a bad night costs, that resting helps, that pushing on
  borrows). The health panel is per body part, so the count lives in the
  notices and, if Moodle Framework lets a description be set at runtime
  (to check), in the moodle's hover text as "7 of 12".
- Sandbox: `MSSpoons` (12; 0 turns the budget off and restores the old
  fatigue drip). Console: `ms spoons <n>`, `ms spoons debt <h>`. Telemetry:
  the `sp*` keys.

## Interactions to decide

- Vitality's Slept Badly already punishes a bad night (mood, stress, a
  fatigue drip for 14 hours). With spoons the same night also means a
  short day. For MS that doubling is the point, but it should be said in
  the moodle text so it does not read as a bug.
- A flare caps the pool at 8 *and* multiplies spend. Both, or just the cap?
  Proposed both; a flare should feel like half a person.
- Straight Edge, Deep Sleeper and the rest need nothing; the night system
  carries them.
- Multiplayer: per character mod data, nothing shared.

## Build order

1. `DanTraits_Spoons.lua`: the pool, spend, rest, tiers, debt, mask; hooks
   `spoonCap`, `spoonRefill`, `spoonSpend`; `wokeUp` and `nightScored`
   listeners. `tests/test_spoons.lua` with a faked MET and the harness's
   sleep flag: a full dark night fills, a lit broken night gives the
   floor, a nap tops up, a busy day empties by afternoon, the wall borrows,
   the next refill is short by the debt, a coffee masks for an hour.
2. Vitality: fire `wokeUp` and `nightScored` (two lines each, no change in
   behaviour; `test_vitality.lua` asserts both fire with the right values,
   including the Restless Sleeper halves and a nap).
3. MS: register as a user; `spoonCap` (flare), `spoonRefill` (amantadine);
   remove the three fatigue drips; apply the tiers; debt into the flare
   rate; `ms spoons` console. `test_ms.lua` updated for the missing drip.
4. Caffeine: `spoonMask` call in `dose`.
5. Moodle, icon, translations, trait text, README, changelog, sandbox
   option, telemetry keys, checklist section 20 (ids `sp-*`).

Nothing is committed until it has been played.

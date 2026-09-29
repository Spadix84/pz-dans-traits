# 05. One place that scales stat deltas

Phase 1, after 04. Sonnet. This is the second bug from the review.

## Problem

Six files scale endurance recovery per frame, each with its own remembered
"last" value: Vitality (`vitLastEndurance`, +/-20%), Smoker (`nicLastEndurance`,
lungs up to -30%), Blood (`bloodLastEndurance`, tier cut plus weakness,
plus a ceiling in shock), Anemia (`anLastEndurance`, -40%), Concussion
(`ccLastEndurance`, -30%), Asthma (`asthmaLastEndurance`, x0.5 or x0).
They run in load order on the same stat and each compares to its own last
write, so a handler's "gain" includes the earlier handlers' cuts from the
previous frame. The cuts neither multiply nor take the max: two 50% cuts
settle at about one third of the regen, and six interact unpredictably.

Same pattern, per minute: catch-a-cold in Vitality (`vitLastCatch`) and
Anemia (`anLastCatch`); food sickness in Positives/Iron Stomach
(`isLastSick`), which halves the ramp of every mod nausea floor set the
previous minute (hangover, migraine, gluten, diabetes, concussion, MDD side
effects), which is not what Iron Stomach means.

## Change

1. In core (or Util), a delta pipeline:

   ```lua
   -- DanTraits_DeltaHook(stat, name, cadence): once per cadence, read the
   -- stat, take the change the game (and anything outside the pipeline)
   -- made since last time, run the "<name>" hook with that delta
   -- (subscribers return a new delta), write back last + newDelta.
   -- One remembered value per stat.
   ```
   Register three: `enduranceRegen` on the frame cadence (only positive
   deltas are offered; negative pass through untouched), `catchCold` on the
   minute cadence (positive deltas), `foodSicknessRise` on the minute
   cadence (positive deltas). The pipeline runs FIRST in its cadence (order
   0) so subscribers see the game's delta, not each other's writes.
   Subscribers are pure: `function(delta, player, d) return delta * k end`.

2. Convert:
   - Vitality: `enduranceRegen` x (1 + VIT_ENDURANCE_REGEN * e); `catchCold`
     x (1 - VIT_COLD * e). Delete `vitLastEndurance`, `vitLastCatch`.
   - Smoker: `enduranceRegen` x (1 - LUNG_ENDURANCE * lungs). Delete
     `nicLastEndurance`. `holdAnger` stays on the frame cadence.
   - Blood: `enduranceRegen` x cut. The shock ceiling stays a separate frame
     clamp (set to the cap when above) since it is not a delta. Delete
     `bloodLastEndurance`.
   - Anemia: `enduranceRegen` x (1 - AN_ENDURANCE_CUT * deficit); `catchCold`
     x (1 + AN_COLD * deficit). Delete both `anLast*`.
   - Concussion: `enduranceRegen` x (1 - CC_ENDURANCE * s). Delete `ccLastEndurance`.
   - Asthma: `enduranceRegen` x keep (0.5 or 0). Delete `asthmaLastEndurance`.
   - Iron Stomach: `foodSicknessRise` x IS_SICK_CUT, but only when no mod
     system set a food-sickness floor this minute. Mechanism:
     `DanTraits_FloorUp` (plan 03) records `d.floorsThisMinute[statName] = true`;
     the pipeline clears the table at the start of each minute.
   - Sleep's `slLastFatigue` rest scaling stays as is: it is the only writer
     of fatigue-while-asleep deltas.

3. Tests. `tests/test_delta.lua`: with two subscribers of 0.5 the net regen
   is exactly 0.25 of the game's; a negative delta is untouched; the Iron
   Stomach rule. Update the six files' tests where they asserted on their
   private `last*` keys (search `LastEndurance`, `LastCatch`, `isLastSick`).
   The dashboard hide-list in `DanTraits/tools/dashboard.py` names
   `ccLastEndurance`, `bloodLastEndurance`, `anLastEndurance`: remove them.

## Acceptance

- Suite green; the delta test proves multiplicative composition.
- `grep -rn "LastEndurance\|LastCatch\|isLastSick" DanTraits/` returns nothing.
- The header comment of each of the six files says "endurance recovery
  through the enduranceRegen hook" instead of describing its own bookkeeping.

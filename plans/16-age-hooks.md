# 16. Age hooks: red cells, concussion, hangover, type 2

Phase 2. Sonnet. Depends on plan 15 for `concussionHeal`.

## Problem

`DanTraits_Age.lua` touches Handy, Gym Regular and Arthritis. Its own rule:
age may make a negative harsher or lock it out, and may make a positive
stronger only where the Age trait pays for it. The 40s trait costs +1, so
harsher universal systems in the 40s are within the rule; the 20s trait
costs -2, so gentler ones in the 20s are too.

## Change

All in `DanTraits_Age.lua`, as hooks guarded by `ageEnabled()` and the band.

1. `bloodCellRebuild` (exists, Blood): 40s x AGE_CELLS_40 = 0.8; 20s x 1.15.
2. `concussionHeal` (plan 15): 40s x 0.75; 20s x 1.2.
3. Hangover severity. Add a `hangoverSeverity` hook in `armHangover`
   (`DanTraits_Hangover.lua`) around the computed severity before the
   tolerance cut. 40s x 1.25, 20s x 0.85.
4. Type 2 resistance. Add a `diaResistance` hook at the end of
   `diaResistance` in Diabetes (before the clamp). 40s + 0.1; 20s - 0.05.
5. Brittle. Optional, same rule: `brittleChance` hook on `FRACTURE_CHANCE`;
   40s x 1.25. Add the hook in Brittle with a comment.
6. The Age header's table gains four rows; README Age paragraph lists them;
   the 20s and 40s trait descriptions in `Translate/EN/UI.json`
   (`UI_trait_DanAge20sdesc`, `UI_trait_DanAge40sdesc`) mention them in one
   clause each.

## Tests

`test_age.lua`: each hook returns nil in the 30s and the stated factor in
the 20s and 40s; `AgeEnabled = false` returns nil everywhere.

## Acceptance

- Suite green. The Age file header's rule paragraph still holds for every
  row.

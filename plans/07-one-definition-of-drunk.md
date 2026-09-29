# 07. One definition of drunk

Phase 1. Sonnet. Small, and it must not change numbers.

## Problem

Five systems decide "is drinking / is drunk" differently:

| file | test | meaning |
|---|---|---|
| Dependent | intoxication >= 0.01 (ALC_ANY) | "had any alcohol" for the meter and relapse |
| Hangover | > 0.20 (HO_BUZZ) build; < 0.05 sober | load builds past a buzz |
| MDD | > 0.05 | drink relief and severity creep |
| Diabetes | > 0.05 | liver busy; too drunk to notice symptoms |
| Smoker | `DanTraits_DrunkLevel >= 2` | cravings build faster; ex-smoker cue |
| Alcohol.lua | Drunk moodle level 0..4 | pain and panic relief |

They mostly agree in spirit but drift in practice, and each reads the stat
its own way on a scale core guesses at (`DanTraits_StatFraction`).

## Change

1. Make `DanTraits_Alcohol.lua` the single source: keep `DanTraits_DrunkLevel`
   (moodle level, intoxication fallback) and add
   `DanTraits_Intoxication(player)` (0..1, one pcall) and a table of named
   thresholds `DanTraits_DRINK = { any = 0.01, tipsy = 0.05, buzz = 0.20, sober = 0.05 }`.
2. Replace the local reads: Dependent uses `any`; Hangover `buzz` and `sober`;
   MDD and Diabetes `tipsy`. Smoker keeps `DrunkLevel >= 2`. No number changes
   in this plan; the point is one place to change them.
3. Load order: Alcohol.lua loads before the readers alphabetically, but do
   not rely on it. Each reader does
   `local DRINK = DanTraits_DRINK or { any = 0.01, tipsy = 0.05, buzz = 0.2, sober = 0.05 }`.
4. Tests unchanged in numbers; add one assertion in `test_alcohol.lua` that
   the table exists with those keys.

## Acceptance

- Suite green.
- `grep -rn "INTOXICATION) or 0) > 0.05\|>= ALC_ANY\|> HO_BUZZ" DanTraits/42/media/lua/shared`
  returns nothing outside Alcohol.lua.

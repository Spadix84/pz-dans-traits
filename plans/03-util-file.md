# 03. A util file for the copied helpers

Phase 1. Haiku or Sonnet. Mechanical.

## Problem

| Helper | Copies | Where |
|---|---|---|
| `clamp01` | 10 | most trait files |
| `floorUp(stats, stat, floor, ramp)` | 5 | Hangover, Caffeine, Migraine; inline variants in Gluten, Diabetes, Vitality, MDD. Two clamp behaviours: Gluten/Diabetes clamp to 100, the others do not clamp |
| `roll(chance)` / `randRange(lo, hi)` | 6 / 3 | Infection, WoundCare, Concussion, Hemophobia, Smoker (percent variant), Dependent |
| body-part `PARTS` short-name map plus `partOf` | 3 | Blood, Infection, WoundCare |
| `num(part, method)` / `is(part, method)` / `partIs` | 4 | Blood, Infection, WoundCare, Hemophilia, HealthPanel |
| Moodle Framework updater, "bad side only, 0.5 is none" | 7 | Vitality (2), Hangover, Migraine, Blood, Infection, Concussion, Asthma |
| `local asleep = false; pcall(function() asleep = player:isAsleep() end)` | 16 | everywhere |
| `sandboxOn()` reading `SandboxVars.DanTraits.<X>Enabled ~= false` | 4 | Blood, Infection, WoundCare, Concussion (plus Age's variant) |
| `add(stats, stat, amount, cap)` / `addFrac` / `statAdd` | 3 | Dependent, Smoker, Infection |

Core (`DanTraits.lua`) is documented as near the 200-local limit, so these
go in a new file.

## Change

1. Create `DanTraits/42/media/lua/shared/DanTraits_Util.lua`. It requires
   nothing. It defines only globals prefixed `DanTraits_` (keep the file's
   top-level locals under 60 for the upvalue limit):
   - `DanTraits_Clamp01(x)`
   - `DanTraits_StatMax(stat)`: pcall around `getMaximumValue`, default 1;
     the 0..100 stats report 100.
   - `DanTraits_FloorUp(stats, stat, floor, ramp)`: raise toward `floor` by
     at most `ramp`, never above `floor`, never above the stat's max.
   - `DanTraits_StatAdd(stats, stat, amount)`: add, clamp to [0, max].
   - `DanTraits_Roll(chance01)`, `DanTraits_RollPercent(pct)`, both using
     `ZombRandFloat` when present, else `math.random`; `DanTraits_RandRange(lo, hi)`.
   - `DanTraits_PartNames` (the short-name map) and
     `DanTraits_PartOf(player, shortName)`.
   - `DanTraits_PartNum(part, method)`, `DanTraits_PartIs(part, method)`.
   - `DanTraits_Asleep(player)`.
   - `DanTraits_SandboxOn(optionName)`: `SandboxVars.DanTraits[optionName] ~= false`
     when the table exists, else true.
   - `DanTraits_BadMoodle(player, name, value01, tiers)`: the MF updater:
     thresholds `0.5 * (1 - t)` for the tiers given (3 or 4), value
     `0.5 * (1 - value01)`. Keep Asthma's and Infection's hand-set thresholds
     by letting `tiers` be either a list of 0..1 tier points or
     `{ thresholds = {...} }`.
2. `DanTraits.lua` does `require "DanTraits_Util"` right after
   `require "DanTraits_Attrib"`.
3. Replace every copy, file by file, reading each helper into a local at the
   top (`local clamp01 = DanTraits_Clamp01`). Keep local names so diffs stay
   small. Where a copy differs in behaviour (the two `floorUp` clamps,
   Smoker's percent roll), pick the shared one and adjust call sites so the
   numbers are unchanged; the existing tests catch a drift.
4. Update the loader in the test harness (plan 02) to load
   `DanTraits_Util` after `DanTraits_Attrib`.
5. Add `tests/test_util.lua`: FloorUp never overshoots and respects max;
   StatAdd clamps; Roll edge cases 0 and 1; BadMoodle maps 0 to 0.5 and 1 to 0.

## Acceptance

- Suite green, no numeric expectation changed.
- `grep -rn "^local function clamp01\|^local function floorUp\|^local function roll\|^local function randRange\|^local PARTS = {" DanTraits/`
  returns nothing.
- `grep -c "player:isAsleep()" DanTraits/42/media/lua/shared/*.lua` totals 1
  (the util).

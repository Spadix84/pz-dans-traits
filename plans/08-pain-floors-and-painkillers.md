# 08. Pain floors that honour painkillers the same way

Phase 1, after 03. Sonnet.

## Problem

Three behaviours for the same "headache":
- Hangover, Caffeine, Migraine skip their PAIN floor entirely while
  `player:getPainEffect() > 0`. Binary: a tablet taken an hour ago removes a
  migraine's pain completely.
- Gluten floors PAIN regardless of painkillers.
- Concussion sets the head part's additional pain, which the game reduces
  by `painReduction`, so painkillers help proportionally. That is the right
  model.
- Alcohol.lua floors `bodyDamage.painReduction` by Drunk level, bookkept.

## Change

1. Add `DanTraits_PainFloor(player, d, source, floor, ramp)` in Util. The
   effective floor is `floor - painReduction`, never below 0, where
   `painReduction` is `player:getBodyDamage():getPainReduction()` (0..100,
   what pills and drink set). Sources register their floor for the minute in
   `d.painFloors[source]`; the maximum of the registered floors is applied
   once, at the end of the minute cadence (a system at order 95), through
   `DanTraits_FloorUp(stats, PAIN, effectiveMax, ramp)`. Floors are max-like
   today by accident; this makes it explicit and gives the dashboard a
   "who is hurting" list.
2. Hangover, Caffeine, Migraine and Gluten call it. Dependent's shakes ADD
   pain per tick; keep that as an add, not a floor. Remove the `meds <= 0`
   guards in the three files.
3. Migraine's "painkillers taken once shorten the attack" stays and still
   reads `getPainEffect`.
4. Tests: in each file's test, a pain reduction of 30 lowers a 60 floor to
   30, not to 0; a floor of 15 with reduction 30 does nothing. Add to
   `test_util.lua` the max-of-floors rule with two sources.

## Acceptance

- Suite green.
- `grep -rn "getPainEffect" DanTraits/42/media/lua/shared` finds only
  Migraine's one-time shortening.

# 19. Mod-data key hygiene

Phase 3. Sonnet. Touches saves: ship with a migration and say so in the
commit.

## Problem

Everything lives flat in `player:getModData().DanTraits`. Most keys carry a
system prefix (`nic*`, `alc*`, `ho*`, `caf*`, `mig*`, `inf*`, `wc*`,
`blood*`, `cc*`, `hb*`, `an*`, `art*`, `dia*`, `asthma*`, `mdd*`, `gluten*`,
`vit*`, `sl*`). Dependent uses unprefixed `withdrawing`, `dryHours`,
`depTolerance`; Positives uses `isLastSick`, `earlyRiserApplied`,
`mealPrepperApplied`; GymRegular `gymRegularApplied`; Sleep
`deepSleeperWakeful`; Age `ageApplied`, `ageBand`; BadDay `badDayApplied`,
`badDayFireDone`. `DanTraits/tools/dashboard.py` keeps a hand-maintained
`shown` set of keys to hide from the "All mod data" card, which must be
edited every time a field is added.

## Change

1. Rename to prefixes: `withdrawing -> alcWithdrawing`, `dryHours -> alcDryHours`,
   `depTolerance -> alcMeter`; `isLastSick` goes away in plan 05;
   `earlyRiserApplied -> posEarlyRiser`, `mealPrepperApplied -> posMealPrepper`;
   `gymRegularApplied -> gymApplied`; `deepSleeperWakeful -> slWakefulGranted`;
   the rest are already prefixed (`age*`, `badDay*`).
2. Migration in core, once per load, on `OnGameStart`: a table
   `RENAMES = { withdrawing = "alcWithdrawing", ... }`; for each old key
   present and new key absent, copy and clear. Log one line with the count.
3. The dashboard: replace the `shown` set with grouping by prefix. In the
   page's JS, derive the group from the leading lowercase run of the key
   (`alc`, `nic`, ...), map known prefixes to card titles in one small
   table, and render an "Other" card for the rest. Delete the `shown` set.
4. Telemetry's `DanTraits_RunCommand("set ...")` and the tests that read
   keys by name (`grep -rn "depTolerance\|dryHours\|withdrawing" tests/`)
   are updated.
5. README "Layout" section: one line saying mod data is one table with a
   prefix per system.

## Tests

`tests/test_core.lua`: the migration renames and does not clobber a new key
that already exists. `tests/test_alcoholic.lua` and `test_hangover.lua` use
the new names.

## Acceptance

- Suite green. `grep -rn "shown=new Set" DanTraits/tools/dashboard.py`
  finds nothing. An old save loaded in game logs the migration line once.

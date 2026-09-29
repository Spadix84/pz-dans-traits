# 17. MDD relief thresholds and the newer systems

Phase 2. Sonnet. After plan 07.

## Problem

- MDD's drink relief triggers at a flat intoxication (`> 0.05`), which
  Dependent calls "not enough" at high tolerance: an Alcoholic gets MDD's
  relief from a sip that does nothing for their withdrawal.
- MDD's smoke relief keys off vanilla `getTimeSinceLastSmoke` going down.
  Smoker's rework resets that clock on becoming a smoker
  (`wakeWithdrawalClock`) and nicotine gum sets it to a fraction
  (`DanTraits_ChewNicotineGum`), so gum, and the moment of becoming a smoker,
  count as a cigarette for MDD. Decide: gum is a lesser relief, becoming a
  smoker is none.

## Change

1. Drink relief. In `mddRelief`, the drink term uses
   `DanTraits_Intoxication(player) > DRINK.tipsy + MDD_TOLERANCE_NEEDS * tolerance`
   where `tolerance = DanTraits_AlcoholTolerance(player)` (0 for
   non-Alcoholics) and MDD_TOLERANCE_NEEDS = 0.3. Same for the severity
   creep in `updateMddTen` (drinking still deepens the episode; the
   threshold for "drinking" is the same).
2. Smoke relief. Stop reading the vanilla clock. Smoker's `applyDose`
   already runs after every dose: have it call
   `if DanTraits_MddOnSmoke then DanTraits_MddOnSmoke(player, dose, smoked) end`.
   MDD defines it: sets `mddSmokeTimer = MDD_SMOKE_MINUTES * min(1, dose)`.
   Gum: `DanTraits_ChewNicotineGum` calls the same with `dose = 0.4, smoked = false`.
   Delete `mddLastSmokeSince` bookkeeping.
3. Header comment; README MDD row unchanged in spirit ("a cigarette" still
   helps; add "a piece of nicotine gum a little").

## Tests

`test_mdd.lua`: an Alcoholic stub at tolerance 1 gets no drink relief at
intoxication 0.2 and gets it at 0.4; `DanTraits_MddOnSmoke` sets the timer;
gum sets a shorter one. `test_smoker.lua`: a dose calls the stub.

## Acceptance

- Suite green. `grep -n "getTimeSinceLastSmoke" DanTraits/42/media/lua/shared/DanTraits_MDD.lua` finds nothing.

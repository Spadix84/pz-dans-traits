# 14. Hallucinations read the mod's own signals

Phase 2. Sonnet. Run with plan 10 (fever term) or after it.

## Problem

`schizoChance` in `DanTraits_Hallucinations.lua` reads only vanilla stress,
unhappiness, fatigue and the clock. The mod's own signals that should push
it, sleep debt, concussion, alcohol withdrawal, fever, do nothing; only
Alcoholic's delirium calls episodes directly.

## Change

1. Add to `schizoChance`, each guarded on the getter existing:
   - `SCHIZO_SLEEP_DEBT_WEIGHT * DanTraits_SleepDebt(player)`, suggested 0.25
   - `SCHIZO_CONCUSSION_WEIGHT * DanTraits_ConcussionStrength(player)`, suggested 0.2
   - `SCHIZO_WITHDRAWAL_WEIGHT * w` where `w` is Alcoholic withdrawal
     strength (`d.alcW` when `d.withdrawing`; expose
     `DanTraits_AlcoholWithdrawal(player)` from Dependent), suggested 0.3
   - fever from plan 10 if not already there
2. Keep the Alcoholic delirium direct calls; they are the "certain" path.
3. The panic-bout episode is the harshest; during a concussion or fever, do
   not pick it (the character is already down): map `roll < 15` to a whisper
   in those states.
4. Header comment; README Hallucinations row.

## Tests

`test_phantom.lua` is about the charge; add a small `test_hallucinations.lua`
(or extend) that loads the file with stubs for the four getters and asserts
`schizoChance` (export it as `DanTraits_SchizoChance`) rises by each weight.

## Acceptance

- Suite green.

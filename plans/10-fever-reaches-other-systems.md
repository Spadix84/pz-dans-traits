# 10. Fever reaches other systems

Phase 2. Sonnet. Touches Sleep, Migraine, Diabetes, Hallucinations, Asthma;
coordinate with 13 and 14 (they touch Migraine and Hallucinations too: run
this one first, or the same agent runs 10, 13, 14).

## Problem

`DanTraits_Infection.lua` exports `DanTraits_InfectionFever(player)` (0..1)
and nothing reads it. Fever sets SICKNESS, fatigue and thirst and stops there.

## Change

Every reader guards `if not DanTraits_InfectionFever then return nil end`
and reads it inside pcall; Infection may be sandboxed off.

1. Sleep: a fever is a bad night. In `DanTraits_Sleep.lua` add hooks
   `nightQuality` x (1 - SL_FEVER_CUT * fever), suggested 0.3, and
   `sleepWake` x (1 + SL_FEVER_WAKE * fever), suggested 0.5. Fever at the
   moment the night is scored is close enough.
2. Migraine: fever is a trigger. In `migraineChance` add
   `MIG_FEVER * fever`, suggested 2.0 (same scale as MIG_HANGOVER).
3. Diabetes: illness raises blood sugar ("sick day rules"). In
   `updateDiabetesMinute` add `g = g + DIA_FEVER_RISE * fever` per minute,
   suggested 0.1 (about 6 an hour at full fever; T2 setpoint pulls back).
4. Hallucinations: delirium. In `schizoChance` add `SCHIZO_FEVER_WEIGHT * fever`,
   suggested 0.3, so a septic character with the trait hears things. For
   everyone else, sepsis itself (score >= INF_SEPSIS) calls a phantom
   episode from Infection at a small chance per minute the way Alcoholic's
   delirium does (`DanTraits_Episodes`, `INF_DELIRIUM = 0.02`), guarded by
   `if not DanTraits_Episodes`.
5. Asthma: fever irritates the airway. In the build block add
   `ASTHMA_FEVER_RATE * fever` per minute, suggested 0.004, counted as
   passive (no mask helps).
6. README: extend the "Wound infection" paragraph with one sentence: "A
   fever makes for a bad night, brings on migraines, raises blood sugar and
   irritates asthma; sepsis brings delirium."

## Tests

One case in each reader's test: stub `DanTraits_InfectionFever = function() return 1 end`
and assert the multiplier or added term. Infection's test: sepsis with a
stubbed `DanTraits_Episodes` records an episode over enough minutes with a
seeded roll.

## Acceptance

- Suite green. `grep -rn "DanTraits_InfectionFever" DanTraits/` finds
  Infection plus five readers.

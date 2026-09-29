# 09. Infection hook subscribers

Phase 2. Sonnet. Independent of the other phase 2 plans.

## Problem

`DanTraits_Infection.lua` runs two hooks that nothing subscribes to:
`infectionHazard(h, player, part)` (chance per hour a wound takes an
infection, in `hazardOf`) and `infectionGrowth(k, player)` (multiplier on
the local level's climb and on the whole-body score's climb). The textbook
modifiers all live in this mod already.

## Change

Each subscriber is a `DanTraits_AddHook` at the bottom of its own file, next
to its other hooks, guarded by its trait check, returning `nil` when it has
nothing to say. Constants at the top of the file with the usual comment.

1. Diabetes (`DanTraits_Diabetes.lua`): high blood sugar feeds infection and
   slows healing.
   - `infectionHazard` x (1 + DIA_INF_HAZARD * t), `infectionGrowth` x (1 + DIA_INF_GROWTH * t),
     where `t` is 0 at glucose <= 180 rising to 1 at 350 (reuse `DIA_HIGH`).
     Suggested DIA_INF_HAZARD = 1.0, DIA_INF_GROWTH = 0.5.
2. Vitality (`DanTraits_Vitality.lua`): Run Down invites infection; Thriving
   fights it. `infectionHazard` x (1 - VIT_INF_HAZARD * e), `infectionGrowth`
   x (1 - VIT_INF_GROWTH * e), e = `DanTraits_VitalityEffect`. Suggested
   0.25 each. Add both to the "what the traits read" constant block.
3. Anemia (`DanTraits_Anemia.lua`): short of iron the body fights slower.
   `infectionGrowth` x (1 + AN_INF_GROWTH * deficit), suggested 0.3.
4. Smoker (`DanTraits_Smoker.lua`): smoking slows wound healing; use the
   meter for Smokers only. `infectionGrowth` x (1 + NIC_INF_GROWTH * meter),
   suggested 0.2, and the unstitched deep wound heal rate in WoundCare if
   plan 15 has added a `woundHeal` hook; otherwise leave that for 15.
5. Infection's header comment gets a line listing who subscribes.
6. README: one clause each in the Diabetes, Vitality, Anaemic and Smoker
   rows, and in the "Wound infection" paragraph ("Diabetes, Vitality, iron
   and smoking count").

## Tests

`tests/test_infection.lua` already builds a wounded part; add a case per
subscriber: load the subscriber file too, set its state (glucose 350,
vitality 0.9, iron 0, nicMeter 1), and assert `DanTraits_InfectionHazard` or
the level climb changes by the factor. Each subscriber file's own test gets
one assertion that the hook returns nil without the trait.

## Acceptance

- Suite green. `grep -rn 'AddHook("infection' DanTraits/` finds four files.

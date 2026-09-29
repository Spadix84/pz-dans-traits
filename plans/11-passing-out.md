# 11. Passing out: hypoglycemia, asthma attack, alcoholic seizure

Phase 2. Sonnet.

## Problem

`DanTraits_Faint.lua` is used by shock, concussion and Fear of Blood only.
Hypoglycemia tier 3 drains health instead of dropping the character. A
tier-4 asthma attack never does. Alcoholic's `seize()` in
`DanTraits_Dependent.lua` carries its own copy of the fall code (`setBumpType`,
`BumpFall` variables) instead of calling `DanTraits_Collapse`, and a seizure
never reaches Concussion.

## Change

1. Diabetes. At low tier 3 (glucose under 40): each minute a chance
   `DIA_LOW_FAINT` (suggested 0.04) of `DanTraits_PassOut(player, minutes, "UI_DanTraits_DiaBlackout")`
   with minutes from `DIA_LOW_FAINT_MIN = { 5, 20 }`, shallow (a wound wakes
   you), not more than once in `DIA_LOW_FAINT_GAP = 30` minutes (`d.diaFaintGap`).
   Glucose keeps falling while out; the health drain stays. Keep the vague
   halo messages; the blackout is not one of them. New text key
   `UI_DanTraits_DiaBlackout` = "You come round on the floor, shaking".
   Guard `if not DanTraits_PassOut`.
2. Asthma. During an attack (tier 4) with endurance at 0 for
   `ASTHMA_FAINT_AFTER_MIN = 3` consecutive minutes, a chance
   `ASTHMA_FAINT = 0.15` per minute of passing out for `{ 2, 5 }` minutes,
   deep (you stay down), key `UI_DanTraits_AsthmaBlackout`. Passing out ends
   the exertion so irritation decays at the attack rate; do not clear the
   attack. Once per attack (`d.asthmaFainted`, cleared when the attack ends).
3. Dependent. Replace the body of `seize()`'s fall with
   `if DanTraits_Collapse then DanTraits_Collapse(player) end` and after it,
   if `DanTraits_KnockHead` exists, `DanTraits_KnockHead(player, ALC_SEIZE_KNOCK, ALC_SEIZE_SCORE)`
   with suggested 0.3 and 0.35: a fit on a hard floor can concuss. Keep the
   pain, panic and fatigue.
4. Faint. `DanTraits_PassOut` returns false while someone is already out;
   callers above must not spend their gap when it returns false. Check each
   caller does `if DanTraits_PassOut(...) then d.xGap = ... end`.
5. README: Diabetes rows ("a bad low can put you on the floor"), Brittle
   Asthma row ("an attack that empties you can black you out"), Alcoholic
   row ("a seizure can concuss").

## Tests

- `test_diabetes.lua`: glucose 30, stubbed `DanTraits_PassOut` recording
  calls, seeded roll: a call within the gap window, then none until the gap
  passes; the `false` return does not spend the gap.
- `test_asthma.lua`: attack with endurance 0 for three minutes then a faint;
  once per attack.
- `test_alcoholic.lua`: a seizure calls the stubbed Collapse and KnockHead.

## Acceptance

- Suite green. `grep -n "BumpFall" DanTraits/42/media/lua/shared/*.lua`
  finds only Faint.lua.

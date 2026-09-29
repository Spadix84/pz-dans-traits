# 15. Vitality's reach: infection, concussion, deep wounds, lungs

Phase 2. Sonnet. The infection part overlaps plan 09; whichever runs second
merges.

## Problem

Vitality shapes asthma, diabetes, MDD, red cells and colds, but not the
body's fight against infection, concussion healing, unstitched deep-wound
healing or lung healing. Each is a one-line multiplier once the target
offers a hook.

## Change

1. Offer hooks where none exist (each `DanTraits_RunHooks(name, base, player, d)`):
   - Infection: `infectionFight` on `INF_S_FIGHT` (the per-day clearance
     with nothing spreading). `infectionGrowth` already exists.
   - Concussion: `concussionHeal` on the per-minute heal in
     `updateConcussionMinute`.
   - WoundCare: `woundHeal` on the unstitched deep wound rate (the
     `WC_UNSTITCHED` scaling) and on the fracture heal if it is ever moved
     here; today just the deep wound.
   - Smoker: `lungHeal` on the per-minute lung recovery.
2. Vitality subscribes with `e = DanTraits_VitalityEffect(player)`:
   `infectionFight` x (1 + 0.3e), `concussionHeal` x (1 + 0.25e),
   `woundHeal` x (1 + 0.25e), `lungHeal` x (1 + 0.25e). Constants in the
   "what the traits read" block with comments.
3. Smoker: `woundHeal` x (1 - 0.2 * meter) for Smokers (moved here from
   plan 09 if that plan deferred it).
4. Vitality header comment and README Vitality paragraph: "and how fast the
   body clears an infection, a concussion, an unstitched wound and a
   smoker's lungs".

## Tests

One case per target in its own test: vitality effect stubbed to +1 and -1,
the rate changes by the factor. `test_vitality.lua`: the four hooks return
nil at neutral vitality.

## Acceptance

- Suite green. `grep -rn 'RunHooks("infectionFight"\|RunHooks("concussionHeal"\|RunHooks("woundHeal"\|RunHooks("lungHeal"' DanTraits/`
  finds all four.

# 13. Migraine triggers: caffeine withdrawal (and fever, see 10)

Phase 2. Haiku or Sonnet. Small. Run after or with plan 10.

## Problem

`migraineChance` in `DanTraits_Migraine.lua` reads sleep debt, thirst,
stress, bright light, hangover, nicotine withdrawal and concussion. Caffeine
withdrawal is the textbook trigger and is missing. Caffeine exports
`DanTraits_CaffeineWithdrawal(hours)`, a curve, not a per-player getter.

## Change

1. Caffeine: add `DanTraits_CaffeineWithdrawalOf(player)` returning
   `d.cafWithdraw or 0` for a Caffeine Dependent, 0 otherwise (guard
   `hasTrait`).
2. Migraine: `chance = chance + MIG_CAFFEINE * withdrawal`, suggested 2.0,
   guarded on the getter existing.
3. Header comment and README Migraines row ("caffeine withdrawal").

## Tests

`test_migraine.lua`: stub the getter to 1, chance rises by MIG_CAFFEINE.
`test_caffeine.lua`: getter returns 0 without the trait, the current
withdrawal with it.

## Acceptance

- Suite green.

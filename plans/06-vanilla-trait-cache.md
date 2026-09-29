# 06. Cache vanilla trait lookups

Phase 1. Haiku or Sonnet. Small.

## Problem

`DanTraits_HasVanillaTrait` (core) walks `getKnownTraits()` with `tostring`
and `string.lower` on every element, every call. Infection calls it twice
per wounded body part per minute inside `hazardOf`; Sleep three times a
minute in `wakeMultiplier` plus its hooks; Smoker's `isSmoker` several times
a minute and per dose; Vitality's `sleepNeed` once a night; Age, Hemophobia,
Positives once a minute.

## Change

1. In core, keep a per-player snapshot `{ at = gameMinute, set = { ["base:smoker"] = true, ... } }`
   in a module local (single player: one entry, keyed by the player object).
   `hasVanillaTrait(player, id)` rebuilds the set when the game minute has
   changed or when `DanTraits_TraitsChanged(player)` was called since. The
   rebuild cost is one walk per minute.
2. Every place that adds or removes a trait at runtime calls
   `DanTraits_TraitsChanged(player)` right after: Smoker `setSmoker`,
   Dependent `setTrait`, Sleep `grantWakeful`, Hemophobia's console command.
   Also invalidate on `OnCreatePlayer` and `OnGameStart`.
3. `DanTraits_HasTrait` (registry traits) is one Java call; leave it.
4. Test, in `tests/test_core.lua`: a stubbed `getKnownTraits` counts its
   calls; ten lookups in one minute walk once; `TraitsChanged` forces a
   re-walk; a trait added without the call is seen the next minute.

## Acceptance

- Suite green. Infection's per-part behaviour unchanged (test_infection).

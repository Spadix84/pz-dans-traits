# 21. A Really Bad Day after the health overhaul

Phase 3. Sonnet for the code; the user for the play test. Do last.

## Problem

`DanTraits_BadDay.lua` predates blood, infection, wound care, hangovers and
the alcoholism meter. Its opening now means:
- a deep shard wound in the groin: a 1.5x bleed site in Blood; the lodged
  shard bleeds through a bandage at 0.35 and carries the top infection
  hazard (0.06 an hour) until it is pulled, and pulling it is a Fear of
  Blood faint roll;
- intoxication 100: a full Drunk 4, so the drink-relief system floors pain
  reduction at 80 (which is what makes the shard survivable), but Hangover
  arms a maximum hangover for when it wears off, and the alcoholism meter
  gains its daily cap;
- a cold at strength 50: with plan 10, a fever-like sickness does not stack
  with it, but check.

With Hemophilia the start is probably unwinnable; with Anaemic the blood
never comes back in time.

## Change

1. Instrument first, then decide. Add a console command `badday` to
   Telemetry that re-applies the start to the current character (calls the
   create handler with the applied flags cleared) so the opening can be
   replayed without a new character.
2. Play it three times with the dashboard open: plain, plus Hemophilia,
   plus Fear of Blood. Record blood volume at the moment the shard is out
   and bandaged, time to first infection roll, and whether the hangover
   lands.
3. Then, in code, choose from these dials (do not change all of them):
   - `generateDeepShardWound` on the groin stays, but Bad Day sets the
     shard's bleeding time to a fixed low value (3) so the opening bleed is
     a scare, not a death; the infection hazard stays;
   - a starting bandage in the inventory (a Bad Day survivor grabs a towel);
   - `Hangover`: Bad Day marks `d.hoLoad = 0` after applying intoxication so
     the opening drunk does not arm a hangover, or leaves it and the README
     says so (it is a *bad* day);
   - Dependent: the day's cap already limits the meter; leave it;
   - Hemophilia plus Bad Day: either make the two traits mutually exclusive
     in `scripts/DanTraits.txt` (cheapest, honest) or accept it.
4. README Bad Day row and the file header say what the opening costs under
   the overhaul.

## Tests

`tests/test_badday.lua` (new; the file has none): the create handler applies
once, is idempotent on reload, and whichever dials were chosen hold (a
bleeding time of 3, a bandage present).

## Acceptance

- Suite green. The user has played the opening under the chosen dials and
  survived it at least once without Hemophilia.

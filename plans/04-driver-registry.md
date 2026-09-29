# 04. One minute driver, one frame driver, explicit order

Phase 1, after 03. Sonnet.

## Problem

Twenty files register `Events.EveryOneMinute` and ten register
`Events.OnPlayerUpdate`, each with the same preamble
(`getSpecificPlayer(0)`, `isDead`, `isLocalPlayer`, `traitData`, optional
`DanTraits_Track`). The order they run in is file load order, and that order
silently decides which system sees which other system's floors and stat
writes in the same minute. Core already has a ten-minute driver
(`DanTraits.lua`, `onTenMinutes`) that three traits use through globals while
Migraine registers its own; the two designs coexist. The explicit `track()`
wrappers inside the five health files are redundant with Attrib, which wraps
every `Events.Add` from a DanTraits file by filename.

## Change

1. In core, replace the ten-minute driver with a registry that owns three
   cadences:

   ```lua
   -- DanTraits_Every(cadence, label, fn, order)
   --   cadence: "minute" | "ten" | "frame"
   --   label:   the system name for attribution ("Blood")
   --   fn(player, d)
   --   order:   number; lower runs first; default 100
   ```
   Core registers ONE `EveryOneMinute`, ONE `EveryTenMinutes` and ONE
   `OnPlayerUpdate` handler. Each does the preamble once, sorts the
   registrations by order then label, and runs each through
   `DanTraits_Track(label, fn, player, d)` inside `pcall`, so one system's
   error never stops the next. Attrib keeps wrapping by filename for
   everything else (OnTick, OnWeaponSwing, OnPlayerGetDamage). Dead player:
   return. Frame cadence: also skip when `player.isLocalPlayer` is false.

2. Order. Put this table in a comment in core:

   | order | minute systems |
   |---|---|
   | 10 | Sleep (light reading, wakes) |
   | 20 | Blood (loss this minute, sets bloodLossMin) |
   | 21 | Hemophilia (holds bleed times) |
   | 22 | WoundCare (reads BloodPartRate) |
   | 23 | Infection |
   | 24 | Concussion |
   | 25 | FearOfBlood (reads bloodLossMin) |
   | 40 | Alcohol, Hangover, Caffeine, Smoker, Anemia, Arthritis, Asthma, Diabetes, Gluten, Migraine, MDD (floors and rates; among themselves by label) |
   | 80 | Positives (Iron Stomach) |
   | 90 | Vitality (reads everything above, scores the night, applies lifts) |

   Frame: Faint stays on OnTick. Frame systems: Alcohol (panic decay),
   Arthritis, Asthma, Anemia, Blood, Concussion, Smoker, Vitality, WoundCare
   (movement sampling). After plan 05 the endurance ones collapse into one.

3. Convert every file: delete its `onXMinute` / `onXPlayerUpdate` wrappers
   and its `Events.EveryOneMinute.Add` / `Events.OnPlayerUpdate.Add` /
   `Events.EveryTenMinutes.Add`; register with `DanTraits_Every`. Keep the
   `DanTraits_updateXMinute = updateX` exports; the tests call them. Remove
   the redundant `track(...)` calls in Blood, Infection, WoundCare,
   Concussion, Hemophobia. Migraine's ten-minute roll joins the "ten"
   cadence; Dependent, MDD and Hallucinations stop being called through
   globals from core.

4. Tests. In the harness, `H.minute()` fires core's single handler; tests
   that fetched "the" EveryOneMinute handler use that. Add
   `tests/test_driver.lua`: registrations run in order; a throwing system
   does not stop the next; a dead player runs nothing; frame skips
   non-local players.

## Acceptance

- Suite green.
- `grep -rn "Events.EveryOneMinute.Add\|Events.OnPlayerUpdate.Add\|Events.EveryTenMinutes.Add" DanTraits/42/media/lua`
  finds only core.
- The dashboard's attribution card still credits each system by name
  (labels unchanged).

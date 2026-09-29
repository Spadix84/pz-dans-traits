# 12. Smoker and Asthma, and one cough

Phase 2. Sonnet.

## Problem

A cigarette adds no airway irritation for a Brittle Asthma character, and
damaged lungs (`nicLungs`) neither slow asthma recovery nor raise the
exertion build. The two coughs are separate mechanisms with separate gap
timers: Asthma uses `playerVoiceSound("Cough")` plus `addSound`
(`DanTraits_AsthmaCough`), Smoker uses `player:triggerCough()` with a fallback
to the asthma one; both can fire in the same minute.

## Change

1. One cough. Move the cough primitive to Util or core:
   `DanTraits_Cough(player, radius, why)`: tries `triggerCough()` (the game's
   own, heard by zombies at its own radius), falls back to voice sound plus
   `addSound` at `radius`; enforces one global gap `d.coughGap` of
   `COUGH_GAP_MIN = 3` minutes across all callers; records `d.coughs`,
   `d.lastCoughWhy`. Asthma and Smoker call it. Asthma's tier-4 burst (two or
   three coughs over the minute through `DanTraits_Later`) bypasses the gap
   by passing `force = true`.
2. Smoker to Asthma. In `DanTraits_Asthma.lua` add an `eat`/`prePill`
   subscriber? No: simpler and already routed, Smoker's `applyDose` calls
   `if DanTraits_AsthmaSmoked then DanTraits_AsthmaSmoked(player, dose) end`
   after the dose lands. Asthma defines it: irritation `+ ASTHMA_SMOKE * dose`,
   suggested 0.12 per cigarette, no mask help, notified through the normal
   tier notices.
3. Lungs to Asthma. In `updateAsthmaMinute`, read `d.nicLungs or 0`:
   exertion and sprint build x (1 + ASTHMA_LUNGS_BUILD * lungs), decay
   x (1 - ASTHMA_LUNGS_DECAY * lungs); suggested 0.5 and 0.3. Read the field
   directly; both live in the same mod-data table and Smoker keeps it for
   everyone who has ever smoked.
4. Header comments in both files; README Brittle Asthma row: "smoking, and
   a smoker's lungs, make it worse".

## Tests

- `test_asthma.lua`: a stubbed `player:triggerCough` counts; two tier-2
  cough windows in one minute produce one cough; `DanTraits_AsthmaSmoked`
  adds irritation; `nicLungs = 1` speeds the build.
- `test_smoker.lua`: a dose calls the stubbed `DanTraits_AsthmaSmoked`.

## Acceptance

- Suite green. `grep -rn "playerVoiceSound\|triggerCough" DanTraits/` finds
  only the shared cough.

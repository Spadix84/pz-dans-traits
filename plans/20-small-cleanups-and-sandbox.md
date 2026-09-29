# 20. Small cleanups and sandbox toggles

Phase 3. Haiku or Sonnet. A grab bag; one commit per bullet is fine.

## Items

1. WoundCare's `say(player, key, part)` calls `HaloTextHelper` directly, so
   "Stitches tore", "Dressing spent", "Bad set" never reach the story event.
   Add `DanTraits_NotifyFmt(player, textKey, ...)` to core (formats with
   `getText(key, ...)`, halo, story with the formatted text) and use it.
   Check `ISDiabetesAction` too: it hand-rolls the halo and story; switch it.
2. Dead fallbacks: `local notifyGood = DanTraits_NotifyGood or DanTraits_Notify`
   in Blood, Infection, Concussion. `DanTraits_NotifyGood` is in core now;
   read it directly.
3. Telemetry: the `drop` command says "fumbler not loaded" and the text key
   is `UI_DanTraits_FumblerDrop`. Rename the message to Arthritis; keep the
   key (translations) but add a comment.
4. Sandbox toggles for the everyone-systems that lack one: Vitality
   (`VIT_ENABLED` is a constant), sleep and light, hangovers, drink relief,
   age already has one. Add `DanTraits.VitalityEnabled`, `SleepLightEnabled`,
   `HangoverEnabled`, `DrinkReliefEnabled` to `sandbox-options.txt`,
   `Sandbox.json` (title plus tooltip each, same wording style), and read
   them with `DanTraits_SandboxOn` at the top of each minute/frame update.
   When Vitality is off, `DanTraits_VitalityEffect` returns 0 so every
   reader is neutral.
5. The three vanilla-definition overrides (`base:nightvision`,
   `base:hemophobic`, `base:smoker` in `scripts/DanTraits.txt`) replace the
   whole block, so any field a game update adds to those vanilla definitions
   is lost. Add a comment block above each listing the vanilla fields copied
   and the game version they were copied from, so the next game update has
   a checklist. No code change.
6. README: add Cat's Eyes (re-costed 3 to 1) as a row in the trait table;
   fix `UI_trait_DanHemophiliadesc` in `Translate/EN/UI.json`, which still
   says bleeding "costs far more health" while the README says blood loss.
7. `check_api.py` passes silently when the jar is not found and
   `run_tests.py` hides that line. Make the skip print "SKIP check_api.py
   (no jar at ...)" and have `run_tests.py` show it. Not a failure.

## Tests

- `test_woundcare.lua`: the tear notice appears in the story capture.
- `test_vitality.lua`: with `SandboxVars.DanTraits.VitalityEnabled = false`
  the effect is 0 and nothing moves.

## Acceptance

- Suite green. `grep -rn "HaloTextHelper" DanTraits/42/media/lua/shared`
  finds only core.

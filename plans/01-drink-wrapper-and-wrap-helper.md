# 01. Drink wrapper collision, and a wrap helper

Phase 0. Standalone. Small. Haiku or Sonnet.

## Problem

`DanTraits_Alcohol.lua` (wrapDrinkAction, around line 69) and
`DanTraits_Diabetes.lua` (wrapDrinkAction, around line 360) both wrap
`ISDrinkFluidAction.updateEat` and both guard with the same flag,
`ISDrinkFluidAction.DanTraitsWrapped`. Whichever runs first wraps; the other
returns early and its wrapper is never installed. Both files call their
wrapper at load and again on `OnGameStart`, so exactly one of the two ever
works in game. If Alcohol wins: diabetes drink carbs, `DanTraits_VitalityOnDrink`
and the `drink` hook (Caffeine Dependent's coffee, tea, cola) are dead. If
Diabetes wins: the drink-relief undo is dead and any sip is a full
painkiller and beta-blocker dose again.

No test loads both files, so the suite cannot see it.

## Change

1. Add to `DanTraits.lua` (core) one helper that chains instead of guarding:

   ```lua
   -- Wrap a method on a game class so several files can each add their own
   -- layer. `tag` is unique per caller (file + purpose); wrapping twice with
   -- the same tag is a no-op, so calling at load and again on OnGameStart is
   -- safe. `fn(original, self, ...)` must call original and return its result.
   function DanTraits_Wrap(class, method, tag, fn)
       if not class or type(class[method]) ~= "function" then return false end
       class.DanTraitsWraps = class.DanTraitsWraps or {}
       local key = method .. ":" .. tag
       if class.DanTraitsWraps[key] then return true end
       class.DanTraitsWraps[key] = true
       local original = class[method]
       class[method] = function(self, ...) return fn(original, self, ...) end
       return true
   end
   ```

2. Convert the two drink wrappers to it. Alcohol: tag `"alcohol-relief"`,
   body = snapshot meds, call original, restore if alcoholic. Diabetes: tag
   `"drink-intake"`, body = read amount/carbs/kcal, call original, fire
   `DanTraits_DiaOnDrink`, `DanTraits_VitalityOnDrink`, the `drink` hook.
   Keep the `wrapDrinkAction()` at load plus `Events.OnGameStart.Add` shape.
   Delete the `DanTraitsWrapped` flag lines in both.

3. Convert the other guarded wrappers to the helper so the pattern is
   uniform: core's `ISEatFoodAction` (isValidStart, isValid, complete, eat)
   and `ISTakePillAction.complete`; `DanTraits_WoundCare.lua` `ISSplint.complete`;
   `DanTraits_Hemophobia.lua` `wrapComplete`, `wrapDuration`, `wrapSplint`
   (the `ISSplint.new` wrap fits: tag `"fear-splint-slow"`);
   `DanTraits_Client.lua` `CharacterCreationProfession.isTraitEnabled`.
   Leave `DanTraits_HealthPanel.lua` alone: it deliberately wraps whichever
   `doDrawItem` is installed at game start and identity-checks it.

4. Tests. Extend `tests/test_alcohol.lua` to also load `DanTraits_Diabetes`
   (copy its stubs from `tests/test_diabetes.lua`) and assert that after one
   drink of an alcoholic fluid BOTH the meds snapshot is restored AND the
   `drink` hook fired (register a hook that records the call). Add the
   mirror check to `tests/test_diabetes.lua`: load Alcohol too, assert carbs
   land. Add `tests/test_core.lua`: `DanTraits_Wrap` twice with the same tag
   wraps once; two different tags both run, innermost first.

## Acceptance

- Suite green.
- `grep -rn "DanTraitsWrapped\|DanTraitsFearWrapped\|DanTraitsFearSlow" DanTraits/`
  returns nothing.
- In game: as a Caffeine Dependent, drinking coffee clears "Craving caffeine";
  as anyone, a sip of whiskey no longer clears panic like a beta blocker.

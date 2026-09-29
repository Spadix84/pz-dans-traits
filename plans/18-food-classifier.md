# 18. One food classifier

Phase 3. Sonnet. Bigger; do it in one worktree with all five consumers.

## Problem

Six name lists classify food, with overlapping words and different
safe-lists:

| file | list | purpose |
|---|---|---|
| Vitality | `JUNK_WORDS`, `JUNK_SAFE`, plus packaged/fresh/cooked/ingredients | diet grade |
| Gluten | `GLUTEN_WORDS`, `GLUTEN_SAFE_PART`, `GLUTEN_SAFE_EXACT` | wheat |
| Diabetes | `DIA_FAST_WORDS` | fast carbs |
| Vegetarian | `MEAT_FOOD_TYPES`, `MEAT_WORDS`, `MEAT_SAFE_PART`, evolved-dish extras | meat |
| Anemia | `MEAT_TYPES`, `GREENS_TYPES`, `EGG_TYPES` on `foodType .. name` | iron |
| Caffeine | `CAF_FOOD`, `CAF_CHOCOLATE` prefix, `CAF_FLUID`, `CAF_PILL` | caffeine |

"cookie", "cake", "donut", "chocolate" and "burger" appear in two or three
lists. Each item is re-scanned on every bite.

## Change

1. New `DanTraits/42/media/lua/shared/DanTraits_Food.lua`, required by core
   after Util. It exports `DanTraits_FoodTags(item)` returning a memoised
   (by `item:getFullType()`, plus rotten/burnt/cooked/packaged flags that
   vary per instance and are read fresh) table:
   `{ junk, wheat, fastCarb, meat, egg, greens, iron = 0..1, caffeine = n,
      fresh, cooked, packaged, rotten, burnt, ingredients = n }`.
   One pass over the name and food type against ONE word table:
   `WORDS = { cookie = { junk = true, wheat = true, fastCarb = true }, ... }`,
   plus the safe-lists merged into per-tag `not` entries
   (`sugarcane = { junk = false }`). Evolved-dish extras contribute their
   tags (meat from a steak in a stew; wheat from pasta). Food types
   (`getFoodType`) map through a second small table.
2. Each consumer reads tags: Vitality's `DanTraits_GradeFood` uses
   `tags.junk / fresh / cooked / ingredients`; Gluten `tags.wheat`;
   Diabetes `tags.fastCarb`; Vegetarian `tags.meat`; Anemia
   `tags.iron` scaled by kcal as today; Caffeine `tags.caffeine`. Keep every
   consumer's public function (`DanTraits_IsWheat`, `DanTraits_IsMeat`,
   `DanTraits_IsFastCarb`, `DanTraits_GradeFood`) as thin wrappers so the
   tests and the client menus keep working.
3. Build the word table by UNION of the six lists, then reconcile the
   conflicts by hand and write the decision as a comment next to the word:
   e.g. `burger = { wheat = true, meat = true }`, `chocolate = { junk = true, fastCarb = true, caffeine = 15 }`.
4. Fluids stay in Caffeine (`CAF_FLUID`) and Diabetes (carbs per litre from
   the fluid properties); the classifier is for items.
5. Tests: `tests/test_food.lua` with a table of item names and the expected
   tag set, built from the existing tests' fixtures (every name they use).
   The six consumers' tests run unchanged.

## Acceptance

- Suite green with no expectation changed in the six consumers' tests.
- `grep -rn "_WORDS = {\|_TYPES = {\|_SAFE" DanTraits/42/media/lua/shared`
  finds only `DanTraits_Food.lua`.

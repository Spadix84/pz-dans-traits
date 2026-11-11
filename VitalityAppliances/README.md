# Vitality Appliances

A Project Zomboid Build 42 mod with two appliances: a countertop **Slow Cooker** and a
**Brick Smoker** you build outdoors. Part of the [Vitality Project](../README.md)
repository; both work on their own, and with the Vitality Project loaded each adds a page
to its Guide tab. Not yet on the Workshop under this name.

It replaces the two separate mods, `SlowCooker` and `BrickSmoker`, and cannot be enabled
beside them (`incompatible=` in `mod.info`). Everything a save holds is named as before:
the items are in module `Base`, the tiles are `appliances_slowcooker_01` and
`crafted_smoker_01` under the same file numbers (6742, 7318), the mod data keys and the
learned recipes are unchanged. To move a save over, swap the two old mods for this one in
its mod list.

## Slow Cooker

Fill its crock, turn it on and walk away. It takes about four times as long as a stove,
runs on grid or generator power, never burns food, and keeps it from spoiling while it's on.

- **The crock** is the cooker's stoneware insert and the only thing the cooker holds.
  A looted cooker comes with one. Moving a cooker doesn't make a new one.
- **Crock stew:** anything that goes in a vanilla stew, added from the Slow Cooker
  window (right-click the cooker) or the game's own evolved-recipe menu. The window
  takes ingredients (and the crock) from what you carry and from any container in reach,
  like the game's own crafting, and fetches them when you press Add.
- **Recipes:** nine Kentucky dishes in the window, unlocked by Cooking level, one at a
  time by a recipe card, or all at once by reading the *Kentucky Slow Cooker Favorites*
  pamphlet. A named dish has a better mood bonus than plain stew.
- **Serving:** right-click the crock: Serve a Bowl (needs an empty bowl), Move to
  Cooking Pot (needs an empty pot), or the game's Pour on Ground.
- **Vitality:** anything from the crock counts as home cooking (1.5x on the diet
  score), and each named dish counts as its own food for variety.

## Brick Smoker

Feed the firebox wood, load the chamber with meat, poultry or fish, and let it smoke.

- **Building:** Build menu, Masonry. 16 clay bricks, 3 units of mortar or concrete, a sheet
  of metal, 2 metal bars and a mason's trowel; needs Masonry 3. It must stand outdoors with
  nothing over it, or the fire won't light (and a fire that gets roofed over chokes).
- **Fuel:** wood only. Log 6 h, plank or firewood 2 h, branch or charcoal 1 h, sticks and
  twigs 15 min. The firebox holds 24 h. Putting the fire out keeps what's left.
- **Smoking:** 8 h of smoke makes a piece *Smoked* (ready to eat, keeps about two weeks);
  24 h makes it *Smoke-Dried* (jerky-like, 60% of the weight, keeps about four months).
  Nothing in the chamber spoils while the fire burns. Each piece keeps its own hunger,
  calories and macros, is named after the cut ("Smoked Venison"), and still goes in
  stews, soups and sandwiches, and in the Slow Cooker's crock.
- **Menu:** right-click the smoker, *Brick Smoker*. Hover it for the fire and each piece's
  progress. *Add Fuel* lists the wood in reach (inventory, crates, the floor) with *Fill It
  Up*; *Light Fire* uses a lighter or matches; *Put In Meat and Fish* loads everything raw
  you carry that fits; *Take Out Smoked Food* empties what's done.
- **Time away counts:** leave it lit and go; it catches up when the area loads again, as far
  as the fuel lasts.

## Layout

The two appliances share the mod folder and nothing else: each keeps its own Lua files,
global table and API, and neither needs the other's code.

| File (under `42/media/`) | |
|---|---|
| `lua/shared/SlowCooker_Core.lua`, `_Food.lua`, `_Recipes.lua`, `_Power.lua` | the cooker: cooking, keeping warm, the dishes, the generator draw |
| `lua/shared/SlowCooker_API.lua` | the cooker's public API |
| `lua/shared/TimedActions/SlowCookerActions.lua` | serve a bowl, move to a pot, add to the crock |
| `lua/server/SlowCooker_Server.lua`, `Items/SlowCooker_Distributions.lua` | finds cookers as they load, ticks them once a game minute; the loot tables |
| `lua/client/SlowCooker_Window.lua`, `_Menu.lua`, `_PowerUI.lua`, `_Client.lua` | the recipe window, the crock's menu, the generator window's line, the loot window icon |
| `lua/shared/Smoker_Core.lua` | the smoker: fuel, fire, smoking, keeping fresh, the container rule |
| `lua/shared/Smoker_API.lua` | the smoker's public API |
| `lua/shared/TimedActions/SmokerActions.lua` | add fuel, light, put out |
| `lua/server/Smoker_Server.lua` | finds smokers as they load; ticks lit ones every 10 game minutes |
| `lua/client/Smoker_Menu.lua` | the right-click menu and the loot window icon |
| `lua/client/SlowCooker_Guide.lua`, `Smoker_Guide.lua` | each one's page in the Vitality Project's Guide tab (through `DanTraits_GuideExtra`; nothing without it) |
| `lua/shared/Translate/EN/*.json` | both appliances' text, one file per kind |
| `scripts/SlowCooker_items.txt` | the cooker, the crock, Crock of Stew, the booklet and the nine recipe cards |
| `scripts/BrickSmoker_entity.txt`, `BrickSmoker_items.txt` | the Build menu recipe (`entity Brick_Smoker`); Smoked Meat/Poultry/Fish, Smoke-Dried Meat/Fish |
| `SlowCooker_tiledefinitions.tiles`, `BrickSmoker_tiledefinitions.tiles`, `texturepacks/`, `depthmaps/` | the tiles, written by each appliance's `build_pack.py` |

Elsewhere in the repository:

| | |
|---|---|
| [`API.md`](API.md) | the guide to both APIs; ships in the mod folder |
| [`art/slowcooker/`](../art/slowcooker/), [`art/smoker/`](../art/smoker/) | Blender models, render and packaging scripts |
| `tests/test_slowcooker.lua`, `tests/test_bricksmoker.lua` | offline tests of the cooking and smoking logic, run with the rest by `python tests/run_tests.py` |
| [`workshop/appliances/`](../workshop/appliances/) | the Steam page (`description.txt`, `workshop.txt`, `preview.png`) and `make_images.py`, which draws the preview and the mod icon from both appliances' art |

## For other mods

`SlowCooker_API.lua` (recipes, ingredients, bowls and pots, the power draw, events,
`isHomeCooked`) and `Smoker_API.lua` (fuel, which foods smoke and as what, your own smoked
products, times, questions about a smoker or a food, events) are loaded separately, each
with `pcall(require, ...)`. The guide is [API.md](API.md). The tests cover both.

## Deploying and publishing

```bash
python deploy.py --mod VitalityAppliances
```

copies the mod to `~/Zomboid/mods/VitalityAppliances`.

```bash
python deploy.py --workshop VitalityAppliances
```

builds `~/Zomboid/Workshop/VitalityAppliances` for the game's uploader (main menu,
Workshop). While that folder exists the game loads it instead of the `mods` copy, and a
plain deploy keeps the two the same. After editing `workshop/appliances/description.txt`,
run `python steam_desc.py appliances` from `workshop/` to rebuild `workshop.txt` and check
Steam's length limit.

The old Slow Cooker Workshop item (3835704316) still carries the `SlowCooker` mod id.
This mod has no Workshop item yet; whether it gets a new one or takes that one over is
not decided.

## In-game checklist

Not yet tested in the game as one mod. Enable Vitality Appliances (with Slow Cooker and
Brick Smoker off) and start a debug save. `console.txt` in `~/Zomboid` shows any Lua errors.

**Both together**

1. **The mod list** shows Vitality Appliances with its icon, and refuses to enable it
   beside the old Slow Cooker or Brick Smoker.
2. **Both tile sets load:** a cooker places on a counter and a smoker builds, in the same
   save, with no missing-tile squares.
3. **An old save:** one that had the two separate mods, with them swapped for this one:
   placed cookers and smokers, crocks, smoked food and learned recipes are all still there.
4. **Smoked meat in the crock:** a piece of Smoked meat is offered as a stew ingredient.

**Slow Cooker** (get one with the Lua console:
`getPlayer():getInventory():AddItem("Base.Mov_SlowCooker")`)

1. **Tiles load:** place it on a counter from the moveables menu. It should rotate
   through all four views and sit properly on the counter.
2. **Layering:** walk behind and in front of the counter. Check nothing draws through it.
3. **On/off:** with power, the loot window shows the cooker's own button and icon, plus
   Turn on. The lamp lights and the lid fogs. Without power there's no button.
4. **Cooking:** a pot of soup (50 minutes on a stove) should be done in about 3h20.
5. **Never burns:** leave it for a day or more. It should stay cooked.
6. **Save and reload while it's on:** it should still be on and still cook.
7. **Trip away:** leave until the base unloads. The food should have progressed on return.
8. **Power cut:** it should switch off and stop cooking. Turning it back on is manual.
9. **Generator:** it runs from one. Switched on, the generator's info window lists it at
   0.02 L/h (not the 0.09 every stove gets), and within a game minute the total matches.
10. **Move it:** pick it up and place it elsewhere (the crock has to come out first).
11. **Crock only:** anything but the crock is refused.
12. **Keep-warm:** a cooked dish left on for days doesn't spoil; switched off, it does.
13. **Window:** right-click the cooker, Slow Cooker... Pick Chili, tick the ingredients,
    Add to Crock. The crock comes out, gets them, goes back, named "Chili".
14. **Serve / pot / pour:** right-click the cooked crock.
15. **Unlocks:** level Cooking and see the notice; read the pamphlet and see all unlocked.
16. **Recipe cards:** read "Slow Cooker Recipe: Kentucky Burgoo" at low Cooking; burgoo
    unlocks, nothing else does.
17. **Crock name:** an empty crock reads "Slow Cooker Crock" in the inventory.

**Brick Smoker**

1. **Build menu:** Masonry lists *Brick Smoker* with its icon, name and tooltip. With the
   ingredients (or debug build-cheat) it places in all four facings and sits on its tile.
2. **Indoors:** build one under a roof: *Light Fire* is greyed out with the outdoors reason.
3. **Loot window:** the smoker shows its own button and takes only raw meat/fish and
   smoked food.
4. **Fire:** add a log, light it. The firebox glows and the chimney smokes. *Put Out Fire*
   turns both off and keeps the fuel.
5. **Smoking:** a steak in a lit smoker is *Smoked Steak* after 8 game hours and
   *Smoke-Dried Steak* after 24. Check its hunger and calories match the steak.
6. **Away and back:** leave it lit, walk far enough to unload the area, wait, come back.
7. **Save and reload while lit:** still lit, still smoking.

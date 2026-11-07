# Dan's Vanilla Fixes

A Project Zomboid (Build 42) mod of small fixes and finishing touches for the game itself.
Part of the [Vitality Project](../README.md) repository; works on its own. Not yet on the
Workshop.

- **Cold packs and coolers work.** Chill a pack in a fridge (half way) or a freezer
  (fully), or leave it out below freezing, then put it in a cooler. The cooler keeps food as
  cold as a fridge, about six hours per frozen pack (sandbox), and the packs and cooler show
  how cold they are in their names.
- **Item info in tooltips.** Read time left on skill books (and novels, with the Vitality
  Project's reading), uses left on drainables and charge on batteries, weapon numbers that
  open up with the weapon's skill, and for clothing the body parts covered and how it
  compares with what you wear (its own sandbox page).
- **Rarity colours.** Every item name is coloured by rarity (orange Legendary, purple Epic,
  blue Rare, green Uncommon, grey Common, teal Crafted), worked out from the loot lists
  when the game starts, modded items included. The tooltip names the tier; no extra column.
- **The collection.** A sidebar button opens a per-character checklist of skill books,
  recipe magazines, VHS tapes, CDs, key rings, mementos and tools; ticked items say so in
  their tooltip and are set Unwanted, so Take All leaves them.
- **Store stock.** Cigarette packs on shop shelves come full.

| Layout | |
|---|---|
| `42/media/lua/shared/DansVanillaFixes_Coolers.lua`, `client/..._CoolersClient.lua` | cold packs and coolers |
| `42/media/lua/client/DansVanillaFixes_ItemInfo.lua`, `DanShared_Tooltip.lua` | the tooltip lines (the tooltip strip is shared with the Vitality Project; deploy keeps the two copies identical) |
| `42/media/lua/client/DansVanillaFixes_ItemRarity.lua` | the rarity pass over the loot lists and the name colours |
| `42/media/lua/shared/DansVanillaFixes_Collection.lua`, `client/..._CollectionUI.lua`, `..._CollectionClient.lua` | the checklist |
| `42/media/lua/shared/DansVanillaFixes_StoreStock.lua` | full packs on shelves |
| `42/media/lua/client/DansVanillaFixes_Guide.lua` | its page in the Vitality Project's Guide tab (does nothing without it) |
| `tools/make_sidebar_icon.py` | draws the Collection button |
| `../tests/test_coolers.lua`, `test_collection.lua`, `test_raritypatch.lua`, `test_vanillaprices.lua` | offline tests |

Deploy with `python deploy.py --mod DansVanillaFixes`. Changes are logged in the
repository's [CHANGELOG.md](../CHANGELOG.md). Singleplayer for now.

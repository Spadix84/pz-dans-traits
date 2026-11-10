-- Dan's Vanilla Fixes: its page in the Vitality Project's Guide tab.
--
-- The Guide reads DanTraits_GuideExtra when the character window is built, so
-- this only has to put the page in the table. Without the Vitality Project the
-- table sits unused and this mod works as before. Plain English only: the
-- Guide's pages are not translated.
DanTraits_GuideExtra = DanTraits_GuideExtra or {}
table.insert(DanTraits_GuideExtra, {
    id = "dansvanillafixes", title = "Dan's Vanilla Fixes", mod = "DansVanillaFixes", order = 10,
    body = {
        "Small fixes and finishing touches for the game itself. Nothing here adds a system to manage; each piece makes something you already do work a little better.",
        "",
        "## Cold packs and coolers",
        "Chill a cold pack in a fridge (half way) or a freezer (fully), or leave it out below freezing, then put it in a cooler. The cooler keeps food as cold as a fridge does, about six hours for each frozen pack (a sandbox setting), and the packs and the cooler say how cold they are in their names.",
        "",
        "## Item info in tooltips",
        "- Skill books say how much reading is left; with the Vitality Project's reading, so do novels.",
        "- Drainables say how many uses are left, batteries their charge.",
        "- Weapon numbers open up as you level that weapon's skill.",
        "- Clothing says which body parts it covers and how it compares with what you are wearing (its own sandbox page).",
        "",
        "## Rarity colours",
        "Every item name in the inventory is coloured by how rare it is: orange Legendary, purple Epic, blue Rare, green Uncommon, grey Common, teal Crafted. The tiers are worked out from the loot lists when the game starts, modded items included, and the tooltip names the tier. Item Rarity UI is not needed.",
        "",
        "## The collection",
        "A Collection button on the sidebar opens a checklist for each character of the skill books, recipe magazines, VHS tapes, CDs, key rings, mementos and tools they own. Tick what you have: those items say so in their tooltip and are set Unwanted, so they grey out and Take All leaves them.",
        "The rest of the game's reading is on it too, by title: every book, magazine, comic, newspaper, flier, brochure, catalogue and RPG manual. Right-click a copy and choose Add to collection, or tick it in the window. A ticked title is set Unwanted like the rest, that title only: the next paperback may be one you do not have, and it stays white. A magazine or a comic counts by its name, whatever the issue, and the issues you add are the ones set Unwanted. Tapes and CDs work the same way, title by title.",
        "",
        "## Store stock",
        "Cigarette packs on gas station, convenience store, liquor store and tobacconist shelves come full, not half-smoked.",
        "",
        "## Need to know",
        "- Safe to add to or remove from a running save.",
        "- Singleplayer for now.",
    },
})

-- Map Legend: its page in the Vitality Project's Guide tab.
--
-- The Guide reads DanTraits_GuideExtra when the character window is built, so
-- this only has to put the page in the table. Without the Vitality Project the
-- table sits unused and this mod works as before. Plain English only: the
-- Guide's pages are not translated.
DanTraits_GuideExtra = DanTraits_GuideExtra or {}
table.insert(DanTraits_GuideExtra, {
    id = "maplegend", title = "Map Legend", mod = "MapLegend", order = 30,
    body = {
        "Your own key for the symbols you draw on the world map, so a red X still means something a month later. It sits in the bottom-left corner of the map (M) and folds down to its title.",
        "",
        "## Entries",
        "An entry is a vanilla symbol in one pen colour and what it means. The same symbol in another colour is another entry, so a red X can mean Horde and a green X Cleared. Each row shows how many of that mark are on your map, with a line for the marks the legend does not cover yet.",
        "",
        "## Using it",
        "- Hover a row and every mark of that kind is outlined on the map; a tooltip gives the full meaning and the pen.",
        "- Click a row to draw with it: the symbol and its pen are picked in the symbols panel, ready to place. Click again to put the pen down. Without that pen the row still outlines its marks and names the pen you need.",
        "- In the symbols panel, hover a symbol to see what it means in each pen; pick one and the pen switches to its legend colour if you carry it.",
        "- Long legends scroll with the mouse wheel.",
        "",
        "## The editor",
        "Press Edit on the legend. Pick a symbol and a pen, type what it means (Enter saves) or choose a preset such as Horde, Loot, Looted, Water, Fuel or Safehouse. Click an entry to change it, move it, or remove it. A symbol and colour already in the legend replaces that entry, so one mark never has two meanings.",
        "",
        "## One legend for every save",
        "The legend is saved to your profile (Zomboid/Lua/MapLegend.txt) and every save and character uses it. Tick This character keeps its own legend to give one character its own, starting as a copy; Copy to profile makes a character's legend the shared one.",
        "",
        "## Need to know",
        "- Vanilla symbols and pens only: no new items, and nothing on the map itself changes. Pens other mods add show up in the editor.",
        "- Safe to add to or remove from a running save. It shows on the world map, not on paper maps.",
        "- Multiplayer: your legend stays on your computer; send a friend your MapLegend.txt to share a key.",
    },
})

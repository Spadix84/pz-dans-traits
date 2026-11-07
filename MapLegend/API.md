# Map Legend: API for modders

Add presets to the legend editor, read what a player's map symbols mean, give a symbol a
meaning from your own mod, and react when the legend changes. Everything lives in
`media/lua/shared/MapLegend_API.lua`. `MapLegend.API_VERSION` is `1`.

## Making Map Legend optional

Put this at the top of one of your **shared** Lua files. It runs when Map Legend is
installed and does nothing when it isn't, so you don't need to list it in `require=`:

```lua
local ok = pcall(require, "MapLegend_API")
if ok and MapLegend and MapLegend.API_VERSION then
    -- calls below
end
```

To make it a hard dependency instead, add `require=\MapLegend` to your `mod.info`.

## What an entry is

```lua
{ sym = "Skull", r = 0.65, g = 0.054, b = 0.054, text = "Horde" }
```

`sym` is a vanilla map symbol id from `MapSymbolDefinitions` (`"X"`, `"Skull"`, `"House"`,
`"Car"`, ...), and `r, g, b` the colour of the pen it is drawn in (the vanilla pens are
black `0.129, 0.129, 0.129`, pencil `0.2, 0.2, 0.2`, red `0.65, 0.054, 0.054`, blue
`0.156, 0.188, 0.49`, green `0.06, 0.39, 0.17`; a pen your mod adds to the symbols panel
is picked up as it is). Colours within `MapLegend.COLOR_TOLERANCE` (0.03) are the same
pen, since the game hands a colour back as a float a hair off what was set. The same
symbol in another colour is another entry.

A character reads the profile's legend (`Zomboid/Lua/MapLegend.txt`, shared by every save
and character) unless it keeps one of its own. Every call below takes the player and
works on whichever that character uses; an edit is saved at once.

## Presets

```lua
-- a meaning in the editor's preset list; the text shown is the translation
-- IGUI_ML_Preset_Beehive if your mod ships one, else the text given, else the name
MapLegend.addPreset("Beehive", "Beehive")
```

Returns `true` when added, `false` for a name already there. The built-in names are
Safehouse, Loot, Looted, Food, Water, Medical, Weapons, Ammo, Tools, Fuel, Generator,
Vehicle, Farm, Animals, Fishing, Danger, Horde, Cleared, Locked, Blocked, Trap,
Survivors, Meet and ToCheck.

## Reading

```lua
local entries = MapLegend.entries(player)              -- the live list, in legend order: read, don't edit
local e = MapLegend.meaning(player, "X", 0.65, 0.054, 0.054)   -- the entry or nil
local all = MapLegend.meaningsFor(player, "X")         -- every entry for a symbol, whatever the pen
MapLegend.isOwn(player)                                -- does this character keep its own legend
```

## Writing

```lua
-- a meaning for a symbol in a pen colour (text up to 60 characters). A symbol and
-- colour already in the legend is replaced, so one mark never has two meanings.
local e = MapLegend.set(player, "Skull", 0.65, 0.054, 0.054, "Horde")

MapLegend.unset(player, "Skull", 0.65, 0.054, 0.054)   -- true when there was one
MapLegend.setOwn(player, true)                          -- the character's own legend, starting as a copy
```

`set` returns the entry (nil for a bad symbol) and saves at once: to the profile file, or
with the character when it keeps its own legend. The legend panel redraws.

## Events

```lua
MapLegend.on("changed", function(player)
    -- any change: the editor, set, unset, setOwn. player is nil when the profile
    -- changed from outside a character (copyToProfile).
end)
MapLegend.off("changed", fn)
```

An error in one listener is logged and does not stop the others.

## Good to know

- Nothing here touches the map itself: the symbols are the game's, drawn by the player.
  To count what is on the map, the panel reads `ISWorldMap`'s symbols; `MapLegend.count`
  in the core does the counting if you have the symbols API object in hand.
- Multiplayer: the legend is the player's own and stays on their computer.
- The core (`MapLegend_Core.lua`) has more, with no promise about it staying put.

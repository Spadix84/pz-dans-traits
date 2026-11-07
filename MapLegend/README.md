# Map Legend

A Project Zomboid (Build 42) mod: your own key for the symbols you draw on the world map.
On the Workshop as [Map Legend](https://steamcommunity.com/sharedfiles/filedetails/?id=3831306437).
Part of the [Vitality Project](../README.md) repository; works on its own.

- **An entry** is a vanilla symbol in one pen colour and what it means. The same symbol in
  another colour is another entry, so a red X can mean Horde and a green X Cleared. Each
  row counts how many of that mark are on the map.
- **Hover** a row to outline those marks; **click** it to draw with that symbol and pen (click
  again to put the pen down). The symbols panel shows what a symbol means in each pen and
  switches to the legend's colour when you pick one.
- **The editor** (Edit on the legend): pick a symbol and a pen, type the meaning or choose a
  preset, reorder, remove. One mark never has two meanings.
- **One legend for every save**, kept in `Zomboid/Lua/MapLegend.txt`; a character can keep
  its own instead, and copy it back to the profile.
- Vanilla symbols and pens only, nothing on the map itself changes, safe to add or remove
  mid-save. Pens other mods add show up.

| Layout | |
|---|---|
| `42/media/lua/shared/MapLegend_Core.lua` | entries, the profile file, a character's own legend, counting; no UI, tested offline |
| `42/media/lua/shared/MapLegend_API.lua` | what other mods may call ([API.md](API.md)) |
| `42/media/lua/client/MapLegend_Panel.lua`, `MapLegend_Editor.lua` | the legend on the map, the symbols-panel hooks, the editor |
| `42/media/lua/client/MapLegend_Guide.lua` | its page in the Vitality Project's Guide tab (does nothing without it) |
| `../workshop/maplegend/` | the Workshop page: description.txt, workshop.txt, preview.png, the mock-ups and the script that draws them |
| `../tests/test_maplegend.lua`, `test_maplegend_api.lua` | offline tests (`python tests/run_tests.py maplegend`) |

Deploy with `python deploy.py --mod MapLegend`; build the Workshop upload folder with
`python deploy.py --workshop MapLegend`. Changes are logged in the repository's
[CHANGELOG.md](../CHANGELOG.md) under "Map Legend".

## For other mods

`MapLegend_API.lua` lets a mod add presets, read what a player's symbols mean, set meanings
and listen for changes, through `pcall(require, "MapLegend_API")` so it runs with or
without this mod. The guide is [API.md](API.md).

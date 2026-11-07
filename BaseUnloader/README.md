# Base Unloader

A Project Zomboid (Build 42) mod that puts a loot run away for you. Part of the
[Vitality Project](../README.md) repository; works on its own. Not yet on the Workshop.

- Right-click the car (**Unload trunk to base**), any container or loot (**Unload to base**),
  or your own items (**Put away what I am carrying**). A window lists what is in the source
  by type, and every container in the base with its name, kind, room, floor, distance and
  how full it is, zone by zone.
- **Drag** a type onto a container and that type lives there from now on, for this save.
  **Suggest** fills the gaps from what the base already holds. Rules can be cleared per type
  or category; containers can be renamed (the loot window shows the name too), tagged with
  categories, or marked **Off limits**.
- **Base zones** are drawn with the game's zone tool (Base zones... on the world menu); with
  none nearby the base is the building you are in plus the ground round the source.
- **Start**: the character loads a trip's worth into worn bags, walks the base putting
  things down, and goes back for more. Favourites and anything worn or held are never
  touched; an interruption only pauses it (**Resume unloading**).
- **Base inventory...** lists everything stored in your zones by type and container, with
  search, sort, and "At base: N" on any item's right-click menu.

The full description of every rule is in the repository README's
[Base Unloader section](../README.md#base-unloader).

| Layout | |
|---|---|
| `42/media/lua/shared/BaseUnloader_Core.lua` | keys, saved data, rules, grouping, suggestions, trip planning: pure, tested offline |
| `42/media/lua/client/BaseUnloader_Scan.lua` | zones, container rows, names, places, item records |
| `42/media/lua/client/BaseUnloader_Zones.lua`, `BaseUnloader_Stock.lua` | the drawn base zones; the base inventory and at-base counts |
| `42/media/lua/client/BaseUnloader_Run.lua` | the step machine over the game's walk and transfer actions |
| `42/media/lua/client/BaseUnloader_UI.lua`, `BaseUnloader_Menu.lua` | the window and the context menus |
| `42/media/lua/client/BaseUnloader_Guide.lua` | its page in the Vitality Project's Guide tab (does nothing without it) |
| `../tests/test_baseunloader.lua` | offline tests (`python tests/run_tests.py baseunloader`) |

Deploy with `python deploy.py --mod BaseUnloader`. Changes are logged in the repository's
[CHANGELOG.md](../CHANGELOG.md) under "Base Unloader". Singleplayer for now.

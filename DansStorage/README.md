# Dan's Storage

A Project Zomboid (Build 42) mod, in development: shelves made for one thing. Each is
plain galvanised steel, two tiles long, takes only its own items, and shows how full it
is: bare, half (some) or full (every place taken).

| Shelf | Takes | A tile holds | Build (Furniture, Metalworking 3, a welding mask, no book) |
|---|---|---|---|
| **Water Jug Rack** | water dispenser jugs (`Base.WaterDispenserBottle`), full or empty, lying on their sides | 9 | 3 blowtorch uses, 2 welding rods, 4 metal pipes, 4 metal bars |
| **Gas Can Shelf** | gas cans (`Base.PetrolCan`) and jerry cans (`Base.JerryCan`), standing on three decks | 9 | 4 blowtorch uses, 3 welding rods, 4 metal pipes, 2 metal bars, 3 sheet metal |
| **Propane Shelf** | propane tanks (`Base.PropaneTank`), standing on two decks | 6 | 3 blowtorch uses, 3 welding rods, 4 metal pipes, 4 metal bars, 2 sheet metal |

Pick its facing in the build cursor; the furniture tools pick it up and put it down like
the game's own two-tile shelves (and, like them, can't turn it). The gas can shelf's
sprites show red cans with a green jerry can here and there whatever is on it.

| Layout | |
|---|---|
| `42/media/lua/shared/DansStorage_Shelves.lua` | `KINDS`, one row per shelf (tiles, container type, items, a tile's count, the accept function's name); which objects are shelf tiles, the accept functions (`DansStorage.acceptWaterJug`, `acceptGasCan`, `acceptPropane`), the overlay each tile should show and setting it, the shelves seen, the build hook |
| `42/media/lua/server/DansStorage_ShelvesServer.lua` | shelves get their accept function and their look back as their chunks load (the function is not saved); every shelf seen is looked at once a game minute |
| `42/media/lua/client/DansStorage_ShelvesClient.lua` | the loot window: the metal shelves' button icon, and the accept function on every shelf listed; the look put back after each item moves (a wrap on `ISInventoryTransferAction.transferItem`) |
| `42/media/scripts/DansStorage_entities.txt` | the build recipes, `DansStorage_WaterJugRack`, `_GasCanShelf`, `_PropaneShelf` |
| `texturepacks/`, `*_tiledefinitions.tiles`, `depthmaps/`, `textures/` | the tiles (`storage_waterjugrack_01`, `storage_gascanshelf_01`, `storage_propaneshelf_01`: ids 1-3 in file 6744) and the build icons, made by `art/storage/` and packed by `tools/build_pack.py` |

A new shelf is a model (`art/storage/build_<name>.py` on `shelf_common.py`), a row in
`SHELVES` in `tools/build_pack.py`, a row in `KINDS`, an entity and its translations.

How it fits the game:

- **Only its items.** Every container can be given an accept-item function
  (`ItemContainer.setAcceptItemFunction`), which the game asks before anything goes in.
  It is not saved, so a shelf tile gets it as it loads (`MapObjects.OnLoadWithSprite`), as
  it is put down (`OnObjectAdded`), as it is built (the entity's `OnCreate`), and as its
  loot window opens (`OnRefreshInventoryWindowContainers`; the only one on a multiplayer
  client).
- **How full it looks** is an overlay tile over the shelf tile: none empty, half while
  it holds some, full only when every place is taken. The game's own container overlays
  (the ones that stock shop fridges) were not used: they say "many" from 7 items, a
  number fixed in the game. They still run after every transfer, and for a sprite they
  don't know they clear the overlay (`ContainerOverlays.updateContainerOverlaySprite`), so
  the client file sets it again straight after (`transferItem`), and the server looks at
  every shelf once a game minute for anything else. The overlay is saved with the object.
- **Two tiles**, the way vanilla's Large Metal Shelves are: `GroupName` + `CustomName` +
  `Facing` + `SpriteGridPos`, each tile its own container (types `waterjugrack`,
  `gascanshelf`, `propaneshelf`).

Build, then deploy:

```
python art/storage/make_sprites.py <shelf>      (after its Blender run, see art/storage/README.md)
python DansStorage/tools/build_pack.py
python deploy.py --mod DansStorage
```

Tests: `python tests/run_tests.py storageshelves` (offline).

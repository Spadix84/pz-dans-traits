# Window air conditioner art

The window AC for Dan's Climate Control ([plans/climate.md](../../plans/climate.md)),
modelled and rendered from a script, the same way as the Slow Cooker's art.

| File | |
|---|---|
| `build_windowac.py` | builds the model in Blender and renders the tile sprites, or 3/4 previews |
| `make_sprites.py` | turns the renders into 128x256 game sprites, the sheet, its depth map, the icon, and an in-wall mock-up |
| `build_pack.py` | writes the texture pack, tile definitions, depth map and icon into `DansClimate/42/media` |
| `windowac.blend` | the model, saved by the last sprite run (open it to look around) |
| `renders/preview_*.png` | 3/4 close-ups, front (indoors) and back (outdoors), off and on |
| `sprites/` | the game sprites, `appliances_windowac_01.png` (S,E,N,W off, then on) and `mockup.png` |

Facings name where the front grille points, which is the side the room is on: S and N
sit in a window on the tile's north edge, E and W in one on its west edge. The sprite
renders put an invisible holdout wall around the window, so the outdoor half only shows
through the opening; the game draws the real wall and window.

Sizes come from vanilla sprites: a 1 m tile edge (90.5 px per metre), 2.46 m walls,
a window opening about 0.52 x 0.88 m with its sill 0.97 m up. The unit is
0.42 x 0.31 m, 0.15 m indoors and 0.27 m out, with pleated panels filling the opening.

```
blender --background --factory-startup --python build_windowac.py -- --out <abs>/renders --depth --save-blend <abs>/windowac.blend
blender --background --factory-startup --python build_windowac.py -- --out <abs>/renders --icon
blender --background --factory-startup --python build_windowac.py -- --out <abs>/renders --preview
python make_sprites.py renders sprites --vanilla <folder of extracted vanilla sprites>
python build_pack.py sprites ../../DansClimate/42/media
```

Blender wants an absolute `--out` path. The mock-up and depth check need
`walls_exterior_house_01_8/9` and `fixtures_windows_01_0/1` from
`media/texturepacks/Tiles2x.pack`, and tiles 0 and 1 of
`media/depthmaps/DEPTH_fixtures_windows_01.png` saved as `DEPTH_fixtures_windows_01_0/1`.

**Depth:** the depth pass writes vanilla's own grey directly. Fitted to the vanilla
window depth map, grey = 177.2 + 103.2 x metres away from the camera, measured from the
tile's floor centre, the same for both wall edges. `make_sprites.py` checks that over
solid wall the unit never sorts behind the wall plane; through the opening it may.

**Packing** (`build_pack.py`) writes `DansClimate.pack`, the tile definitions (file number
6743, beside the Slow Cooker's 6742), the depth map and the inventory icon into the mod.
The tiles carry `attachedN` or `attachedW` like vanilla curtains, and no `IsMoveAble`, so
only the mod's own install action can place one.

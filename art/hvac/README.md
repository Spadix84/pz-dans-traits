# Central heating and cooling art

The electric furnace, the central air conditioner's outdoor unit and the floor vent for
Dan's Climate Control ([plans/climate.md](../../plans/climate.md)), modelled and rendered
from a script, the same way as the space heater and the window air conditioner next
door, whose camera, helpers and sprite treatment they use.

| File | |
|---|---|
| `build_hvac.py` | builds the three models in Blender and renders the tile sprites, 3/4 previews, or the icons |
| `make_sprites.py` | turns the renders into 128x256 game sprites, the sheet, its depth map, the two icons and a mock-up on a floor tile |
| `hvac.blend` | the three models side by side, saved by the last sprite run (open it to look around) |
| `renders/preview_*.png` | 3/4 close-ups, front and back, idle and running |
| `sprites/` | the game sprites, `appliances_hvac_01.png`, `DEPTH_appliances_hvac_01.png`, `Item_HVACFurnace.png`, `Item_HVACCondenser.png` and `mockup.png` |

**The sheet** is 8 tiles across and 3 down (1024x768), tiles `appliances_hvac_01_N`:

| Tiles | |
|---|---|
| 0-3 | furnace idle, facing S, E, N, W |
| 4-7 | furnace running, same order |
| 8-11 | condenser idle, facing S, E, N, W |
| 12-15 | condenser running, same order |
| 16 | vent, its long side along the tile's north-south axis |
| 17 | vent, turned a quarter |
| 18-23 | empty |

**The furnace** is an upflow cabinet 0.55 m wide, 0.65 m deep and 1.35 m tall in worn
beige enamel: a louvred lower door, a control label, a badge and a pilot lamp on the
upper door, a disconnect box with its conduit on the right side, a filter slot on the
left, and a galvanised plenum stub on top (1.47 m in all). Running, the pilot lamp and a
small lamp on the disconnect box are lit amber. In a tile it covers x 19-109, y 93-246.

**The condenser** is a grey-green box 0.8 m square and 0.75 m tall on a 0.92 m concrete
pad (0.80 m to its top): louvres on all four sides over a dark coil, a round fan
opening with a wire guard on top, and on its front a plain service panel with the
label, the two refrigerant lines and the electrical whip. Running, the four fan blades
are a blurred disc. In a tile it covers x 5-123, y 136-253.

**The vent** is a steel floor register, 0.30 by 0.15 m and 7 mm tall, with eight fins
and a damper lever, in the middle of the tile (x 50-78, y 216-231).

Facings name the way the front points. The camera looks from the south-east, so S and E
show the front, and N and W the back. The furnace's lamps are on its front and its
right side, so tile 6 (N, running) looks the same as tile 2: from there neither shows.
The condenser's fan is on top and shows from every side.

```
blender --background --factory-startup --python build_hvac.py -- --out <abs>/renders --depth --save-blend <abs>/hvac.blend
blender --background --factory-startup --python build_hvac.py -- --out <abs>/renders --icon
blender --background --factory-startup --python build_hvac.py -- --out <abs>/renders --preview
python make_sprites.py renders sprites
```

Blender wants an absolute `--out` path. `--objects furnace,condenser,vent` limits a run
to some of them.

**The lamp and the palette:** the sprite treatment reduces each sprite to 40 colours,
and a few pixels of amber don't win a place among them, so they turned cream.
`make_sprites.py` puts the strongly orange pixels of the plain downscale back afterwards
(22, 14 and 7 pixels in tiles 4, 5 and 7).

**Depth:** as the space heater's: vanilla's grey with the window air conditioner's
slope (103.2 grey a metre away from the camera) and 188.2 at the tile's floor centre,
the value vanilla floor appliances read. The furnace runs from 81 at its top front edge
to 192 at its far foot, the condenser 97 to 196, the vent 174 to 201.

**Packing:** not done here. `DansClimate/tools/build_pack.py` packs the mod's sheets;
this one still has to be added to it, with its tile properties.

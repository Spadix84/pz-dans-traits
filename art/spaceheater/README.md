# Space heater art

The electric space heater for Dan's Climate Control ([plans/climate.md](../../plans/climate.md)),
modelled and rendered from a script, the same way as the window air conditioner next
door, whose camera, helpers and sprite treatment it uses.

| File | |
|---|---|
| `build_spaceheater.py` | builds the model in Blender and renders the tile sprites, or 3/4 previews |
| `make_sprites.py` | turns the renders into 128x256 game sprites, the sheet, its depth map and a mock-up on a floor tile |
| `spaceheater.blend` | the model, saved by the last sprite run (open it to look around) |
| `renders/preview_*.png` | 3/4 close-ups, front and back, off and on |
| `sprites/` | the game sprites, `appliances_spaceheater_01.png` (S,E,N,W off, then on) and `mockup.png` |

A 1990s radiant heater: a brown enamel cabinet 0.54 m wide and 0.39 m tall on two skids,
a chrome reflector behind a wire guard, two quartz elements, a dial, a switch and a pilot
lamp on top, a carry handle, vent slots and the cord at the back. Switched on, the
elements and the lamp glow.

Facings name the way the front points. The camera looks from the south-east, so S and E
show the elements, and N and W the back, where only the pilot lamp shows it running.

```
blender --background --factory-startup --python build_spaceheater.py -- --out <abs>/renders --depth --save-blend <abs>/spaceheater.blend
blender --background --factory-startup --python build_spaceheater.py -- --out <abs>/renders --preview
python make_sprites.py renders sprites
python ../../DansClimate/tools/build_pack.py
```

Blender wants an absolute `--out` path.

**Depth:** the depth pass writes vanilla's grey directly, with the window air
conditioner's slope (103.2 grey a metre away from the camera). Its grey at the tile's
floor centre is 188, not the 177 fitted to walls and windows: vanilla floor appliances
(`DEPTH_appliances_cooking_01`, `_laundry_01`, `_misc_01`) read 10 to 12 grey farther
than the wall fit where they meet the floor. The heater's lowest pixels come out at
159 to 166, where a vanilla appliance on the same screen rows reads 160.

**Packing** (`DansClimate/tools/build_pack.py`) puts this sheet and the window air
conditioner's into `DansClimate.pack` and the tile definitions (file number 6743; this
tileset is id 2). Tiles 0-3 are a vanilla moveable (`IsMoveAble`, item
`Base.Mov_SpaceHeater`), so the game's furniture tools pick the heater up, place it and
turn it. Tiles 4-7 carry no properties: the mod draws them over 0-3 while it runs.

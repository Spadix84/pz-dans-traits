# Storage shelf art

The shelves of Dan's Storage ([DansStorage/README.md](../../DansStorage/README.md)),
modelled and rendered from scripts with the window air conditioner's camera, helpers and
sprite treatment ([../windowac](../windowac)).

| File | |
|---|---|
| `shelf_common.py` | what every shelf shares: the steel frame (uprights, feet, caps, beams, side bars, sheet decks), shapes, the two-tile cut, the facings and grid positions, rendering and the command line |
| `build_waterjugrack.py` | the water jug rack: three tiers of beams, three 19 l jugs on their sides on each, necks out |
| `build_gascanshelf.py` | the gas can shelf: three sheet decks, three cans standing on each (red petrol cans, a green jerry can here and there) |
| `build_propaneshelf.py` | the propane shelf: two sheet decks under a top frame, three 20 lb tanks standing on each |
| `make_sprites.py <shelf>` | turns `renders/<shelf>` into 128x256 game sprites in `sprites/<shelf>`: the sheet, its depth map, a floor mock-up and the preview the build icon is cut from |
| `<shelf>.blend` | each model, saved full by its last sprite run (open it to look around) |
| `renders/<shelf>/preview_*.png` | 3/4 views of the whole shelf: empty, half, full |

All three share the frame: galvanised square-tube uprights at the ends and in the middle,
a front and a back beam at each level, a bar across at every upright, 2 m long and 0.42 m
deep against the back of its tiles.

**Two tiles.** A model is built as two halves cut at the middle (`clipped_box`), one per
tile, and each tile is rendered alone, centred on the camera's tile. So each sprite holds
only what stands on its own tile, as vanilla two-tile furniture does, and the two meet
without a seam (see each `mockup.png`). The scripts print the grid position each half has
for each facing; the sheet keeps vanilla's order for two-tile shelves (`crafted_05_48/49`):
S and N west tile then east, E and W south tile then north.

**Sheet:** row 0 (tiles 0-7) the bare shelf, row 1 (8-15) half full (the bottom level
full and, on the jug rack and the gas can shelf, two on the middle, from the middle of
the shelf out), row 2 (16-23) full. Rows 1 and 2 are whole renders, shelf and all, which
the mod draws over row 0 as an overlay: half while it holds some, full when every place
is taken.

**Depth:** each tile and state has its own depth pass (what is on it changes the shape),
with the floor-object grey of the space heater (188.2 at the tile's floor centre).

```
blender --background --factory-startup --python build_<shelf>.py -- --out <abs>/renders/<shelf> --depth --save-blend <abs>/<shelf>.blend
blender --background --factory-startup --python build_<shelf>.py -- --out <abs>/renders/<shelf> --preview
python make_sprites.py <shelf>
python ../../DansStorage/tools/build_pack.py
```

Blender wants an absolute `--out` path, with forward slashes when it comes from Git Bash.
A full sprite run (24 tiles and 24 depth passes) takes a few minutes on the CPU.

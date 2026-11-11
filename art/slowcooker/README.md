# Slow cooker art

The Slow Cooker for [Vitality Appliances](../../VitalityAppliances/README.md), modelled and
rendered from a script.

| File | |
|---|---|
| `build_slowcooker.py` | builds the model in Blender and renders the tile sprites |
| `make_sprites.py` | turns the renders into 128x256 game sprites, the sheet, its depth map and the inventory icon |
| `build_pack.py` | writes the texture pack, tile definitions (file number 6742) and depth map into the mod |
| `slowcooker.blend` | the model, saved by the last sprite run |
| `sprites/` | the game sprites; `preview.png` is the 256 px picture `workshop/appliances/make_images.py` uses |
| `preview.png` | a large render, for looking at |

The raw renders are not kept, so re-render first. Run from this folder:

```bash
blender --background --factory-startup --python build_slowcooker.py -- --out renders --variants harvest --facings E,S,W,N --states off,on --scale 8 --samples 96 --depth --save-blend slowcooker.blend
```

```bash
python make_sprites.py renders sprites --variant harvest --facings E,S,W,N --sheet
```

```bash
python build_pack.py sprites ../../VitalityAppliances/42/media
```

Tiles 0-3 are the cooker facing E, S, W, N. Tiles 4-7 are the same views switched on,
drawn over it as an overlay while it runs. `build_pack.py` does not copy the inventory
icon: after a re-render, copy `sprites/Item_SlowCooker.png` to the mod's
`media/textures/Item_SlowCooker.png` and `media/ui/Container_SlowCooker.png`, then run
`python workshop/appliances/make_images.py` from the repository root for the mod icon.

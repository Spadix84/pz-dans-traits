# Brick smoker art

The Brick Smoker for [Vitality Appliances](../../VitalityAppliances/README.md). The model
is built by script; `smoker.blend` is saved for looking at or editing by hand, but the
sprites come from the script.

| File | |
|---|---|
| `build_smoker.py` | builds the model in Blender and renders the tile sprites |
| `make_sprites.py` | turns the renders into 128x256 game sprites, the sheet, its depth map, the icons and a 256 px preview |
| `build_pack.py` | writes the texture pack, tile definitions (file number 7318), depth map and icons into the mod |
| `smoker.blend` | the model, saved by the last sprite run |
| `renders/` | the depth renders; the raw colour renders are not kept in git |
| `sprites/` | the game sprites, `icon.png` and `preview.png` |

Run from this folder:

```bash
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python build_smoker.py -- --out "$(cygpath -w "$PWD")\\renders" --facings E,S,W,N --states off,on --scale 4 --samples 64 --depth --save-blend "$(cygpath -w "$PWD")\\smoker.blend"
```

```bash
python make_sprites.py renders sprites --sheet
```

```bash
python build_pack.py sprites ../../VitalityAppliances/42
```

Tiles 0-3 are the smoker facing E, S, W, N; tiles 4-7 the same views lit (glowing firebox,
chimney smoke), drawn over it as an overlay while the fire burns. The mod's icon and the
Workshop preview show both appliances: after a re-render, run
`python workshop/appliances/make_images.py` from the repository root.

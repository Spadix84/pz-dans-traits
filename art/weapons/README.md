# Weapon models

Weapons modelled from scripts, in the game's own model space and written straight to the
game's model format (DirectX `.X` text, what vanilla's weapons are), so nothing is lost
or turned round in an exporter.

| File | |
|---|---|
| `weapon_common.py` | shared: a face list with texture coordinates, the `.X` writer and reader, Blender previews |
| `install.py` | copies each weapon's model, texture and icon into the Dan's Weapons mod (`DansWeapons/`) |
| `hockeycleaver/` | the hockey stick cleaver |
| `glaive/` | the bread knife glaive |
| `cutlerymace/` | the cutlery mace |
| `sock/` | the lock in a sock and the sock flail (two models, one texture) |
| `texture_common.py` | shared: the texture canvas (painted four times too big and shrunk), the colours, wood, duct tape and steel |
| `icon_common.py` | shared: the 32x32 inventory icon, drawn on the diagonal with a dark rim |

## The model space

Measured from vanilla's ice hockey stick, fire axe and meat cleaver:

- **+Y** runs along the weapon away from the hand. The grip is at the origin; the butt
  sits a little behind it (the ice hockey stick is y -0.093 to 0.674).
- **-Z** is the cutting edge (the fire axe and the meat cleaver both cut that way).
- **X** is the thin way.
- A unit is about half a metre for long weapons (the 1.5 m stick is 0.77), and small
  things are drawn big (the cleaver is 0.24).
- Faces are wound counter-clockwise seen from outside. Texture coordinates measure v
  from the top of the image.

## Hockey stick cleaver

An ice hockey stick with a meat cleaver lashed to the far end: the cleaver's handle
taped flat along the shaft with two bands of duct tape, wire through the hole in the
blade's corner, the cleaver's edge one way and the stick's own blade the other. 168
triangles, one 256x256 texture.

| File | |
|---|---|
| `build_hockeycleaver.py` | the measurements, the texture layout and the mesh; run in Blender it writes the model, the `.blend` and the previews |
| `make_texture.py` | paints `HockeyStickCleaver.png` from the same measurements (numpy, Pillow) |
| `HockeyStickCleaver.X` | the game's model |
| `HockeyStickCleaver.png` | its texture |
| `make_icon.py` | draws `Item_HockeyStickCleaver.png`, the 32x32 inventory icon (drawn, not rendered: at that size the model is a line), and `icon_preview.png` |
| `hockeycleaver.blend` | the model, to look around |
| `preview_*.png` (not committed) | side, back, edge-on, the head close up and at 3/4; `preview_compare.png` puts it beside vanilla's stick, axe and cleaver at the same scale |

```
cd hockeycleaver
python make_texture.py
python make_icon.py
blender --background --factory-startup --python build_hockeycleaver.py -- --game "<the game's folder>/media"
```

`--game` is only for the comparison picture. Then `python ../install.py` copies the model,
the texture and the icon into the mod.

**In the mod:** Dan's Weapons (`DansWeapons/`) has it as `Base.HockeyStickCleaver`. The
model sits in `media/models_X/weapons/2handed/`, the texture in
`media/textures/weapons/2handed/`, and the model script
(`DansWeapons/42/media/scripts/DansWeapons_models.txt`) names the mesh. Its two
attachments are the fire axe's hand position (the same edge direction) and the fire axe's
turn on the ground with the ice hockey stick's offset. They have not been tried in game;
the game's attachment editor (debug mode) is the place to settle them.

## The others

Each folder has the same three scripts (`build_<name>.py` for Blender, `make_texture.py`,
`make_icon.py`) and the same outputs. They use what `weapon_common.py` gained after the
hockey stick cleaver: `ring` and `Mesh.loft` for round, tapering or bent shafts, `Mesh.plate`
for thin sheets seen from both sides, and `run`, a build script's whole main.

- **Bread knife glaive** (`glaive/`, 110 triangles): a six-sided broom handle, the knife's
  handle taped flat against its -Z face, the blade running on past the pole's end, edge
  towards -Z. The serrations are painted.
- **Cutlery mace** (`cutlerymace/`, 216 triangles): a turned club with three forks and three
  butter knives on its head's six flats, their stems under two bands of tape and their
  ends bent out 22 degrees. The same all the way round.
- **Lock in a sock** and **sock flail** (`sock/`, 188 and 254 triangles): a sock skinned
  over a row of rings that sag towards -Z, a knot, and a flat toe with the padlock painted
  showing through. A weapon is one rigid shape in the game, so it is modelled mid-swing,
  not hanging. The flail adds a small six-sided handle and a band of tape.

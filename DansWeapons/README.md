# Dan's Weapons

A Project Zomboid (Build 42) mod, in development: improvised weapons with their own
models, made from household things that otherwise go unused. None needs a skill or a
recipe learned, and none takes more than duct tape; they are fragile, and when one breaks
you get the useful part back.

| Weapon | Skill | Hands | Damage | Reach | Condition | Weight |
|---|---|---|---|---|---|---|
| **Hockey Stick Cleaver** | Axe | 2 | 0.7 to 1.4 | 1.45 | 8, lowers 1 in 6 (+ cleaver 10) | 2.5 |
| **Bread Knife Glaive** | Long Blade | 2 | 0.9 to 1.6 | 1.5 | 8, 1 in 6 (+ knife 8) | 2.2 |
| **Cutlery Mace** | Short Blunt | 1 | 0.6 to 1.1 | 1.1 | 9, 1 in 8 | 1.8 |
| **Lock in a Sock** | Short Blunt | 1 | 0.5 to 1.0 | 0.95 | 5, 1 in 4 | 0.5 |
| **Sock Flail** | Short Blunt | 1 | 0.7 to 1.3 | 1.15 | 6, 1 in 5 | 1.0 |

For scale, from the game: a hand axe is 0.7 to 1.5 at 1.1, a machete 2.0 to 3.0 at 1.23,
a nightstick 0.6 to 1.1 at 1.2, a hammer 0.5 to 1.0 at 1.1, a rolling pin 0.2 to 0.5.

| Weapon | Make it from | Where | Take apart | When it breaks |
|---|---|---|---|---|
| **Hockey Stick Cleaver** | an ice hockey stick, a meat cleaver, 2 duct tape, 1 wire or electric wire, with pliers | any surface | the cleaver and the stick, each with its own wear | splinters, the cleaver on the ground, a broken stick in the hands |
| **Bread Knife Glaive** | a bread knife, a **long handle** (or a broom or a mop), 2 duct tape | any surface | the bread knife and a long handle | splinters, the knife on the ground, a broken long handle |
| **Cutlery Mace** | a **handle** (or a rolling pin), 3 forks, 3 butter knives, 3 duct tape | any surface | no | splinters, one fork and one butter knife, the handle done for |
| **Lock in a Sock** | a pair of long or heavy socks (not worn), a padlock | in the hands, no tools | the padlock and the socks | the padlock on the ground, a rag in the hand |
| **Sock Flail** | a lock in a sock, a **small handle**, 1 duct tape | in the hands | no | the padlock on the ground, the small handle |

All are Weaponry recipes with nothing to learn. The stick's, pole's or handle's condition
carries over to the weapon, and so does the cleaver's or knife's (the two long ones have
two conditions, like the game's knife spears). The hockey stick cleaver can be sharpened;
most are repaired with tape or glue. None fells trees, and none is in the loot tables.

**The sock is stiff.** A weapon model in the game is one rigid shape, so the sock cannot
hang and swing. It is modelled the way it is mid-swing, pulled out straight by the
padlock with a slight sag, which is right while it is moving and a little odd standing
still.

| Layout | |
|---|---|
| `42/media/scripts/DansWeapons_items.txt` | the items |
| `42/media/scripts/DansWeapons_models.txt` | their model scripts: the mesh, and where each sits in the hand and on the ground |
| `42/media/scripts/DansWeapons_recipes.txt` | `Make...` and `ReclaimFrom...` |
| `42/media/lua/shared/DansWeapons.lua` | `DansWeapons.PARTS` (what each is made of), `OnBreak.<weapon>` (what is left when it breaks) and `DansWeapons.dismantle` (each part's wear when one is taken apart) |
| `42/media/models_X/`, `42/media/textures/`, `42/icon.png` | the models, textures and inventory icons, built in `art/weapons/` and copied in by `art/weapons/install.py` |
| `42/poster.png` | the mod list picture, written by `workshop/weapons/make_images.py` |

A new weapon is a model in `art/weapons/` (on `weapon_common.py`, `texture_common.py` and
`icon_common.py`), a row in `WEAPONS` in `art/weapons/install.py`, an item, a model
script, its recipes, a row in `DansWeapons.PARTS` with its `OnBreak` line, and its names.

**In game so far:** all five have been spawned and used (2026-11-16) and look and sit
right in the hands: the glaive on the cleaver's hand position, the one-handed three on the
rolling pin's. If a new one sits wrong, the game's attachment editor (debug mode) gives
the numbers for its model script.

Test `tests/test_weapons.lua`; deploy with `python deploy.py --mod DansWeapons`.

**Workshop page** (not yet uploaded): `workshop/weapons/` in the repo. `description.txt`
is the page, `workshop.txt` what the game's uploader reads (rebuild it with
`python workshop/steam_desc.py workshop/weapons` after any edit), and
`python workshop/weapons/make_images.py` draws `preview.png` (also this mod's
`42/poster.png`), `lineup.png` and `recipes.png` from Blender renders of the mod's own
models, with the numbers read from the item script. The page links the two big pictures
by their raw GitHub address, so they show once the commit is pushed.
`python deploy.py --workshop DansWeapons` builds the upload folder
(`~/Zomboid/Workshop/DansWeapons`).

# The overhaul: one Lua mod, a ZombieBuddy add-on

Design note, drafted 2026-11-09. Nothing built yet. It follows the Climate spike
(`plans/climate.md`), which proved a ZombieBuddy mod can be built, tested and loaded
from this repo.

## Why

The Vitality Project has grown to 39,000 lines of Lua and has only been played with a
long list of other mods loaded. Two things are wanted:

- **It works properly on the plain game.** A pass with nothing loaded but our own mods
  and Moodle Framework, so a fault is ours and not another mod's.
- **A ZombieBuddy edition that runs smoother.** Lua can only correct the engine after
  the fact. Java can change it at the source.

## Decisions taken (user, 2026-11-09)

1. **One Lua codebase.** The Vitality Project stays Lua-only. That is the edition for
   players without ZombieBuddy, and it is the product.
2. **The ZombieBuddy edition is an add-on mod,** not a second copy. It requires
   ZombieBuddy and the Vitality Project, and ships a jar the way `DansClimate` does.
   Working name: Vitality Engine, in `VitalityEngine/`.
3. **Moodle Framework stays required.** The 48 moodles stay Moodle Framework moodles.
   Native moodles are not pursued (see the facts below for what was found).
4. **The SpiffBoy cartridges are their own Workshop item** that adds to the Vitality
   Project when both are loaded.
5. **First, a pass with every other mod disabled.**

## Facts read 2026-11-09

- **Frame cost is already small.** The 1.5.1 measurement put the frame work at
  1.5 to 18 microseconds a frame; a 60 fps frame is about 16,700. The add-on will not
  raise the frame rate. The minute tick (66 systems plus the moodle reader) has never
  been timed: `frametime` times the frame handler only.
- **Seven stat pipelines correct the engine after the fact.** Each reads a stat, works
  out how much the game raised it, and writes back the adjusted value
  (`DanTraits_DeltaHook`). `enduranceRegen` and `panicRise` run every frame; `catchCold`,
  `foodSicknessRise`, `hungerRise`, `fatigueRise` and `boredomRise` every minute.
- **Things the code says Lua cannot reach:** the thermoregulator (MS, and the Hot Water
  Bottle keeps its own warmth clock), another character's gunshot or an explosion
  (Tinnitus), sprinting (Age traits poll for it), the wash menu (Laundry: built in Java).
- **Moodle Framework was a soft dependency** (made a hard one the same day, see the end
  of this note). `mod.info` had no `require=`. Without
  it all 48 moodles are skipped silently (`DanTraits_Client.lua:17`) and nothing replaces
  them. Its mod id is `MoodleFramework` (Workshop 3396446795, 2.8 installed).
- **Native moodles:** the game has `MoodleType.register(String)`, the same shape as the
  trait registry, but `Moodles` has no public way to set a level, so Lua cannot drive
  one. A Java patch could. Not checked: whether a registered type draws in `MoodlesUI`.
  Parked by decision 3.
- **Vitality Cartridges is already its own mod** (`VitalityCartridges/`, id
  `VitalityCartridges`, `require=\SpiffBoy`, 0.1.0, a deploy row). The Vitality Project
  reads it from `DanTraits_SpiffBoy.lua` by item id; the cartridges call back through
  `DanTraits_SpiffBoy` and `DanTraits_GuideExtra`, both nil-checked. What it lacks is a
  Workshop folder: `deploy.py --workshop` only knows DanTraits and MapLegend.
- **The state-machine survey is done and uncommitted** (`docs/state-machines.md`):
  22 machines declared through `DanTraits_Machine`, 9 defects fixed with tests, 13 open
  items. 32 files modified. The offline suite passes 123/123 as the tree stands.

## The shape

```
 Vitality Project        Lua only. Requires Moodle Framework. Everything it does today.
   ^         ^
   |         +-- Vitality Cartridges    own Workshop item; requires SpiffBoy
   |
 Vitality Engine         own Workshop item; requires ZombieBuddy and the Vitality Project.
                         A jar of patches plus one Lua file that switches ports over.
```

**Ports.** Each place where Lua works around the engine becomes a named port in core
with today's Lua as its implementation. The add-on's Lua file replaces a port with a
Java-backed one when its API global exists. The rules:

- **Same keys, same saves.** A port never changes the mod-data keys a system writes.
  The add-on can be added to or dropped from a running save.
- **Same states.** With and without the add-on, every declared machine reads the same
  state for the same inputs. `tests/test_machines.lua` is the check, run both ways (the
  harness stubs the Java API).
- **A Java failure falls back.** A port that throws switches itself back to the Lua
  implementation and logs once, as `GameBridge.fail` does in Climate. It never takes
  the game down.
- **One patch body, one call.** ZombieBuddy copies a patch's body into the game's class,
  so it may only call a public method of ours (the Climate crash, in its README).
- **Singleplayer first.** A server would need the add-on on both sides.

**Candidate ports,** in the order I would look at them. Each needs its Java side read
from bytecode before it is scheduled; none is verified beyond the Lua comments.

| Port | In Lua today | With the add-on | What it buys |
|---|---|---|---|
| Stat rises (the seven pipelines) | read the rise, write back the scaled value | scale where the game raises the stat | exact, no frame of lag; the two frame pipelines go |
| Body temperature | no hook; the bottle runs its own clock | a term in the thermoregulator | MS heat and the Hot Water Bottle act on real warmth |
| Sounds | no event for others' shots or explosions | a patch where the world sound is made | Tinnitus and Sensory hear everything |
| Sprinting | polled each frame | told when it starts and stops | one less frame system |
| The wash menu | rebuilt around the Java one | changed where it is built | Laundry's menu stops being fragile |

Blood, Fever and the pain floors also write over the engine each minute. Whether a
port helps them is unknown until the minute tick is timed and their Java side is read.

## Phases

0. **Commit the state-machine work.** It is the contract the rest is checked against.
   Waiting on the user's go.
1. **The plain-game pass.** Load the Vitality Project and Moodle Framework alone, then
   add our other mods one at a time (Dan's Vanilla Fixes, Base Unloader, Map Legend,
   Vitality Challenges). Use the `states` command and the open list in
   `docs/state-machines.md` as the checklist. Add a minute-tick timer beside `frametime`
   and record the number: it decides which ports are worth building.
2. **Cartridges to the Workshop.** A `workshop/cartridges` folder (workshop.txt,
   preview, description), its `workshop` key in `deploy.py`, a line on the Vitality
   page pointing at it.
3. **The Engine spike.** `VitalityEngine/` scaffolded from `DansClimate` (build.py, Main,
   an `Api` exposed to Lua), the port seam in core with tests, and one port: endurance
   regeneration scaled at the source. Done when the same save loads with and without
   the add-on and the same tests pass both ways.
4. **Ports by measured value,** from the table above.

## Open questions

- ~~Should `mod.info` say `require=\MoodleFramework`?~~ Yes (user, 2026-11-09): the line
  is in, and the pages say "Needs Moodle Framework". The game will not enable the
  Vitality Project until Moodle Framework is subscribed, current subscribers included,
  so the Steam notes for the next upload must say so and the Workshop page needs it
  under Required Items (set on Steam by the user). The nil checks around `MF` stay:
  a server has no Moodle Framework.
- **The add-on's name.**
- **Multiplayer** for the add-on: out of scope until singleplayer is proven.

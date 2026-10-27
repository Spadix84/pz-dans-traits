# Still Water: a breathing cartridge for SpiffBoy

Started 2026-10-25. The first Vitality cartridge, built with the SpiffBoy SDK
(Workshop 3825220785) for the SpiffBoy console (3825220364). See also the compat
file `DanTraits/42/media/lua/shared/DanTraits_SpiffBoy.lua`.

## What it is

A paced breathing exercise on the handheld. A disc on a dark pond grows while
you breathe in and shrinks while you breathe out; you hold A for the in-breath
(and any hold after it) and let go for the out-breath (and any hold after it).
No score to chase and no way to lose: the screen shows how even your breathing
is, and lily pads open on the pond as the good breaths add up.

## Three parts

1. **The cartridge mod**, `VitalityCartridges/` in this repo, its own Workshop
   item later. `mod.info` `require=\SpiffBoy`. Vitality never requires it, and it
   never requires Vitality: alone it is a calm little game, with Vitality it
   also does you good.
2. **The game**, `StillWater`, item `VitalityCartridges.Cartridge_StillWater`.
3. **The bridge** in Vitality: `DanTraits_SpiffBoy.lua` reads the running game's
   `vitality` table; Sensory, Strain and the compat file's own minute act on it.

## 1. The mod

```
VitalityCartridges/
    42/
        mod.info                id=VitalityCartridges, require=\SpiffBoy, versionMin=42.0
        poster.png              from cartridge_label.py's poster
        media/
            lua/shared/VitalityCartridges/Core.lua                    the namespace table, MOD_ID
            lua/shared/VitalityCartridges/Games/StillWater/Definition.lua
            lua/shared/VitalityCartridges/Games/StillWater/Translate/EN.json
            lua/client/VitalityCartridges/Games/StillWater/Game.lua
            lua/client/VitalityCartridges/Games/StillWater/Music.lua
            lua/shared/Translate/EN/ItemName.json                     "Still Water (SpiffBoy cartridge)"
            ui/VitalityCartridges/Games/StillWater/*.png              screen art (masks) and label.png
            scripts/VitalityCartridges/StillWater.txt                 the item and its model
            textures/VitalityCartridges/VitalityCartridgesCartridge_StillWater.png
            textures/Item_VitalityCartridges_Cartridge_StillWater.png
    tools/make_still_water_art.py     draws the masks and the label (Pillow)
```

- Layout like Dan's Vanilla Fixes (only `42/mod.info`, plus an empty `common/`).
- `deploy.py --cartridges` mirrors it to `~/Zomboid/mods/VitalityCartridges`.
- English only (the console falls back to English; we don't translate).
- Loot weight 1 (SpiffBoy's own cartridges are 2): the places consoles turn up,
  inside found consoles, on student and Spiffo's zombies.
- Game code is written fresh, not copied from Hello SpiffBoy; the SDK's
  licence is still "to be decided by the author". The label tool's blank
  cartridge art (`tools/cartridge/`) is the one SDK asset we use.
  **Before any Workshop upload: ask the author about the licence.**

## 2. The game

Screens: title, session, summary.

- **Title**: STILL WATER, then BREATHE, PACE (cycles CALM 4-6 / BOX 4-4-4-4 /
  4-7-8), SOUND (the ambient loop on or off), totals from the save.
- **Session**: the pacer runs in phases (in, hold, out, hold). Each phase's
  name and seconds left at the top; the disc in the middle (radius 6 to 40,
  one cell of a pre-drawn strip); the lily pads round the edge; an evenness bar
  at the bottom. A soft rising note starts each in-breath, a falling one each
  out-breath. START ends the session.
  - Matching: A held when the pacer wants in or hold-in, released for out or
    hold-out. 0.4 s of grace either side of each change, where both count.
  - `calm` (0..1): an average of the matched ticks over about one cycle
    (exponential, time constant one cycle), from 0 at the start of a session.
  - A breath (one cycle) is even when 80% or more of its ticks matched. Every
    five even breaths a lily pad opens, up to eight.
- **Summary**: the minutes, the even breaths, the best evenness. A or START
  saves (totals, pace, sound) and goes back to the title: the save happens on
  that press, as the console requires.
- The game exposes `self.vitality = { active = bool, calm = 0..1 }`, set every
  tick (active only in a session). It never reads the character: the game
  stays deterministic, so the SDK robot can test it.
- Fast forward: the console runs 2 to 6 times faster then, so the pacer does
  too. Not worked around; nobody breathes at 20x.
- Art drawn by a script (crisp masks, exact shades): the disc strip, a ring,
  two lily pad cells (closed, open) as a layered sheet, and the colour label.
- Draw calls: well under 100 (the texts are the most).

## 3. The bridge (Vitality)

`DanTraits_StillWaterCalm(player)` in `DanTraits_SpiffBoy.lua`: 0 unless a
Still Water session is on screen, else the game's `calm`, clamped 0..1.

| System | Effect a game minute, by calm c |
|---|---|
| Sensory Issues | drain x (1 + 1 x c): x2 at full calm, like a shower (`calmOf`, `S.CALM_BREATHE`) |
| Stress | -0.004 x c (0..1 stat): about a quarter off in an hour at full calm |
| Panic | -2 x c (0..100 stat) |
| Strain | 15 minutes at calm 0.6 or more in a day: the comfort `breathe` (2), its own kind, so it counts toward the variety bonus |

Old games (staleness) still applies to SpiffBoy's own boredom relief, as for any
cartridge; the effects above never fade.

Later, not in this build: Asthma (paced breathing between attacks), Heart
Condition (slower heart rate), Panic Disorder if we ever add it.

## Testing

- SDK robot on the mod (`run_robots.py`, 20000 ticks, three seeds): no crash,
  no warnings, draw calls, determinism. Its random buttons never breathe well,
  so a test of our own drives a few even cycles and checks calm and the lily pads.
- `tests/test_spiffboy.lua`: the bridge (the reader, Sensory, stress, panic,
  the Strain comfort), with a stub window holding a stub game.
- In game: the art, the sounds, the feel of the timing.

## Status

2026-10-25: built. The mod, the art, the game, the bridge, `deploy.py --cartridges`; the SDK
robot (three seeds clean, 55 draw calls at most), `tools/run_cartridge_test.py`, our suite
93/93. Deployed to `~/Zomboid/mods/VitalityCartridges` and Vitality. Not played. Open: the feel
of the timing and the sounds in game; the licence question before any upload.

## Steps

1. This plan.
2. Scaffold the mod, the art script, `deploy.py --cartridges`.
3. The game and its tunes; the robot.
4. The bridge and its tests; the full suite.
5. Changelogs (Vitality's for the bridge; the cartridge mod gets its own), deploy.

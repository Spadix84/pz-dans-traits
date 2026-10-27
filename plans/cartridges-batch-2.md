# Vitality Cartridges, batch 2: Steady, Spiffo Walk, First Aid Quiz, Spiffo Pup

Started 2026-10-25, after Still Water (`plans/still-water.md`). Four more games for
the `VitalityCartridges/` mod (requires SpiffBoy, now 0.1.7), each with its own
link into Vitality through `DanTraits_SpiffBoy.lua`.

## What SpiffBoy 0.1.7 gives us (checked 2026-10-25)

- A powered console that is put away (hidden) keeps stepping its game: the
  window's `OnPreUIDraw` loop calls `step()` on hidden windows, which advances
  the runtime. No input reaches it (held keys cleared) and nothing is drawn,
  but tunes play and the battery drains. Pocket games work.
- Mood relief (`SpiffBoy.Mood.applySecond`, now in a shared file, same
  constants) only applies while `isPlaying()`: shown, powered, a game running,
  and a button pressed within the last 5 seconds. Our staleness wrap still works.
- Our compat seams are unchanged: `forPlayer`, `putAway`, `runtime.game`,
  `definition.item`, `boot`, `glitch`, `linkLost`, `gameMissing`, `hidden`.

## The common pattern

- Each game keeps `self.vitality = {}` from `init`. Fields the game writes are
  read by Vitality; fields Vitality writes are inputs the game treats as
  optional (absent means a plain default), so the game stays deterministic and
  the SDK robot can test it without Vitality.
- Vitality writes its inputs once a game minute while the console is powered
  with that cartridge's game running, shown or in the pocket.
- Names: item `VitalityCartridges.Cartridge_<Id>`, class
  `VitalityCartridges<Id>Game`, art `media/ui/VitalityCartridges/Games/<Id>/`,
  texts `media/lua/shared/VitalityCartridges/Games/<Id>/Translate/EN.json`,
  tunes registered under `<Id>`. Loot weight 1 each. English only.
- Each game: art script `VitalityCartridges/tools/make_<id>_art.py` (masks in
  the four shades, a 388x212 colour label), the SDK's `cartridge_label.py` for
  the model texture and icon, the SDK robot clean on three seeds, and a scripted
  test `VitalityCartridges/tools/test_<id>.lua` run by
  `tools/run_cartridge_test.py`.

## 1. Steady (small)

A reflex test that shows how steady your hands and how quick your reactions
are right now.

- A target drifts round the screen (a seeded random walk); you hold a cursor
  on it with the arrows for a 20 second round. Score: the share of ticks on
  target. Verdict: STEADY (80%+), SHAKY (50%+), ALL OVER THE PLACE. Best saved.
- Inputs from Vitality: `vitality.tremor` 0..1 adds jitter to the cursor (up to
  3 px a tick, from `self.random`), `vitality.slow` 0..1 delays the arrows (up
  to 20 ticks).
- Vitality computes them (combined as 1 - product of (1 - each)):
  tremor: intoxication x0.8, alcohol withdrawal shakes 0.7, a diabetic low
  (`DanTraits_DiaLow`) x1, an MS flare 0.5, panic/100 x0.5, an adrenaline rush
  0.4, caffeine withdrawal x0.3; Steady Hands halves it unless the hands are
  shaking (withdrawal shakes or a low, as its own rule says).
  slow: concussion strength x1, intoxication x0.6, tiredness x0.5, a hangover
  x0.4, sumatriptan's day after 0.3.
- No effect on the character: it is a mirror.

## 2. Spiffo Walk (medium)

A pedometer pet. Leave the console on in your pocket and Spiffo grows as you walk.

- Input from Vitality: `vitality.steps`, a running count of the character's
  steps (never goes down), and `vitality.day`, the game day number. The game
  adds the rise since it last looked (ignoring a fall, or a jump over 2000 at
  once). Without Vitality nothing counts.
- Stages by total steps: egg (0), hatched (500), pup (3000), grown (10000),
  elder (30000). Every 1000 steps a treasure (one of eight hats, seeded), worn
  on the main screen. Today's steps against a goal of 2000.
- Saves on any button press while shown when there is something new (the
  console allows a save only on a press): steps since the last save are kept
  only while the console stays on.
- Vitality counts steps once a game minute: tiles moved on foot since the last
  minute x1.5 (nothing in a vehicle, nothing over 60 tiles a minute: a teleport
  or a load). Kept in `d.cwSteps`.
- Game writes `vitality.today`, `vitality.goalMet`. Vitality: the day's goal met
  is a Strain comfort `walk` (2), once a day, with a notice.

## 3. First Aid Quiz (medium, mostly writing)

- Rounds of ten multiple-choice questions (three answers, up and down to pick, A
  to answer) drawn without repeats from a bank of 40, seeded. After each
  answer the right one is shown with a one-line reason. Best score saved.
- The bank teaches what Vitality and the game actually do: bleeding and
  bandages, stitches and splints, infection and antibiotics, concussion signs,
  blood loss and shock, burns, sepsis, the medicines (painkillers,
  sumatriptan, anticonvulsants, insulin, beta blockers), dehydration and heat.
  Every answer checked against the Lua.
- Game writes `vitality.rounds` (finished rounds this power-on),
  `vitality.lastScore`, `vitality.lastTotal`.
- Vitality: a round of 8 or more, once a game day, gives First Aid
  (`Perks.Doctor`) 20 experience while First Aid is under level 3, with a notice.

## 4. Spiffo Pup (medium to large)

A Tamagotchi in the cartridge's save.

- Needs: food, fun, clean (0..100). Each game hour: food -8, fun -6, and a mess
  every 6 hours takes clean down 25. Lights off (sleep) halves the fall. Any need
  at 0 makes the pup sick; sick for 24 hours, it runs away (A hatches a new egg).
- Actions: FEED (+40 food), PLAY (a catch game, +10 fun a catch), CLEAN (clean
  back to 100), LIGHTS. Each action saves (it is a press).
- Time: input `vitality.hours`, the world's age in hours, from Vitality. The
  pup ages from the hours saved with it, so time passes while the console is
  off. Without Vitality it counts its own ticks while on (a 1 hour day).
- Game writes `vitality.care` (lowest need / 100), `vitality.gone`,
  `vitality.cared` (care actions this power-on).
- Vitality: a care action is a Strain comfort `pet` (2); MDD's floor drops by
  up to 8 while the pup was last seen cared for (care >= 0.5 within the last
  day: `DanTraits_PupCare`); the pup running away costs 15 unhappiness, once.

## The bridge (Vitality)

In `DanTraits_SpiffBoy.lua`: a reader for a running game of a given cartridge,
shown or pocketed (`gameOf(player, item)`), and one minute step per game
(inputs written, outputs read). New Strain comforts `walk` and `pet` (2 each);
MDD reads `DanTraits_PupCare`. Tests in `tests/test_spiffboy.lua`.

## Status

2026-10-25: built. Each game by its own agent from this plan, then reviewed here: Steady, Spiffo
Walk, First Aid Quiz (40 answers spot-checked against the Lua), Spiffo Pup; the bridge, with a
midnight fix (the Walk goal read before the new day is written). Five cartridges' scripted tests,
the SDK suite (three seeds, check_texts) and our suite 94/94 green; all five together on the robot
at 135 draw calls at most. Deployed. Not played.

## Order

Steady, Spiffo Walk, First Aid Quiz, Spiffo Pup; the bridge alongside. Each
game is self-contained in its own folders, so they can be built side by side.

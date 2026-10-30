# Vitality Cartridges changelog

Game cartridges for the SpiffBoy handheld console (Workshop 3825220364), made with
the SpiffBoy SDK (3825220785). Requires SpiffBoy. Plan: `plans/still-water.md`.

## 0.1.0 (in progress)

- **Menu cues honour SOUND OFF** (2026-10-29, review). Steady, Still Water, Spiffo Walk and
  First Aid Quiz played their move, select and nope cues straight from the sequencer, past the
  sound switch (Spiffo Pup already went through `cue`). Every cue goes through `cue` now.
- **Still Water** (2026-10-25), item `VitalityCartridges.Cartridge_StillWater`, loot weight 1
  (SpiffBoy's own are 2). Paced breathing on a pond: a disc grows for the in-breath and shrinks
  for the out-breath; hold A to breathe in (and through the hold after), let go to breathe out
  (and through the rest after). Paces 4-6 (in 4 s, out 6 s), box (4-4-4-4) and 4-7-8. In step,
  ripples spread and the disc is light; out of step it dims. 0.4 s of grace either side of each
  change. `calm` is the share of matched ticks averaged over about one breath; a breath with 80%
  of its ticks matched is even, and every five even breaths open a lily pad (eight). Soft cues
  for in, out and hold, and a slow pond loop (SOUND on/off). The summary's A or START saves the
  totals (even breaths, seconds, longest run), the pace and the sound. For the Vitality Project
  the game keeps `self.vitality = { active, calm }`; it never reads the character.
  Art drawn by `tools/make_still_water_art.py`; the model texture, icon and poster by the SDK's
  `cartridge_label.py`. Tests: the SDK robot (20000 ticks, no warnings, 55 draw calls at most)
  and `tools/run_cartridge_test.py` (in step, out of step, grace, the save, the pace menu).
- **Four more cartridges** (2026-10-25, `plans/cartridges-batch-2.md`; each with its own art
  script, label, scripted test and a clean SDK robot). Still Water's menu cues were given notes
  of their own (they were near the SDK example's).
  - **Steady** (`Cartridge_Steady`): hold a cross on a drifting ring for 20 seconds (2 of READY
    first); the share of ticks within 5 px is the score: STEADY 80+, SHAKY 50+, ALL OVER THE
    PLACE. Reads `vitality.tremor` (a carried push up to 3 px a tick, from `self.random`) and
    `vitality.slow` (the arrows delayed up to 20 ticks); writes `active`, `lastScore`. Best saved.
  - **Spiffo Walk** (`Cartridge_SpiffoWalk`): a pedometer pet that runs in the pocket. Reads
    `vitality.steps` (counts the rise; a fall or a jump over 2000 only re-bases) and
    `vitality.day`; writes `today`, `goalMet` (2000). Egg, hatched (500), pup (3000), grown
    (10000), elder (30000); a hat every 1000 steps (eight kinds, worn on the home screen). Saves on
    any press when something is new.
  - **First Aid Quiz** (`Cartridge_FirstAidQuiz`): rounds of ten from a bank of 40 (no repeats in
    a round, the deck reshuffled when spent), three answers, the right one and a reason after each.
    Every answer checked against the Vitality Lua. Writes `rounds`, `lastScore`, `lastTotal`.
  - **Spiffo Pup** (`Cartridge_SpiffoPup`): a Tamagotchi in the save. Food -8 and fun -6 an hour,
    a mess every 6 hours (clean -25), lights off halves it all; a need at 0 makes it sick, 24
    sick hours and it runs away. FEED, PLAY (a catch game, +10 fun a catch), CLEAN, LIGHTS.
    Reads `vitality.hours` (catches up the gap since its save, up to 72 hours; its own clock
    without it); writes `care`, `gone`, `cared`.

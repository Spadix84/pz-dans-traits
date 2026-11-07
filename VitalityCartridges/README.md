# Vitality Cartridges

Five game cartridges for the [SpiffBoy](https://steamcommunity.com/sharedfiles/filedetails/?id=3825220364)
handheld console mod, built with its SDK. Requires SpiffBoy. Part of the
[Vitality Project](../README.md) repository; the games work on their own, and with the
Vitality Project loaded they reach the character. Not yet on the Workshop.

| Cartridge | The game | With the Vitality Project |
|---|---|---|
| **Still Water** | Paced breathing on a quiet pond: 4-6, box, 4-7-8 | Even breaths calm a sensory overload, stress and panic |
| **Steady** | Keep a cross on a drifting ring for twenty seconds | The ring drifts the way your hands do: drink, shakes, a sugar low, a concussion |
| **Spiffo Walk** | A pedometer pet that hatches, grows and finds hats as you walk | The daily goal counts as a comfort against burnout |
| **First Aid Quiz** | Forty questions on wounds, infection and medicine | A good round teaches a little First Aid |
| **Spiffo Pup** | A pet to feed, play with and clean up after, hungry even while the console is off | A looked-after pup eases burnout and lifts a depressive episode's low mood |

Screen time on the console counts for the Vitality Project's screen-time and old-games
relief wherever the console is (a bag, the floor, a car); Spiffo Walk counts steps only from
a console you carry.

| Layout | |
|---|---|
| `42/media/lua/shared/VitalityCartridges/Core.lua`, `Games/<Game>/Definition.lua` | the cartridge items and what each game declares |
| `42/media/lua/client/VitalityCartridges/Games/<Game>/Game.lua`, `Music.lua` | each game, and its sequencer music |
| `42/media/lua/client/VitalityCartridges/Common.lua` | what the five games share (ink, numbers, the menu move) |
| `42/media/lua/client/VitalityCartridges/Guide.lua` | its page in the Vitality Project's Guide tab (does nothing without it) |
| `tools/` | the SDK robot tests (`run_cartridge_test.py`, one `test_<game>.lua` each) and the art scripts |
| `CHANGELOG.md` | its own changelog |

The bridge to the character is on the Vitality Project's side (`DanTraits_SpiffBoy.lua`):
each game keeps a small `self.vitality` table and never reads the character itself. Deploy
with `python deploy.py --mod VitalityCartridges`. The SDK tools run with `python -E -P`.

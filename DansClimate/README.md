# Dan's Climate Control

A Project Zomboid (Build 42) mod, in development. Buildings hold heat like real ones,
powered buildings have heating and air conditioning with a thermostat, and without
power you can install a window air conditioner or an electric space heater. The design
is in [plans/climate.md](../plans/climate.md).

Needs [ZombieBuddy](https://github.com/zed-0xff/ZombieBuddy) (2.3.4 or later): the game
decides indoor temperature in Java (`ClimateManager.getAirTemperatureForSquare`), which
Lua can't replace. Singleplayer for now.

| Layout | |
|---|---|
| `42/media/lua/shared/DansClimate_Climate.lua` | room temperatures, the Lua side: ticks the Java model each game minute, keeps the thermostats in global ModData |
| `42/media/lua/client/DansClimate_ThermostatMenu.lua` | the right-click thermostat for the building you're in, and the debug readout |
| `42/media/lua/shared/DansClimate_WindowAC.lua` | window AC: tiles and facings, the room it cools, install, remove, power, on/off |
| `42/media/lua/shared/TimedActions/DansClimate_WindowACActions.lua` | install and remove (screwdriver) and on/off timed actions |
| `42/media/lua/client/DansClimate_WindowACMenu.lua` | the right-click options, and the window with a unit in it staying shut |
| `42/media/lua/server/DansClimate_WindowACServer.lua` | units switch off when their power goes (checked every 10 game minutes) |
| `42/media/lua/server/Items/DansClimate_Distributions.lua`, `42/media/sandbox-options.txt` | where a window AC is found as loot (appliance shops, big-store electronics aisles, hardware stores; rarely warehouse crates and garages), and the Window Air Conditioner Loot (%) sandbox option |
| `42/media/scripts/DansClimate_items.txt`, `texturepacks/`, `*_tiledefinitions.tiles`, `depthmaps/` | the `Base.WindowAC` item and its tiles, built by `art/windowac/` |
| `java/src/com/spadix84/dansclimate/` | the Java side. `ZoneModel`: the room temperature maths, no game types. `GameBridge`: reads rooms, windows, doors, fires, window ACs, weather and power into it. `Api`: what Lua calls, as `DansClimateJava`. Patches: `AirTemperaturePatch` (indoors, the game reads the room's temperature), `WindowClimbPatch` (nobody climbs through a window with a unit in it). Patches and `Api` must be in this package itself: ZombieBuddy skips subpackages. A patch's `@Patch.OnEnter`/`OnExit` body is copied into the game's class, so it may only use public classes and members of ours (anything else crashes the game with IllegalAccessError); keep it to one call into a public method. `tools/build.py` fails the build otherwise |
| `java/test/` | plain-Java tests of `ZoneModel`, run by `build.py --test` |
| `42/media/java/DansClimate.jar` | the built jar ZombieBuddy loads (`javaJarFile` in `mod.info`) |
| `tools/build.py` | compiles the jar with a JDK 25 against the game's jar and ZombieBuddy's |

Build, then deploy:

```
python DansClimate/tools/build.py
python deploy.py --mod DansClimate
```

ZombieBuddy asks you to approve a Java mod the first time it sees a jar, and again
after each rebuild (the approval is tied to the jar's hash).

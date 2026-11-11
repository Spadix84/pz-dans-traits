# Dan's Climate Control

A Project Zomboid (Build 42) mod, in development. Buildings hold heat like real ones.
While the grid is up they have heating and air conditioning with a thermostat. Once
the power goes out that is gone, generator or not, and it is down to fires, an
electric space heater you put down and a window air conditioner you install (those
two run on a generator). With the know-how from two rare manuals and skill in Welding,
Maintenance and Electrical, you can install a furnace and a central air conditioner
of your own, and a vent in each room they should reach. Being cold or too warm for
what you are wearing wears on mood and energy, and a comfortable room in bad weather
lifts them (Comfort: it works with the plain game, and through the Vitality Project's
hooks when that is loaded).
The design is in [plans/climate.md](../plans/climate.md).

Needs [ZombieBuddy](https://github.com/zed-0xff/ZombieBuddy) (2.3.4 or later): the game
decides indoor temperature in Java (`ClimateManager.getAirTemperatureForSquare`), which
Lua can't replace. Singleplayer for now.

| Layout | |
|---|---|
| `42/media/lua/shared/DansClimate_Climate.lua` | room temperatures, the Lua side: ticks the Java model each game minute, keeps the thermostats in global ModData, tells Java when a unit appears or changes, reads the sandbox options |
| `42/media/lua/client/DansClimate_ThermostatMenu.lua` | the right-click thermostat for the building you're in, and the debug readout |
| `42/media/lua/shared/DansClimate_WindowAC.lua` | window AC: tiles and facings, the room it cools, install, remove, power, on/off, its fan (Low/High) and dial, the hum zombies hear |
| `42/media/lua/shared/TimedActions/DansClimate_WindowACActions.lua` | install and remove (screwdriver), on/off, and fan-and-dial timed actions |
| `42/media/lua/client/DansClimate_WindowACMenu.lua` | the unit's right-click entry (the room's temperature, on/off, Low/High, Cool to, remove), and the window with a unit in it staying shut |
| `42/media/lua/server/DansClimate_WindowACServer.lua` | units switch off when their power goes (checked every 10 game minutes) and hum for the zombies every 5 |
| `42/media/lua/shared/DansClimate_Heater.lua` | space heater: a vanilla moveable; its switch, Low/High and dial in ModData, power, the glowing tile drawn over a running one, the heat source beside it |
| `42/media/lua/shared/TimedActions/DansClimate_HeaterActions.lua` | on/off and Low/High-and-dial timed actions |
| `42/media/lua/client/DansClimate_HeaterMenu.lua` | the heater's right-click entry (the room's temperature, on/off, Low/High, Heat to) |
| `42/media/lua/server/DansClimate_HeaterServer.lua` | heaters get their glow and warmth back as they load, switch off when their power goes, and cut their elements in and out with the room |
| `42/media/lua/shared/DansClimate_Comfort.lua` | comfort: how warmly dressed, the comfortable band, the chill, stuffy and cosy meters, what they do to mood, tiredness and sleep, and the Vitality hooks (`fatigueRise`, `nightQuality`, `catchCold`, `homeGood`). `DansClimate.Comfort.get(player)` for other mods |
| `42/media/lua/client/DansClimate_ComfortClient.lua`, `42/media/ui/` | the three comfort moodles (Moodle Framework, optional) or a spoken line without it, and their icons |
| `42/media/lua/shared/DansClimate_Central.lua` | the furnace, the central air conditioner and the vent: which objects they are, the building each serves, the switch, power, what a unit is doing, the working look drawn over it, the hum, taking one out |
| `42/media/lua/shared/TimedActions/DansClimate_CentralActions.lua` | on/off, and taking a unit or a vent out with a screwdriver |
| `42/media/lua/client/DansClimate_CentralMenu.lua` | their right-click entries (the room's temperature, on/off, remove) |
| `42/media/lua/server/DansClimate_CentralServer.lua` | tells the Java side as they load and are built, keeps their look current, and hums a working central air conditioner for the zombies |
| `42/media/scripts/DansClimate_entities.txt` | the three build recipes (Furnace, Central Air Conditioner, Vent): each has to be learned and needs Welding, Maintenance and Electrical |
| `42/media/lua/server/Items/DansClimate_Distributions.lua`, `42/media/sandbox-options.txt` | where a window AC, a space heater, the central units and the two manuals are found as loot, and the sandbox options: Window Air Conditioner Loot (%), Space Heater Loot (%), Furnace and Central Air Conditioner Loot (%), Installer's Manual Loot (%), Window Air Conditioner Noise (tiles), Unit Generator Draw (%), Comfort and Comfort Strength (%) |
| `42/media/scripts/DansClimate_items.txt`, `texturepacks/`, `*_tiledefinitions.tiles`, `depthmaps/`, `textures/` | the items (`Base.WindowAC`, `Base.Mov_SpaceHeater`, `Base.HVACFurnace`, `Base.HVACCondenser`, the manuals `Base.BookHVACHeating` and `Base.BookHVACCooling`), their tiles and icons. The art is built by `art/windowac/`, `art/spaceheater/` and `art/hvac/` and packed by `tools/build_pack.py` |
| `java/src/com/spadix84/dansclimate/` | the Java side. `ZoneModel`: the room temperature maths, no game types. `GameBridge`: reads rooms, windows, doors, fires, units, weather and power into it. `Units`: window ACs, space heaters, furnaces, central air conditioners and vents as the game's objects (which they are, their settings, power, generator draw, which central units are working). `UnitHum`: the hum the player hears from a running window AC. `Api`: what Lua calls, as `DansClimateJava`. Patches: `AirTemperaturePatch` (indoors, the game reads the room's temperature), `WindowClimbPatch` (nobody climbs through a window with a unit in it), `GeneratorPoweredPatch` and `GeneratorDrawPatch` (generators count running units and burn fuel for them). Patches and `Api` must be in this package itself: ZombieBuddy skips subpackages. A patch's `@Patch.OnEnter`/`OnExit` body is copied into the game's class, so it may only use public classes and members of ours (anything else crashes the game with IllegalAccessError); keep it to one call into a public method. `tools/build.py` fails the build otherwise |
| `java/test/` | plain-Java tests of `ZoneModel`, run by `build.py --test` |
| `42/media/java/DansClimate.jar` | the built jar ZombieBuddy loads (`javaJarFile` in `mod.info`) |
| `tools/build.py` | compiles the jar with a JDK 25 against the game's jar and ZombieBuddy's |
| `tools/build_pack.py` | packs the three tile sheets into the texture pack and the tile definitions, and copies the depth maps and the icons |
| `tools/make_icons.py` | draws the three comfort moodle icons |
| `tools/check_scripts.py` | checks the scripts against each other: the build recipes, the manuals, the items and every translation key (`build.py --test` runs it) |

Build, then deploy:

```
python DansClimate/tools/build.py
python deploy.py --mod DansClimate
```

ZombieBuddy asks you to approve a Java mod the first time it sees a jar, and again
after each rebuild (the approval is tied to the jar's hash).

Tests: `python tests/run_tests.py climate`, `windowac`, `heater`, `central`, `comfort` (offline),
`build.py --test` (the model, then the scripts), and in a debug game
`tests/ingame/DansClimate_Test.lua` (modes `all`, `climate`, `extras`, `heater`,
`central`, `manuals`, `centralkit`, `comfort`; its header says how to run it).

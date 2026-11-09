# Dan's Climate Control

Design note, drafted 2026-11-09. Not built yet. A new mod, `DansClimate/`, in this
repo beside Dan's Vanilla Fixes. It needs ZombieBuddy, because building
temperature is decided in Java and Lua can't replace it.

## Why

The game's indoor temperature is a one-line rule:

- **With grid power, every room is exactly 22°C**, summer and winter, from a
  shack to a warehouse. Generators don't count, so a generator-powered base gets
  no heating or cooling at all.
- **Without power, a building closes a fixed share of the gap to 22°C:**
  40% at night and 60% at midday (85% of that gap on upper floors, or on the
  ground floor in summer). It reacts instantly: no thermal mass, so a house goes
  cold the minute the sun sets.
- **Nothing about the building matters.** Open or smashed windows, open doors,
  curtains, basements, the top floor under a hot roof, a lit fireplace filling
  the room: none of them change the room's temperature. A fire only warms the
  tiles in its own radius and line of sight.
- **There is no way to cool a room** after the grid goes down. Vanilla has an
  "Air Conditioner" moveable (`Mov_AirConditioner`, sprite `industry_01_4`) but
  it's decoration.

## Decisions taken (user, 2026-11-09)

1. **ZombieBuddy add-on**, its own mod, so DVF stays Lua-only.
2. **Indoor and outdoor temperatures feel closer to real**, shaped by the season
   and the sun.
3. **Existing buildings have built-in HVAC while powered**, by grid or
   generator, with a thermostat the player can set. When the power is gone,
   the player needs their own units.
4. **Player-installable units in v1:** a window AC unit and an electric space
   heater. A central HVAC unit to install is not in v1.
5. **Location:** `DansClimate/` in this repo, deployed with `deploy.py`.
6. **Toolchain:** Temurin JDK 25 (the game runs Zulu 25), built with `javac`
   directly, so no Gradle download is needed.

## Vanilla facts (B42, read 2026-11-09)

From bytecode in `projectzomboid.jar` (method names and constants, not
decompiled source).

- `ClimateManager.getAirTemperatureForSquare(sq, vehicle, doWindChill)` is the
  only place indoor temperature is decided. Everything above is its logic.
  After the indoor step it takes the higher of that and
  `IsoCell.getHeatSourceHighestTemperature`, then adds the vehicle's
  `getInsideTemperature()`.
- **Callers:** `Thermoregulator` (body temperature), `BodyDamage`,
  `CraftUtil`, `VehicleEngine`, `ui.Clock` (the temperature readout), and from
  Lua: fishing (`Bobber.lua`, `FishingUtils.lua`). Replacing the function
  changes all of them together, which is what we want.
- **Outdoor** (`ClimateValues.updateValues`):
  `temperature = dayMean + airMass*8 + 1 − 5*(1 − dayLightLagged) − 5*nightLagged`.
  The day/night swing is a fixed 10°C whatever the cloud cover. A lot of things
  read it directly: snow, puddles, sky, sound, `IsoWorld`, weather periods.
- **Indoors** = `IsoGridSquare.isInARoom()`: the square has an `IsoRoom` (map
  buildings), **or** its `IsoWorldRegion.isPlayerRoom()` is true (an enclosed,
  roofed space the player built). Player rooms have no `IsoRoom`, so they need
  their own zone key (the region ID).
- `IsoRoom`: `getBuilding`, `getRoomDef`, `getSquares`, `getWindows`,
  `isShop`, `isDerelict`. `IsoBuilding`: `getID`, `getDef`, `isResidential`,
  `hasBasement`.
- `IsoWindow`: `IsOpen`, `isSmashed`, `isGlassRemoved`, `isDestroyed`,
  `isBarricaded`, `HasCurtains` (→ `IsoCurtain`), `isNorth`.
- **Sun and weather:** `ClimateManager.getDayLightStrength`, `getCloudIntensity`,
  `getWindspeedKph`, `getHumidity`, `getSeasonProgression`,
  `getPrecipitationIntensity`.
- **Power:** `IsoWorld.isHydroPowerOn()` for the grid;
  `IsoGridSquare.haveElectricity()` for a generator (exterior squares only if
  the sandbox allows it). A generator's load is summed from
  `IsoObject.getGeneratorPowerConsumption()` over the objects it powers
  (`IsoGenerator.setSurroundingElectricity`), so our units can add their own
  draw by patching that method for their sprites.
- `IsoHeatSource` is exposed to Lua; `IsoCell.addHeatSource` /
  `removeHeatSource` are public.

## The model

One **zone** per room: an `IsoRoom` (key: room ID), or a player room (key:
world-region ID). Each zone has an air temperature `T` that steps once per game
minute:

```
dT/dt = k_env  · (T_sol    − T)      walls and roof, toward the sun-heated outside
      + k_gnd  · (T_ground − T)      floor slab or basement walls
      + k_vent · (T_out    − T)      open/broken windows and open outer doors, × wind
      + k_mix  · (T_bldg   − T)      air shared with the building's other rooms
      + Q_sun                        sun through unshaded windows
      + Q_fire                       lit fireplaces, stoves, campfires in the room
      + Q_units                      HVAC, window AC, space heaters
```

All the rates are per hour and are divided by the room's floor area (relative to
a 20-tile room) where they model a source, so a heater warms a closet faster than
a hall.

| Term | Value to start balancing from | Notes |
|---|---|---|
| `T_out` | vanilla outdoor temperature | unchanged in v1 |
| `T_sol` | `T_out + S·(8 top floor / 3 other)` | `S = dayLight·(1 − 0.7·cloud)` |
| `T_ground` | 30-day running mean of `T_out` | so basements are cool in summer, mild in winter |
| `k_env` | 0.08/h residential, 0.12/h shop or warehouse, 0.2/h derelict | time constant ~12 h for a house |
| `k_gnd` | 0.02/h ground floor, 0.10/h basement (z < 0) | |
| `k_vent` | 0.25/h per open or broken window, 0.5/h per open outer door, ×(1 + wind/20 kph) | planks halve it; glass-removed counts as broken |
| `k_mix` | 0.5/h | |
| `Q_sun` | 0.6 °C/h per window × `S` | closed curtains ×0.3 |
| `Q_fire` | 3 °C/h per lit fire in the room | |

This gives what the vanilla rule can't: lag (a house is still cool at 3 pm
and warm at 9 pm), sun-baked top floors, cool basements, cold drafts through
a smashed window in January, and a fireplace that warms the whole room.

**Rooms that haven't been seen yet** start at the model's steady state for the
current weather, with any working HVAC and units running. No zone state is
saved in v1. On load, rooms start from steady state again; only the thermostat
settings and the units are saved (in object and global ModData).

**Only zones in loaded chunks are stepped.** That's the rooms around the player,
a few dozen at most, so a per-minute step costs very little.

## Climate units

| | Built-in HVAC | Window AC | Space heater |
|---|---|---|---|
| Where | every non-derelict map building | a window square (the window can't open while it's in) | any floor tile |
| Power | grid; a generator if the building's squares have power | grid or generator | grid or generator |
| Effect | heats up to +6 °C/h and cools up to −4 °C/h toward the setpoint, for the whole building | cools its room up to −3 °C/h | heats its room up to +4 °C/h, plus a small `IsoHeatSource` so standing next to it feels warm |
| Control | thermostat: Off / Heat / Cool / Auto, setpoint (defaults 21 °C heat, 24 °C cool) | Off / Low / High, its own setpoint | Off / Low / High |
| Generator draw | high (sandbox) | medium | medium-high |
| Noise | none | a low hum every few minutes that zombies can hear (small radius, sandbox) | none |

**Mounting a window AC** (decided and built 2026-11-09; offline tests in
`tests/test_windowac.lua`; in game 2026-11-09, `tests/ingame/DansClimate_Test.lua` passes
42/42 in debug: install into an open window, `WindowClimbPatch`, the Lua guards, power,
the watcher, remove. Still to try by hand: the right-click menu and timed actions, a
save and reload, a zombie at a smashed window. The art is in `art/windowac/`):

- **Install:** right-click a window while carrying the unit and a screwdriver →
  *Install Window Air Conditioner*, a timed action of about 30 game seconds next
  to the window. The window must not be barricaded, open, or already holding a
  unit. The mod closes it first: the sash comes down onto the unit's top.
  A smashed or glass-removed window works too, and the unit and its side panels
  seal it, so its draft term drops to that of a closed window.
- **Which way it faces:** the front grille faces the side you stand on, and that's
  the room it cools. The object always goes on the window's own square, as tile
  `appliances_windowac_01_<n>`: S or N for a window in the square's north edge,
  E or W for one in its west edge (0-3 off, 4-7 on, in the order S, E, N, W).
  The room it cools is the window's square for S and E, the square to the north
  for N, and the one to the west for W.
- **While it's in:** the window can't be opened or climbed through, which closes
  that entry point. Hide the vanilla options in Lua, and if NPC or zombie paths
  ignore that, patch `IsoWindow.canClimbThrough` and `canOpen` in Java. Zombies
  can still smash the glass above it; the unit stays in.
- **Running it:** right-click → On/Off, Low/High, and a temperature dial. It needs
  power on its square (grid or generator). On swaps to tiles 4-7 (the green
  display). It draws generator fuel through the `getGeneratorPowerConsumption`
  patch, and it hums: a small world sound every few minutes that zombies can hear.
- **Remove:** right-click → *Remove Window Air Conditioner* with a screwdriver;
  the item comes back, and the window works normally again.
- **Saving:** the unit is an ordinary `IsoObject` with ModData (on, fan,
  setpoint), so the game saves it; Lua re-registers it with the Java model on
  `LoadGridsquare`.

**The thermostat** for the built-in HVAC is a context-menu option inside a powered
map building, which opens a small panel. Map buildings have no thermostat object
to click.

**Player rooms** (built by the player) have no built-in HVAC; only units.

**Items:** Window AC and Space Heater as moveables you can pick up and place. They
appear in appliance and hardware store loot and, rarely, in house garages and
storage rooms. Art: the vanilla `industry_01_4` sprite is an outdoor unit, so
both need new sprites. The Blender pipeline from `pz-slow-cooker/art` can make
them.

## Outdoors (optional, sandbox, off by default in v1)

- **Day/night swing follows the cloud cover:** clear nights colder, cloudy nights
  milder (swing ×(0.6 + 0.8·(1 − cloud))). This changes the global temperature,
  so snow, puddles and crops follow it, which is why it's opt-in.
- **Sun on the skin:** an outdoor square in daylight feels up to +4 °C
  warmer in clear weather (`S`·4). Only the feel; the global temperature is unchanged.

## How it's built

```
DansClimate/
  42/mod.info                  require=\ZombieBuddy, javaJarFile=media/java/DansClimate.jar,
                               javaPkgName=com.spadix84.dansclimate
  42/media/java/DansClimate.jar
  42/media/lua/shared/DansClimate_Core.lua      config, sandbox bridge, unit registry (ModData)
  42/media/lua/client/DansClimate_Menu.lua      thermostat and unit context menus, install actions
  42/media/lua/client/DansClimate_Thermostat.lua the thermostat panel
  42/media/lua/client/DansClimate_Guide.lua     its Guide tab page (does nothing without Vitality)
  42/media/scripts/DansClimate_items.txt
  42/media/sandbox-options.txt
  java/src/com/spadix84/dansclimate/
    Main.java                  exposes the API to Lua
    ZoneModel.java             zones, the step, steady-state start (no game types: unit-testable)
    GameBridge.java            reads rooms, windows, weather and power from the game into ZoneModel
    AirTemperaturePatch.java   ClimateManager.getAirTemperatureForSquare
    GeneratorDrawPatch.java    IsoObject.getGeneratorPowerConsumption
    WindowClimbPatch.java      IsoWindow.canClimbThrough
    (patches sit in the package itself: ZombieBuddy 2.3.4 skips @Patch classes in subpackages)
  java/test/...                plain-Java tests of ZoneModel (run with `java`, no JUnit)
  tools/build.py               javac + jar against projectzomboid.jar and ZombieBuddy.jar
```

- **The patch:** for an indoor square that isn't in a vehicle, return the
  zone's `T` instead of the vanilla indoor rule. Keep the vanilla steps after it
  (heat sources, vehicle), so campfires and car heaters behave as before. For
  outdoor squares and vehicles, change nothing (except the optional sun feel).
  The lookup is a hash-map read; the function is called every tick for each
  character, so it must stay that cheap.
- **The step** is driven from Lua `Events.EveryOneMinute` calling the exposed
  `DansClimate.tick()`, so it pauses with the game and follows the game speed.
- **Units** live as world objects with ModData. Lua re-registers them with Java on
  `Events.LoadGridsquare` and when they're placed, picked up or switched.
- **Singleplayer first**, like DVF. In MP the model would run on the server and
  the patch would need the zone temperatures sent to clients.

## Phases

1. **Scaffold:** JDK, `tools/build.py`, a patch that only logs, the
   `deploy.py` row, confirm in game that ZombieBuddy loads it. Done 2026-11-09: both
   patches apply and `[DansClimate] patch live` logs.
2. **The model for map buildings** with built-in HVAC and the thermostat panel,
   plus a debug readout (room temperature and each term) to balance against.
   Built 2026-11-09, tested in game the same day (climate mode 13/13; balancing not
   yet judged in play): `ZoneModel` (25 Java checks), `GameBridge`,
   `Api` and the patch returning the room's temperature; the thermostat is a
   right-click submenu (mode, heat to, cool to) rather than a panel; the readout is a
   debug-mode menu tooltip and the `climate` command. Window ACs already cool in it
   (a lit, powered unit blowing into the room). Not done: player-built rooms, saving
   zone temperatures, sun direction, sandbox options.
3. **Window AC:** item, art, placing it in a window, the cooling, the hum, the
   generator draw.
4. **Space heater:** item, art, placing it, the heating and its heat source.
5. **Player rooms, sandbox options, Guide page, CHANGELOG, balancing.**
6. **Outdoor options** (cloud-driven swing, sun on the skin).

## Open questions

- ~~Is ZombieBuddy active?~~ Yes: `~/Zomboid/console.txt` from 2026-11-08 shows
  `[ZB]` loading and Java mod approvals read from
  `~/.zombie_buddy/mod_approvals.json`. A new Java mod will ask for approval the
  first time it loads.
- **Art** for the window AC (two facings, on and off) and the space heater (four
  facings, glow when on).
- **Balancing:** the starting values above are guesses to tune in game with
  the debug readout.

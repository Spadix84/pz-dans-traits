# Dan's Climate Control

Design note, drafted 2026-11-09; built in steps since (see Phases). A new mod, `DansClimate/`, in this
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
   **Changed 2026-11-10:** the built-in HVAC runs on the grid only. Once the power
   goes out it is off for good, generator or not, and the player is left with fires,
   space heaters and window air conditioners, or the furnace and central air
   conditioner they install themselves (see Central heating and cooling the player
   installs).
4. **Player-installable units in v1:** a window AC unit and an electric space
   heater. A central HVAC unit to install is not in v1. **Changed 2026-11-10:** a
   furnace, a central air conditioner and vents, gated behind three skills and two
   rare manuals.
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
| Power | the grid only; dead once the power goes out (2026-11-10) | grid or generator | grid or generator |
| Effect | heats up to +6 °C/h and cools up to −4 °C/h toward the setpoint, for the whole building | cools its room up to −3 °C/h | heats its room up to +4 °C/h, plus a small `IsoHeatSource` so standing next to it feels warm |
| Control | thermostat: Off / Heat / Cool / Auto, setpoint (defaults 21 °C heat, 24 °C cool) | On/Off, Low / High, its own setpoint (16-30 °C, default 22) | On/Off, Low / High, its own setpoint (14-28 °C, default 21) |
| Generator draw | none: a generator doesn't run it | medium | medium-high |
| Noise | none | a low hum every few minutes that zombies can hear (small radius, sandbox) | none |

**As built (2026-11-09, second pass):**

- **Low and High:** a window AC cools up to 1.5 °C/h on Low and 3 on High; a space
  heater heats up to 2 °C/h on Low and 4 on High (in a 20-tile room; a smaller room
  moves faster). Each works toward its own dial and stops there.
- **The readout and the dial** are in the unit's right-click entry: *Window Air
  Conditioner (room 27 °C)* or *Space Heater (room 12 °C)*, then Turn On/Off, Low,
  High, and *Cool to* / *Heat to* with a list of temperatures. The tooltip says what
  the unit is doing. Settings live in the object's ModData (`DansClimateAC`,
  `DansClimateHeater`), which the Java side reads. A unit taken out or picked up comes
  back switched off with its fan and dial as they were: the AC's item carries them in
  its ModData, the heater's ride in `movableData`, the one table the game's furniture
  tools copy from an object to its item and back.
- **Generator draw** (litres an hour, as the game counts it: a stove is 0.09, a
  fridge-freezer 0.13): AC 0.07 Low, 0.11 High; heater 0.09 Low, 0.15 High; times the
  sandbox's Unit Generator Draw (%). Charged while the unit is switched on, whether or
  not it has reached its dial. Done with two patches on `IsoObject`:
  `couldBePoweredByGenerator` (the game then keeps units on the chunk's list generators
  add up) and `getGeneratorPowerConsumption`. The generator's info window lists them by
  their tile name. The building's own heating and cooling doesn't run on a generator
  at all (2026-11-10), so it has no draw.
- **The grid going down (2026-11-10):** the built-in HVAC is powered by
  `IsoWorld.isHydroPowerOn()` alone (`GameBridge.grid`, `C.powered()` in Lua). With the
  grid down the thermostat entry stays for its reading of the room, greyed, with no
  settings under it and a tooltip that points at fires, space heaters and window air
  conditioners. The thermostat's saved settings are kept, so they apply again in a
  sandbox where the power comes back.
- **The hum** is two things. Zombies: a world sound at the unit every 5 game minutes,
  radius 8 on High (sandbox, 0 to 30; 0 is silent) and 60% of that on Low. The player:
  the game's fridge hum, looped by the game's own ambient-object system while the unit
  runs (`UnitHum`, a `PerObjectLogic` added to the unit's chunk).
- **The space heater** is a vanilla moveable (`Base.Mov_SpaceHeater`, tiles
  `appliances_spaceheater_01_0-3`), so the furniture tools pick it up, place it and turn
  it; it doesn't block the square. Tiles 4-7 (elements glowing) are drawn over it
  while it's switched on. While its elements are on it is also an `IsoHeatSource`
  (radius 3 at 38 °C on High, radius 2 at 34 °C on Low); the elements cut out once the
  room is half a degree over the dial. The game doesn't save heat sources or overlays,
  so the watcher gives them back as heaters load. Outdoors or in a player-built room
  it still warms the squares beside it, but there is no room for it to heat.
- **Loot:** the heater has the window AC's shops and crates (appliance shop 10,
  Gigamart electronics 1.5, hardware store 1, electronics crate 0.3, garage 0.3, junk
  crate 0.1) plus `ClosetShelfGeneric` 0.2, times Space Heater Loot (%).

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

**The thermostat** for the built-in HVAC is a context-menu option inside a map
building, with its settings in a submenu while the grid is up. Map buildings have no
thermostat object to click.

**Player rooms** (built by the player) have no built-in HVAC; only units.

**Items:** Window AC and Space Heater as moveables you can pick up and place. They
appear in appliance and hardware store loot and, rarely, in house garages and
storage rooms. The window AC's loot was built 2026-11-09
(`server/Items/DansClimate_Distributions.lua`, `tests/test_climateloot.lua`): weight
10 on an appliance shop's shelf (`ElectronicStoreAppliances`, one roll), 1.5 in
`GigamartHouseElectronics`, 1 in `ToolStoreMisc`, 0.3 in `CrateElectronics`, 0.2 in
`GarageTools`, 0.1 in `CrateTools` and `CrateRandomJunk`, times the sandbox option
Window Air Conditioner Loot (%), 0 to 500. Not yet seen in game. Art: the vanilla `industry_01_4` sprite is an outdoor unit, so
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
   generator draw. Built 2026-11-09, the fan, dial, hum and generator draw in a second
   pass the same day (`tests/test_windowac.lua`; in game, `DansClimate_Test.lua` mode
   `extras`, not yet run).
4. **Space heater:** item, art, placing it, the heating and its heat source. Built
   2026-11-09 (`art/spaceheater/`, `tests/test_heater.lua`, 36 Java checks; in game,
   mode `heater`, not yet run).
5. **Player rooms, sandbox options, Guide page, CHANGELOG, balancing.**
5a. **Central heating and cooling the player installs:** built 2026-11-10, see its
   own section; in game, modes `central`, `manuals`, `centralkit`, not yet run.
6. **Outdoor options** (cloud-driven swing, sun on the skin).

## Central heating and cooling the player installs

Built 2026-11-10 (version 0.3.0), offline-tested, not yet run in game. Until a player
has it, nothing heats or cools a whole building once the grid is down.

**Decided by the user (2026-11-10):**

- The player installs a **furnace** and a **central air conditioner**. Both are
  **heavy items to find and haul home**, for now. The furnace is **electric**.
- It takes knowledge: gated behind **Maintenance, Welding and Electrical**, and behind
  **extremely rare books** that teach the installation. Books, not magazines: a
  magazine reads too fast.
- **Vents turn rooms on**, one per room, and the output is shared across them.
- Later, for immersion: an outdoor wood-burning boiler with a pump, or propane. Not
  now: the core electric units first, working and tested.

**As built:**

- **Three build recipes** (`scripts/DansClimate_entities.txt`, build menu, Furniture),
  each `NeedToBeLearn` with all three skills:

  | Recipe | Welding | Maintenance | Electrical | Uses |
  |---|---|---|---|---|
  | Vent (`DansClimate_Vent`) | 4 | 3 | 2 | 1 sheet metal, 2 small sheet metal, 4 screws, torch, rods |
  | Furnace (`DansClimate_Furnace`) | 5 | 5 | 5 | the Electric Furnace item, 2 sheet metal, 4 electric wire, 8 screws, torch, rods |
  | Central Air Conditioner (`DansClimate_CentralAC`) | 6 | 6 | 7 | the Central Air Conditioner item, 2 metal pipes, 1 small sheet metal, 6 electric wire, 8 screws, torch, rods |

  All need a welding mask and a screwdriver.
- **Two manuals**, 380 pages each (the size of the game's thickest skill book):
  *Residential Heating: An Installer's Manual* teaches the furnace and the vent,
  *Central Air Conditioning: An Installer's Manual* the central air conditioner and
  the vent. Loot at a tenth of a last-volume skill book's weight or less (0.2 on a
  trade bookshop's or hardware store's shelf, 0.05 in a library), times the sandbox's
  Installer's Manual Loot (%).
- **The units as loot** (`Base.HVACFurnace`, `Base.HVACCondenser`, 40 weight each, the
  same as a generator): appliance shop 2, generator room 1, generator crate 0.5,
  hardware store 0.2, metalwork and electronics crates 0.1, times Furnace and Central
  Air Conditioner Loot (%).
- **Where they go.** A furnace stands in a room of a map building and heats that
  building. A central air conditioner stands outdoors with a room of the building on
  one of the four squares beside it. Both block their square. A vent is a floor
  register and blocks nothing. A unit placed anywhere else works on nothing and its
  tooltip says why.
- **Sharing.** One furnace gives each vented room up to 6 °C an hour and one central
  air conditioner up to 4 (the strength of a building's own system), while the rooms
  with a vent add up to 120 tiles of floor or less. Past that the same output is
  spread: 240 tiles get half each. A second unit doubles the floor. The unit's tooltip
  warns when it is spread thin (`ZoneModel.centralShare`, `GameBridge.refresh`).
- **The thermostat** is the building's own. With the grid down it is dead unless the
  building has a furnace or a central air conditioner; then its menu works again and
  its tooltip says which of them answers. The units don't need the grid: a generator
  reaching the unit is enough (for the outdoor unit, either its own square or the
  room it is hooked up through).
- **Generator fuel:** furnace 0.40 L/h, central air conditioner 0.35, only while
  working (a vented room is off its setpoint and the thermostat's mode allows it),
  times Unit Generator Draw (%). The model decides that every ten game minutes and
  has the generators add up their load again when it changes. For scale, a space
  heater on High is 0.15 for a ninth of a furnace's heat.
- **Switch.** A unit is on from the moment it is built, and has Turn On / Turn Off in
  its right-click entry (*Furnace (room 12 °C)*). Unlike a space heater it doesn't
  switch itself off when the power goes: it picks up again when the generator does.
- **Noise.** A working central air conditioner hums: zombies hear it every 5 game
  minutes from 1.5 times the Window Air Conditioner Noise radius (12 tiles by
  default), and the player hears the game's fridge hum from it. The furnace is quiet.
- **Taking one out** is in the right-click entry and needs a screwdriver. The unit
  comes back as its item, on the floor if it is too heavy to carry. A vent's sheet
  metal is lost.
- **Art:** `art/hvac/` (Blender, the heater's pipeline), tile sheet
  `appliances_hvac_01` (id 3 in file 6743): 0-3 furnace, 8-11 central air conditioner,
  16-17 vent; 4-7 and 12-15 are the working looks (a lit lamp, a spinning fan) drawn
  over a working unit.
- **Tests:** `tests/test_central.lua`, `tests/test_climate.lua` (the thermostat),
  `tests/test_climateloot.lua`, 49 Java checks, and
  `DansClimate/tools/check_scripts.py` (recipes, manuals, items and translations
  against each other; `build.py --test` runs it). In game: `DansClimate_Test.lua` modes
  `central`, `manuals` and `centralkit`, not yet run.

**Not built, or not known yet:**

- **Map buildings only.** The room model has no player-built rooms, so a furnace in a
  cabin the player built heats nothing.
- **A paged book that teaches recipes is new ground:** no vanilla item has both
  `NumberOfPages` and `LearnedRecipes`. `ISReadABook` handles the two separately (the
  time comes from the pages; `complete()` calls `character:ReadLiterature(item)` for
  anything that isn't a skill book), so it should work. Mode `manuals` checks the
  pages, the reading time and that `ReadLiterature` teaches; reading one through by
  hand is the real proof. The fallback is `item:getModData().learnedRecipe`.
- **Whether the build menu shows the recipes under Furniture** with the `Welding` tag
  (copied from the game's welded counter), and whether it takes the heavy unit from
  the floor beside the player or only from the inventory.
- **The game's own dismantle** on a built unit: untested. Use the mod's Remove.
- **Upkeep** (filters, breakdowns), **a wood boiler or propane**, and a thermostat
  object to click: later.

**Vanilla facts (B42 scripts and bytecode, 2026-11-10):**

- Build recipes are `component CraftRecipe` on an entity, with `NeedToBeLearn = true`
  and `SkillRequired = MetalWelding:3`. Several skills go in one line, separated by
  semicolons (`Blacksmith:4;Tailoring:2`); `xpAward` likewise. `Electricity` and
  `Maintenance` are both used as requirements in vanilla (up to 6 and 5). A book's or
  magazine's `LearnedRecipes` names the entity (`Metal_CounterCorner_Lvl1`).
- `ScriptManager.getBuildableRecipe(name)` returns the recipe (`needToBeLearn()`,
  `getRequiredSkillCount()`, `characterHasRequiredSkills(character)`);
  `IsoGameCharacter.isRecipeKnown(String)`, `learnRecipe(String)`,
  `getKnownRecipes()`, `setPerkLevelDebug(perk, level)`.
- The last volume of a trade's skill books has weight 2 in `BookstoreBooks`,
  `BookstoreBlueCollar` and `ToolStoreBooks`, 1 in `LibraryBooks`, 0.5 in `CrateBooks`.
  A generator is weight 10 in `CrateGenerator` and nowhere else.
- The offline tests (fengari) can't read files: script checks have to be Python.

## Comfort: mood and energy from the temperature

Built 2026-11-10 (version 0.4.0), offline-tested, not yet run in game. The game's own
hypothermia and overheating cover the extremes; this covers the middle, where a 14 °C
house isn't dangerous but is miserable.

**Decided by the user (2026-11-10):** it lives in this mod only, so it can't conflict
with other systems; it works with the plain game as well as with Vitality; being
comfortable is a small buff, not just the absence of a penalty.

**As built** (`lua/shared/DansClimate_Comfort.lua`, `client/DansClimate_ComfortClient.lua`):

- **The reading**, once a game minute for each player. *Feels*: the air around the
  character with wind chill (indoors, the room's temperature from the model).
  *Warmth*, 0 to 1: the game's own clothing insulation over the body, weighted by
  skin, so wet, torn and worn clothes count for less. In bed the bedclothes add 0.35 to the cold end of the band
  only (2026-11-10, after a play-test: stripped for bed in a 75 °F room read too warm;
  the covers come off, so bed never lowers the warm end).
- **The comfortable band** moves with the clothes: 21 to 27 °C naked, about 16 to 25
  in a T-shirt and jeans, about 14 to 24 with a sweater over it, about 4 to 20 in
  full winter gear. Working hard lowers the cold end by up to 5 degrees. The thermostat's tooltip
  shows the character's band.
- **Three meters**, each 0 to 1, following their targets over about an hour: *chill*
  (under the band, full 8 degrees out), *stuffy* (over it), *cosy* (comfortable
  indoors in a room of 17 °C or more while it is 12 °C or colder outside, full at
  0 °C; or in a room of 26 °C or less while it is 28 °C or hotter outside, full at 36).
  Nothing in a vehicle.
- **What they do**, at a full meter, times the sandbox's Comfort Strength (%):

  | | Awake | Asleep |
  |---|---|---|
  | Chill | +2 unhappiness an hour (never past 40), +0.02 stress an hour (never past 0.4) | the night up to 15% worse |
  | Stuffy | tiredness builds 25% faster, +1 unhappiness an hour | the night up to 15% worse |
  | Cosy | −2 unhappiness and −0.03 stress an hour | nothing |

- **With the plain game** all of that goes straight onto the game's stats. A worse
  night is sleep taking 15% less tiredness off.
- **With the Vitality Project** the parts Vitality has a pipeline for go through its
  hooks instead, so they multiply with Vitality's own and aren't counted twice:
  `fatigueRise` (stuffy), `nightQuality` (a night in discomfort), `catchCold` (a full
  chill doubles the wet-and-cold meter's rise), and the new `homeGood` (what being at
  home does: a quarter more while cosy, half in a full chill or stuffiness). Vitality
  itself knows nothing about this mod; `homeGood` is an ordinary public hook
  (`DanTraits_Home.lua`, `API.md`).
- **Already following the room temperature without any of this:** Vitality's MS heat
  sensitivity, arthritis in the cold and sleeping in clothes read the game's air
  temperature for the character, which this mod supplies indoors.
- **What the player sees.** With Moodle Framework, three moodles: Chilly / Cold, Too
  Warm / Sweltering, and Cosy / Cool Indoors (icons from `tools/make_icons.py`).
  Without it, the character says a line when a level is reached.
- **Sandbox:** Comfort (on/off) and Comfort Strength (%).
- **For other mods:** `DansClimate.Comfort.get(player)` returns the meters and the last
  reading.
- **Tests:** `tests/test_comfort.lua`; in game, mode `comfort` prints the reading and
  each body part's insulation, for tuning.

**The warmth scale (fixed 2026-11-10 after a play-test).** The first build capped each
body part's insulation at 1, but the game's numbers run far past that: an item of
insulation x counts 2x + x³/2 on each part it covers (T-shirt 0.4, jeans 1.6, padded
jacket 2.3), layers add up, and each layer adds 0.05. So jeans alone read as full
winter gear on the legs, a T-shirt and jeans scored about 0.6, and a 75 °F room was
"too warm". Each part is now divided by `NODE_FULL = 3.5` (roughly a part in full
winter gear), which puts a T-shirt and jeans near 0.25. Worked out from the game's
scripts and classes, not yet read off in game; mode `comfort` shows the real figure.

**Decided by the user (2026-11-10):** the heat cost stays as it is. A hot day outdoors
tiring you faster (about 5% at 80 °F, 15% at 86 °F in a T-shirt and jeans) is wanted,
and it gives a reason to keep different clothes for different weather.

**Not known yet:** the real warmth figures in game. Tune `NODE_FULL`, `LOW_PER_WARMTH`
and `HIGH_PER_WARMTH` only if mode `comfort` shows the outfits scoring differently.

**Not built:** a warm room speeding recovery from illness (Vitality has no hook for
it), the hot water bottle mattering less in a heated room, a Guide page.

## Open questions

- ~~Is ZombieBuddy active?~~ Yes: `~/Zomboid/console.txt` from 2026-11-08 shows
  `[ZB]` loading and Java mod approvals read from
  `~/.zombie_buddy/mod_approvals.json`. A new Java mod will ask for approval the
  first time it loads.
- ~~Art for the window AC and the space heater.~~ Both built: `art/windowac/`,
  `art/spaceheater/`.
- ~~Should the heater block its square?~~ No, for now (user, 2026-11-10): it has no
  `solidtrans` and you walk through it.
- ~~Generator draw for the building's own heating and cooling.~~ Moot since
  2026-11-10: it runs on the grid only. The player's own furnace and central air
  conditioner draw 0.40 and 0.35 L/h while working.
- **Balancing:** the starting values above are guesses to tune in game with
  the debug readout.

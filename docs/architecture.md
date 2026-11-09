# How the Vitality Project works

A map of the mod as it stands on 2026-11-04 (1.5.2 built, not yet uploaded): what the pieces are,
how a game minute flows through them, how the files talk to each other, and where everything lives.
The companion assessment, what is solid and what is uneven, is `plans/review-2026-11-04.md`.

## The shape in numbers

| | |
|---|---|
| Lua in `DanTraits/42/media/lua` | 128 files, 37,800 lines: 91 shared, 24 client, 2 server, 9 timed actions, 2 server/Items |
| Sibling mods in the repo | Base Unloader 4.5k, Vitality Cartridges 2.8k (+0.9k SDK tests), Vitality Challenges 2.4k, Dan's Vanilla Fixes 1.9k, Map Legend 1.3k |
| Content | 93 traits (57 negative, 34 positive, 2 free), 45 items, 6 recipes, 73 sandbox options on 5 pages, ~2,000 EN strings (RU covers ~39%) |
| Moodles | 48 Moodle Framework moodles: 9 fed by their owners, 39 fed from one reader file; Reading has its own |
| Core seams in use | 86 clock registrations (66 minute, 5 ten-minute, 15 frame), ~95 named value hooks (214 subscriptions), 71 method wraps on ~55 targets, 16 player-ready steps, 7 stat-delta pipelines |
| Per-player state | one mod-data table, 511 distinct keys, prefixed per system (`alc*`, `nic*`, `inf*`, ...) |
| Offline checks | 113 test files green; the clock-order comment, every wrap target and every Java method name are checked against the installed game |

## The layers

```
 game        Java + vanilla Lua: Events, CharacterStat, BodyDamage, timed actions, UI classes
   ^
 core        DanTraits.lua (the seams), DanTraits_Util.lua (helpers, delta pipeline, pain floors),
             DanTraits_Food.lua (the one food classifier), DanTraits_Attrib.lua (dashboard attribution)
   ^
 systems     one file per trait or everyday system, ~85 files in five areas (below)
   ^
 showing     DanTraits_Moodles.lua (reads, never writes), the health panel, Guide / Notes / What's New,
             the client menus, Telemetry (the companion app)
   +
 content     scripts/DanTraits.txt, registries.lua, sandbox-options.txt, Translate/, Distributions, icons
   +
 adapters    six files that do nothing unless another mod is loaded (DTEM, Bandits, A-Life, SpiffBoy,
             Wound Expansion, This Is Your Life); Bathing for Take A Bath And Shower
   +
 tooling     tests/ (fengari harness + four checkers), deploy.py, DanTraits/tools (icons, reading table)
```

Every system file begins `require "DanTraits"` and gets the core's globals; nothing else is shared by
`require`. Files talk to each other at run time through globals (`DanTraits_<File><Thing>`), never at
load time, so load order only matters for the handful of files that wrap a class at load.

## Core: the seams

`DanTraits.lua` owns the only handlers for the game's lifecycle and clock events. Every other file
registers *into* core rather than with the game. The seams, in the order a new system meets them:

- **`DanTraits_OnPlayerReady(label, fn, order)`**: the one create-or-load sequence (migrate 10, retire
  20, trait cache 30, kits 40, Age 50, ... default 100). Core runs it from `OnCreatePlayer` and again
  from `OnGameStart` for every local player, so each step is written to run twice without effect.
- **`DanTraits_StartingKit(spec)`**: what a new character with a trait starts with.
- **`DanTraits_Every(cadence, label, fn, order, opts)`**: the minute, ten-minute and frame clocks.
  `opts.trait` gates a system on a trait and `opts.clear` takes its effects back when the trait goes;
  `opts.active` (frame) says whether the system needs frames right now. The order table in the file's
  comment is law: `tests/check_drivers.py` fails if a registration disagrees with it.
- **`DanTraits_DeltaHook(stat, name, cadence)`** (Util): the stat-delta pipeline. At order 0 it reads a
  stat, takes how much it *rose* since the pipeline last wrote it, offers that rise to the hook `name`,
  and writes back the adjusted value. Subscribers scale the game's rise and never see each other, so
  the factors multiply. Seven run: enduranceRegen and panicRise per frame; catchCold, foodSicknessRise,
  hungerRise, fatigueRise and boredomRise per minute.
- **`DanTraits_AddHook(name, fn, order)` / `DanTraits_RunHooks(name, value, ...)`**: named value hooks.
  A system offers a value (`nightQuality`, `enduranceRegen`, `eat`, `pill`, `infectionGrowth`, ...);
  every file that registered adjusts it in order. This is how Age multiplies two dozen things without
  touching their files, and how Positives is 279 lines of nothing but subscriptions.
- **`DanTraits_Wrap(class, method, tag, fn)`**: the one way to layer on a game method. Keyed by
  method and tag so wrapping twice is a no-op; refuses `new()` (multiplayer reads its parameter names).
- **`DanTraits_XpFactor(player, perk, amount, k)`**: one record per `AddXP` event; Age, AgeTraits,
  Fitness, Strain and ADHD each multiply into it, so penalties compound and can never exceed the gain.
- **`DanTraits_Guard(tag, fn, ...)`**: every call core makes into a system. Logs the first failure per
  tag, then is quiet; under `DanTraits_STRICT` (the tests) it raises instead.
- **`DanTraits_Data(player)`**: the per-player mod-data table, created and migrated
  (`DanTraits_MigrateModData` renames old keys at ready step 10).
- **`DanTraits_Machine(id, spec)`**: a system's phases declared once, next to its keys:
  `states` (rest first), a reader `of(player, d) -> state, info`, optional `trait` / `on`
  gates and a `load` step for a state that cannot outlive a save. Read through
  `DanTraits_StateOf(player, id)`, Telemetry's `machines`, the `states` console command.
  22 declared; the full list, the undeclared ones and the open defects are in
  `docs/state-machines.md`, which `tests/check_machines.py` keeps in step with the code.
- **`DanTraits_SetTrait` / `DanTraits_HasTrait` / `DanTraits_HasVanillaTrait`**: trait lookups, memoised
  per player for the frame driver and dropped once a minute or when the mod changes a trait.
- **`DanTraits_Notify` / `DanTraits_Story`**: a halo line that is also published as the Lua event
  `OnStoryEvent` for PZ Chronicle and the companion app.
- **`DanTraits_Later(frames, fn, tag)`**: run after n frames.
- **`DanTraits_Frame(player)`**: the movement snapshot read once a frame on first ask.
- **The eat and pill hooks**: core wraps `ISEatFoodAction` and `ISTakePillAction` once and runs the
  `eat`, `prePill` and `pill` hooks, so fifteen systems react to food and pills without each wrapping.
- **Pain floors** (Util): `DanTraits_PainFloor(player, d, source, floor, ramp, hold)` records a floor;
  the applier at minute 95 writes the largest to the head. Concussion, Sunburn and Gout write their own
  part by design.
- **Moodle helpers** (Util): `DanTraits_BadMoodle` for an owner-fed moodle, `DanTraits_LevelMoodle` for
  the reader file.

`DanTraits_Util.lua` also holds the copy-and-paste helpers (clamps, dice, body-part lookups, the
asleep check, the sandbox toggle, `DanTraits_Cough`, `DanTraits_DropHeld`, world-hours and
day-index) and `DanTraits_Food.lua` the one food classifier (`DanTraits_FoodTags(item)`), read by
nine systems.

## A game minute

```
EveryOneMinute
  core: for each local player (dead skipped), d = DanTraits_Data(player):
    0   the delta pipelines: catchCold, foodSicknessRise, hungerRise, fatigueRise, boredomRise
   10   Sleep                    light, clothes, wakes
   11   Home                     where the night was slept, the home's pull
   19   Clotting, Good Clotter
   20   Blood, Hot Water Bottle  loss this minute; the bottle's warmth clock
   21   Hemophilia
   22   WoundCare                dressings, stitches
   22.5 Illness                  catching, the courses, their symptoms; drives the game's cold
   22.9 Antibiotics (Fever)      the shared level decays
   23   Infection
   23.2 Fever                    every source's fever composed into SICKNESS: the only writer
   23.5 Age                      paces wound clocks, stiffness, intoxication, food sickness
   24   Concussion
   25   Fear of Blood
   30   Meds                     the drug levels every medicated system reads this minute
   35   Adrenaline
   39   Spoons                   MS's energy budget
   40   the conditions, by label: ADHD, AgeTraits, Alcohol, Anemia, Anger, Arthritis, Asthma, Brittle,
        Caffeine, CarpalTunnel, Cooking, Dehydration, Diabetes, Epilepsy, Fitness, Germaphobe, Gluten,
        Gout, Hangover, HayFever, Heart, Lactose, Laundry, MDD, Migraine, MS, Smoker, Sunburn, Thyroid,
        Tinnitus, Tremor, Triptan
   41   Grit, Headphones, SensitiveSkin, Sensory   (read what 40 left)
   42   Knox                     Resilient's roll against the zombie infection
   44   SpiffBoy                 screen time
   45   Strain                   burnout: reads fever, withdrawal, meal, Pumped, clothes, hangover
   50   AgeWants
   60   Hunted, Swarmed, Relaxant
   90   SleepMenu, Vitality      Vitality reads everything above, scores the night, applies lifts
   95   PainFloor                the largest registered head-pain floor is written
   96   Moodles                  reads what every system left in d, sets 39 moodles; writes nothing
  100   DTEM                     hands another mod's duplicate traits over

EveryTenMinutes:  10 Dependent   40 Laundry, MDD, Migraine   90 Hallucinations

OnPlayerUpdate (a frame): the player's frame set, rebuilt once a minute from each frame system's
  opts.active and opts.trait, so a character with nothing happening runs nothing:
    0 enduranceRegen, panicRise   20 Blood   22 WoundCare   24 Concussion
   40 AgeTraits, Alcohol, Arthritis, ArthritisGrip, Dependent, Gout, Heart, Meds, SensoryShutdown,
      Smoker, StrainKnock   45 Anger
```

Outside the clocks, core and a few files listen to the game directly: `AddXP` (the one record),
`OnWeaponSwing` / `OnPlayerGetDamage` / `OnPlayerAttackFinished` (hits: Blood, WoundCare, Concussion,
Brittle, Arthritis, Tinnitus, Heart), `OnFillContainer` (loot: Meds, Robbed, Bad Day, Reading),
`OnZombieDead` (Strain), `OnWorldSound` (Sensory), `OnClothingUpdated` (Sensory), `OnTick` (Faint's
pass-out hold, Hallucinations), and the context-menu events on the client.

## How systems talk to each other

Four ways, from strongest to weakest:

1. **Named value hooks.** The owner offers a value, subscribers adjust it. ~95 names; the busiest are
   `nightQuality` (18 subscribers), `enduranceRegen` (16), `eat` (15), `pill` (13), `sleepWake` (10).
   The owner never knows who subscribed. This is the mod's main integration mechanism and the reason
   Age, Positives and the lifestyle systems can reach a condition without editing it.
2. **Exported getters.** `DanTraits_Fever(player)`, `DanTraits_MedEffect(player, id)`,
   `DanTraits_HomeStrength`, `DanTraits_StrainFactor`, `DanTraits_AgeBand`, `DanTraits_IsPhantom`...
   The hubs most read this way: Faint (10 callers), Meds (16), Fever (13), Blood (7), Strain (6),
   Home (5), Age (many).
3. **Another file's mod-data keys, read by prefix.** Strain reads eight files' keys; Heart reads
   Smoker's and Sleep's; Spoons reads Sleep's and Vitality's; Moodles reads ~25 files' keys (by
   design: it is the reader). Works because the keys are stable, but nothing declares them public.
4. **The character's own stats.** Smoker and Dependent hold ANGER up; Anger.lua gives the Angry
   moodle consequences without knowing who raised it.

There are a few two-way dependencies (Heart <-> Adrenaline, Smoker <-> Strain, Migraine <-> Sensory,
Dependent <-> Hallucinations, Infection <-> Fever). All are late-bound globals, so none is a load
problem; they are simply pairs that have to be read together.

## The five areas

**Health and medical** (34 shared files, the health panel). Blood volume and red cells replace
bleeding-as-health-damage (Blood, Clotting, Hemophilia, Anemia); wound infection to sepsis
(Infection) and dressing and stitch care (WoundCare); one fever composed from every source (Fever),
with the catchable illnesses (Illness: cold, flu, pneumonia, strep, stomach bug, food poisoning) and
wound infection as its sources; one drug table of 27 medicines with build-up, half-life, side
effects and overdose (Meds), read by every medicated condition; Faint as the one pass-out; the
conditions themselves (Diabetes, Heart, Asthma, Epilepsy, MS + Spoons, Arthritis, Brittle, Gout,
Thyroid, Hay Fever, Carpal Tunnel, Tremor, Tinnitus, Dehydration, Sunburn, Concussion, Adrenaline,
Relaxant); Knox for Resilient's roll. The health panel shows all of it by First Aid level, and a
doctor can read a patient's blood over the server relay.

**Mind, mood and habit** (15 shared files). Three withdrawal meters with the same shape and no shared
code (Dependent for drink, Smoker for nicotine, Caffeine), Hangover and Alcohol's drink relief, MDD's
episodes and regimen, Migraine's triggers and attacks, Hallucinations' phantoms, Sensory's six-channel
load, ADHD, Anger (consequences for the vanilla Angry moodle), Germaphobe, Strain (burnout from
fighting, eased by comforts), Straight Edge, Bad Day, and Positives (nine traits that are pure hook
subscriptions).

**Everyday life** (25 shared files, 9 client). Vitality scores diet, exercise and sleep into one 0..1
value that lifts or drags a dozen systems through hooks; Fitness's muscle groups, plans and
magazines; Cooking's dish tiers and Fuelled; Reading (genres, tastes, real 1993 books; its own
cluster of five files); Laundry (five shared files around one `L` table: wash, dry, gear, traits);
Sleep, Home, Bathing, Hot Water Bottle, Steady Hands, Gym Regular, Vegetarian, Gluten, Lactose.
`nightQuality` and `nightScored` are the collection points for the night; `fitnessRecovery` and
`exerciseScore` for training.

**Age and the starts** (8 shared files). Age is four one-way layers: AgeRules (a table of which bands
may take which trait and at what price) <- Age (the band trait, ~30 multipliers pushed through ~21
hooks, spawn levels, a minute pass that re-paces wound clocks and stiffness) <- AgeTraits (fifteen
one-age traits) and AgeWants (daily wants per band). Behaviour is decoupled from vanilla traits except
Handy; prices still name eight vanilla ids by design. The five crippled starts (Bad Day, Wounded,
Robbed, Hunted, Swarmed) each set up the world once at creation; only Robbed uses the ready sequence.

**Showing and talking** (client). DanTraits_Client creates the Moodle Framework moodles, owns the
inventory and world context menus for the mod's items, and filters the creation screen (hidden
traits, the age gate and surcharge, Major Skills rows); TIYL does the same for This Is Your Life's
screen. Moodles.lua is the one reader that turns mod data into 39 moodle levels once a minute. The
Guide tab, Notes tab and What's New are rich-text pages over `DanTraits_GuideData`. Telemetry writes a
JSON snapshot twice a second for the companion app and takes its commands in debug mode; Attrib
credits every stat change to the system that made it while the dashboard is measuring.

## The content layer

`scripts/DanTraits.txt` declares the 93 traits (cost, exclusions, three disabled in multiplayer, seven
magazines' recipes), 45 items and 6 recipes; `registries.lua` registers the same 93 plus four retired
ones kept for old saves (`DanTraits_RETIRED` swaps them out at ready step 20). `sandbox-options.txt`
has 73 options on five pages (DanTraits 9, Health 24, Life 19, Laundry 15, Reading 6); nearly every
system has a switch, read through `DanTraits_SandboxOn/Num`. `Translate/EN` holds ~2,000 strings in
eight files (UI and Moodles are the big two); RU covers about 39%. `server/Items/DanTraits_Distributions`
appends the medicines and items to the game's loot tables from one spec list. Icons are drawn by
`DanTraits/tools/make_icons.py`; the reading table is generated from the game jar.

## Tooling

`tests/harness.lua` replaces `Events` with a recorder, stubs ~30 game globals (a player with `_md`,
`_st`, `_inv`; stats; body parts; the clock; dice you can load), loads Util, Food, core and the file
under test, then a test fires events (`H.fire`, `H.minute()`, `H.frame(p)`) and asserts. `run_tests.py`
first runs the four checkers: `lint_kahlua.py` (Kahlua's missing globals and its 200-local / 60-upvalue
caps, translation JSON), `check_api.py` (Java method names against the jar), `check_wraps.py` (every
wrapped vanilla method exists in the installed game), `check_drivers.py` (the order comment matches
the registrations). What they cannot catch: method arity, receivers they do not know, other mods'
table shapes, UI behaviour, multiplayer. `deploy.py` mirrors a mod into `~/Zomboid/mods` (and the
Workshop folder while it exists), builds the upload folder, and refuses to deploy if the two copies
of `DanShared_Tooltip.lua` differ.

## The sibling mods

None requires DanTraits in `mod.info`; Challenges and Dan's Vanilla Fixes soft-detect it (nil-checked
globals), Cartridges is read *by* DanTraits_SpiffBoy, Base Unloader and Map Legend are independent.
Each stands alone on the Workshop, so each has its own small guard, halo, sandbox-read and wrap
idiom. `DanShared_Tooltip.lua` (byte-identical in DanTraits and Dan's Vanilla Fixes, enforced by
deploy.py and a test) is the one shared-by-copy library and the model for sharing anything else.

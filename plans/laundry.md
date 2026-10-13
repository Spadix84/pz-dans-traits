# Laundry

Design note, drafted 2026-10-11, decided and BUILT the same day (deployed,
unplayed). Laundry lives in Vitality as a self-contained module, so it can be
lifted out into a standalone mod later. Where this note and the code differ,
the code is right; "As built" at the end lists what changed on the way.

## Why

Hand-wash floors (Dan's Vanilla Fixes, 2026-10-03) play well: a sink no longer
makes clothes spotless. Clean clothes now take a little thought, which fits a
mod about the body. But the rest of laundry is still free:

- **Wet laundry has no cost.** A wash sets wetness to 100. You can wring a
  garment to 10 in a few seconds, or simply wear it soaked and let your body
  heat dry it. Right now, pulling clothes out of the washer wet and putting
  them straight on is the best play.
- **Clothes never go stale.** A shirt worn for three weeks of sprinting through
  a Kentucky summer is the same shirt as on day one, apart from the dirt the
  game adds.
- **Old blood washes out like new blood**, so there is no reason to wash soon.
- **Off-grid, there is nothing between a sink and a washing machine.**
- **Washing has no cost at all to the garment.**

Vitality already reads dirty clothing: dirty or bloody clothing over a wound
raises infection risk 1.5x each (`DanTraits_Infection.lua`), and Germaphobe
counts the share of your body under dirty clothes. Laundry makes those effects
matter more.

Very few Workshop mods touch laundry, so there is room for a proper one.

## Decisions taken (user, 2026-10-11)

1. **Drying matters.** Wearing damp clothes for too long makes them stink. A
   "musty clothes" moodle gives a slight mood drop: a minor discomfort, never
   punishing. Clotheslines are wanted, especially for wilderness play.
2. **Set-in blood stains:** yes.
3. **Washboard tier:** yes.
4. **Sweat and wear make clothes stale:** yes.
5. **Washing wears fabric:** yes.
6. **Master sandbox toggle**, and the options get their own sandbox page.

Facts from the user, checked against the game files below: B42 has soap,
cleaning liquid and bleach; clothes get dirtier from ordinary wear; clothesline
tiles exist.

## Vanilla facts (42.21, read 2026-10-11)

Paths are relative to `ProjectZomboid/media`. Java behaviour comes from
reading bytecode names and constants, not decompiled source.

- **The wash action** is `ISWashClothing` (shared/TimedActions).
  - Water used: `ceil(4 + blood*3 + dirt)` per covered part.
  - Soap: one use per bloody part, from a Soap2 bar (`UseAndSync`) or 0.0999 L
    of cleaning liquid.
  - `complete` zeroes blood and dirt, then calls `setWetness(100)` and
    `setDirtiness(0)`.
  - Duration: `(blood + dirt) * 15`, capped at 500. Without soap it is x5,
    capped at 800, with a floor of 100.
- **The Wash / Wash All menu is Java** (`ISWorldObjectContextMenuLogic`). It
  calls back into Lua through `ISWorldObjectContextMenu.onWashClothing`.
- **Soap list:** `getSoapList` (Java) returns Soap2 bars and containers that
  hold at least 49.9% cleaning liquid. **Bleach is never on it.**
  `ISWashClothing.useSoap` drains any fluid container it is handed, so we must
  never put bleach into `self.soaps`.
- **Wringing:** `ISWringClothing` caps wetness at 10 (60 for shoes). It takes
  `wetness * 5` ticks and is offered above 15 wetness.
- **Drying is all Java.**
  - Worn clothes dry in `ClothingWetness.updateWetness`, using body heat, skin
    and air temperature, and perspiration. Sweat therefore already wets worn
    clothes.
  - Washer and dryer cycles run in `ClothingWasherLogic` /
    `ClothingDryerLogic`.
  - No Lua dries clothes, and nothing dries them near a fire.
- **Dirt from wear is Java** (`IsoGameCharacter.addDirt`,
  `Clothing.getClothingDirtynessIncreaseLevel`).
- **Clothing API** (note the spelling "Dirtiness"):
  `getWetness/setWetness`, `getDirtiness/setDirtiness`,
  `getBlood(part)/setBlood`, `getDirt(part)/setDirt`, `isDirty` (> 15),
  `isBloody` (> 25), `getCondition/setCondition`, `syncItemFields`.
- **Items:**
  - `Base.Soap2`: drainable, 20 uses.
  - `Base.CleaningLiquid2`: fluid container, 0.5 L of CleaningLiquid.
  - `Base.Bleach`: fluid container, 1 L of Bleach.
  - `Base.Rope` and `Base.Twine` also exist.
  - There is **no washboard, wash tub, clothes peg or laundry recipe**.
- **Bleach in vanilla** is used only on floors (`ISCleanBlood`, 0.25 L) and
  graffiti. Nothing uses it on clothes.
- **Stats:** `CharacterStat.UNHAPPINESS` and `CharacterStat.DISCOMFORT` both run
  0-100, changed with `getStats():add/remove/set`. `ISWashYourself` is an
  example.
- **Clotheslines on the map.** There are no named clothesline tiles; the likely
  candidates are unlabelled:
  - `appliances_laundry_01_26..29`: Material MetalPipe/MetalWire,
    PhysicsShape Tree. Probably the posts.
  - `appliances_laundry_01_30/31`: MetalWire. Probably the line.
  - None of them is moveable, has a container, or is referenced by any Lua.
  - The laundry cart (`appliances_laundry_01_24/25`, container
    `clothingdryerbasic`) does no drying.
  - The crafted drying racks are for herbs and leather.
- **Sandbox pages.** The sandbox screen is one flat list of pages, with no
  nesting (`ServerSettingsScreen.lua:5128-5151`). Each distinct `page =` value
  becomes its own entry, titled from `Sandbox_<page>`. A page appears in the
  list where its first option is registered, so pages from one mod stay
  together. Evolving Traits World ships five pages and True Smoking two.

## The design

### One number per garment: odour

Each garment carries a little state in modData (`DT_Laundry`):

| Field | Meaning |
|---|---|
| `odour` | 0-100. Sweat and wear push it up; washing brings it down |
| `musty` | true once the garment stayed damp too long. Any wash clears it |
| `wetSince` | game hour the garment was first seen damp (cleared when dry) |
| `bloodSince[part]` | game hour blood was first seen on a part |
| `stain[part]` | set-in blood floor for a part (0-1) |
| `washes` | count, for the tooltip and wear |

The state is created lazily, the first time a garment is seen. A garment the
player never touches costs nothing.

### 1. Damp clothes go musty

- A garment counts as **damp** at wetness 30 or above. When it is first seen
  damp, its `wetSince` is stamped.
- If it is still damp `LaundryDampHours` later (default 6), it turns **musty**:
  `musty = true` and its odour is raised to at least 80.
- Drying below 10 clears the stamp. That dry-out line is a constant, not an
  option.
- **Wearing it counts 1.5x.** Damp fabric against warm skin is how clothes go
  sour. A garment worn soaked from the washer, drying only by body heat, should
  usually turn musty unless the day is hot.
- Sightings are checked every ten minutes on worn clothes and on everything
  carried, including bags. Any other garment is checked when it is next picked
  up or looked at, against its stamp. That way wet clothes stuffed into a
  dresser are musty when you come back, if the game did not dry them in the
  meantime (spike S1).
- **Wringing leaves clothes damp.** While laundry is on, `ISWringClothing`
  stops at `LaundryWringLeaves` (default 50; shoes 70) instead of 10. Wringing
  then saves time but does not skip the drying.
- **Ways to dry**, all bounded by the damp clock:
  - Dryer: vanilla.
  - Body heat: vanilla, counts 1.5x.
  - By the fire: new, see below.
  - Clothesline: new, phase 6.

**By the fire** (new timed action, "Dry by the Fire"). It is offered on a damp
garment within 2 tiles of a lit campfire, fireplace, wood stove or barbecue.
You hold the clothes up and turn them. Wetness falls by about 1 point per
in-game minute, so a soaked shirt takes about an hour and a half; the exact
rate is tuned in S1. It works on several garments at once, like Wash All.
Leaving the fire interrupts it.

### 4. Sweat and wear make clothes stale

Worn garments gain odour while worn:

| Source | Odour per game hour | Notes |
|---|---|---|
| Just wearing it | +0.4 | about 10 a day |
| Exertion (endurance below 90%, running, sprinting or fighting) | +1.5 | |
| Heat (body temperature 37.5 °C or above) | +1.0 | |

- **Layers:** items against the skin (underwear, socks, shirts, trousers,
  dresses) gain the full rate. Outer layers (jackets, coats, vests) gain half.
  Accessories, bags, armour plates, watches and jewellery gain none. The
  body-location lists live in one table.
- **Targets:** a quiet day indoors is about +10, so clothes go stale in about 5
  days. A summer looting day is about +20, so about 2.5 days.
- **Washing brings odour down:**

  | Wash | Odour afterwards |
  |---|---|
  | Hand wash without soap | down to 30 at most |
  | Hand wash with soap or cleaning liquid, or a washboard (with or without soap) | 0 |
  | Washing machine | 0 |

  Every wash clears `musty`. Then the garment is wet again, and the damp clock
  starts over.
- **Airing out:** a garment drying on a clothesline in daylight loses 5 odour
  an hour, but never below 30. You need a wash to get it fresh.

### The moodle: Stale Clothes

There is one moodle, worked out from worn garments only:

| Level | When | Effect |
|---|---|---|
| 1 "Stale Clothes" | the worst worn garment has odour 50+ | +0.5 unhappiness per hour while unhappiness is under 20 |
| 2 "Musty Clothes" | anything worn is musty, or odour 80+ | +1 unhappiness per hour while unhappiness is under 30 |

- **The caps keep it a minor discomfort.** Laundry never pushes you into
  depression by itself.
- `LaundryMood` (0-200%) scales the effect. At 0 the moodle still shows but
  costs nothing.
- **Germaphobe** feels it twice as much, with caps 10 higher. Stale and musty
  worn garments also count as dirty for Germaphobe's clothing share.
- **Infection:** a musty garment over a wound counts as dirty clothing. That is
  the existing x1.5; nothing new stacks on top.
- **Tooltip lines** on garments:
  - "Damp, musty in about 3 hours"
  - "Stale" or "Musty"
  - "Set-in stain"
  - "Washed 12 times"

### 2. Set-in blood stains

- When blood is first seen on a part, the part's `bloodSince` is stamped. It is
  cleared when that part's blood reaches 0.
- After `LaundryStainDays` (default 3; 0 turns stains off), the part gets a
  stain floor: half the blood on it at that moment, capped at 20%.
- **The cap is deliberate.** It keeps a washed, stained garment under the
  vanilla "bloody" line, so stains are cosmetic plus a wash floor. They never
  count as bloody clothing for infection. That depends on the threshold
  `hasBloodyClothing` uses, checked in spike S5.
- **Every wash** (hand, washboard, machine) floors each part at
  `max(method floor, stain)`. The machine no longer clears an old stain.
- **Bleach removes stains.** A world context option, "Bleach Stains", appears on
  any water source the wash menu uses, when you carry stained garments and
  bleach.
  - It uses 0.1 L of bleach per garment, plus water as a normal wash.
  - It clears stains and blood, and leaves the garment wet.
  - It always rolls fabric wear at the harsh rate.
  - It is our own timed action, `DT_ISBleachClothing`, so bleach never reaches
    `ISWashClothing.useSoap`.
- **Later idea:** bleach could fade the garment's tint toward white.

### 3. The washboard

- **A new item, Washboard** (weight 1.0). It works from your inventory: any hand
  wash uses the washboard floors (dirt and blood down to 25% without soap, 10%
  with), takes 1.5x as long, and sets odour to 0.
- **Loot:** laundry rooms, farmhouses, general and antique stores. The exact
  distribution keys are picked when building.
- **Recipes:**
  - Carpentry: 1 plank, 1 sheet metal, 4 nails, a hammer.
  - Wilderness: 1 plank or split log plus a knife, Carving 2.
- **Assets:** an icon (through `tools/make_icons.py`) and a world model.
  Without a model it shows the generic dropped-item look, which is acceptable
  for a first cut.
- **No new tub item.** Washing happens at the sinks, barrels and water tiles
  vanilla already offers. Whether a bucket of water on the floor can be a wash
  source is checked in S1. If it can, that is the tub.

### 5. Washing wears fabric

- **Each wash rolls a chance** to take 1 condition off the garment. Condition
  never goes below 1, and washing never adds holes.

  | Method | Chance per garment |
  |---|---|
  | Hand | 1% |
  | Washboard | 3% |
  | Machine | 4% |
  | Bleach | 25% |

- **`LaundryWear` enum:** Off, Gentle (x0.5), Normal, Harsh (x2).
- **Spike S4** checks that `setCondition` on Clothing does not fall out of step
  with holes or insulation. If it does, wear moves to a cosmetic "worn" tooltip
  only.

### Hand-wash floors move from DVF

Vitality's laundry wash wrapper takes over the hand-wash floors and widens
them: method floors, stains, odour, wear and wash count.

**Recommended:** Dan's Vanilla Fixes keeps its washing file for players who do
not run Vitality, but steps aside when Vitality's laundry is on. It checks
`DanTraits_Laundry and DanTraits_Laundry.active()` at the top of both wrappers.
DVF's two options get a tooltip line: "Ignored while Vitality's laundry is on."
A later standalone laundry mod gets the same handshake.

Alternative: delete it from DVF. That is simpler, but DVF users who never
installed Vitality lose a feature they have.

### 6. Clotheslines (last, highest risk)

This is the piece wilderness play wants most, and the riskiest, so it is built
last.

- **Map clotheslines.**
  - Spike S2 first confirms that `appliances_laundry_01_26..31` are posts and
    a line. It places them with the brush tool and looks at them.
  - Then it tries to give those sprites a container named `dt_clothesline`
    (capacity 15) in `Events.OnLoadedTileDefinitions`, and checks whether
    already-explored map objects pick it up.
  - **Fallback:** create the container in Lua (`obj:setContainer`) the first
    time someone chooses "Hang Laundry" on the object, and check that it saves.
- **Building one.**
  - It is a build-menu entity like the vanilla drying rack, using the post
    sprites.
  - Recipe: 2 planks or 2 long sticks, plus 1 rope or 3 twine. No skill
    needed.
  - Spike S3 checks whether an entity can use a post-and-line layout or needs
    one free-standing tile.
  - A line strung between two trees is a nice later idea, but out of scope.
- **Drying model, per game hour on a loaded line:**
  - Wetness falls by 20 x temperature x wind x light.
    - Temperature: under 0 °C x0.2, under 5 °C x0.4, over 20 °C x1.5.
    - Wind: x1 to x1.5.
    - Light: clear daylight x1.3, night x0.5.
  - Rain adds 40 an hour.
  - Under a roof: x0.6, no weather.
  - Sun freshens laundry as described under airing out.
- **Unloaded lines** catch up when they load, from a `lastUpdate` stamp, using
  the climate at that moment.
- **Only loaded lines are visited.** They register through
  `Events.LoadGridsquare` and unregister on unload. Nothing scans the world.

## Sandbox pages

The current single "Vitality Project" page has 25 options, and laundry would
add 12 more. Splitting it costs nothing:

- **Option names stay `DanTraits.*`**, so existing saves keep their values; the
  page is display only (to be confirmed in spike S6).
- **New pages need only new translation keys**, in EN and RU.

| Page (key) | Title | Options |
|---|---|---|
| `DanTraits` | Vitality: General | Age* (6), KnoxSurviveChance, StartingMedication |
| `DanTraitsHealth` | Vitality: Health | Blood, Infection, WoundCare, Concussion, Vitality, Sunburn, Dehydration, MedSideEffectChance, MSSpoons, InhalerLoot, ArthritisWeaponDrop |
| `DanTraitsLife` | Vitality: Daily Life | SleepLight, Home, Hangover, DrinkRelief, AngerEffects, SmokerCravingMoodle |
| `DanTraitsLaundry` | Vitality: Laundry | the options below |

The options in `sandbox-options.txt` are reordered so the pages appear
together, in this order.

**Laundry options:**

| Option | Type | Default |
|---|---|---|
| `LaundryEnabled` | boolean, master switch | true |
| `LaundryHandFloor` / `LaundryHandSoapFloor` | 0-100 | 40 / 20 |
| `LaundryBoardFloor` / `LaundryBoardSoapFloor` | 0-100 | 25 / 10 |
| `LaundryWringLeaves` | 0-100 | 50 |
| `LaundryDampHours` | 1-48 | 6 |
| `LaundryOdourRate` | 0-300% | 100 |
| `LaundryMood` | 0-200% | 100 |
| `LaundryStainDays` | 0-30 (0 = no stains) | 3 |
| `LaundryWear` | enum Off / Gentle / Normal / Harsh | Normal |
| `LaundryClotheslines` | boolean | true |
| `LaundryLineDryRate` | 25-300% | 100 |

**With `LaundryEnabled` off:**

- Nothing in this note runs, and wringing is vanilla again.
- DVF's floors apply again if DVF is loaded.
- Existing garment modData is left alone, so turning laundry back on picks up
  where it stopped.

## Code shape

Everything has the `Laundry` prefix and one global, `DanTraits_Laundry`, so the
standalone mod later is mostly a copy:

| File | Job |
|---|---|
| `shared/DanTraits_Laundry.lua` | State, odour, damp clock, stains, wear rolls. Pure logic, unit-tested |
| `shared/DanTraits_LaundryWash.lua` | Wraps `ISWashClothing:complete` / `ISWringClothing`, and the floors moved from DVF |
| `client/DanTraits_LaundryClient.lua` | Context options (bleach, dry by the fire, hang), the wash-menu filter, tooltip lines |
| `shared/TimedActions/DT_ISDryByFire.lua`, `DT_ISBleachClothing.lua` | New timed actions |
| `shared/DanTraits_Clothesline.lua` | Phase 6 |
| `DanTraits_Moodles.lua` | One new moodle entry with two levels; icons through `make_icons.py` |
| `scripts/DanTraits.txt` | Washboard item and recipes; clothesline entity (phase 6) |

- **Traits read laundry through two functions, never its internals:**
  `DanTraits_Laundry.wornOdourShare(player)` for Germaphobe, and
  `DanTraits_Laundry.isMustyOver(part)` for Infection. Both return nothing when
  laundry is off or absent.
- **Cost:** one ten-minute tick over worn and carried clothing. There is no
  world scan.
- **Multiplayer:** like the rest of Vitality, this is client-side
  singleplayer-first. Garment modData changes go through `syncItemFields`
  where vanilla does. Clothesline containers need the server pass from
  `plans/multiplayer.md` before they can work in MP.

## Spikes before building

| # | Question | How |
|---|---|---|
| S1 | How fast do clothes dry when worn, in the dryer, and in a carried bag? Does anything dry clothes left in a world container? Can a bucket on the floor be a wash source? | Debug: set wetness 100, time each case at 10 °C and 25 °C |
| S2 | Are `appliances_laundry_01_26..31` a clothesline? Can a Lua-added container appear on existing map objects? | Brush tool, then `OnLoadedTileDefinitions` and the `setContainer` fallback |
| S3 | Can a build entity use the post/line sprites? | Copy the vanilla drying-rack entity |
| S4 | Is lowering a Clothing's condition safe (holes, insulation, tooltip)? | Debug on a few garments |
| S5 | What blood threshold does `hasBloodyClothing` use? | Bytecode constant, then an in-game check at 20% |
| S6 | Do sandbox values survive moving an option to a new page? | An old save, before and after |

## Phases

Each phase ships on its own and gets a changelog line and checklist items
(`laundry-*`, a new checklist section).

1. **Foundation:**
   - Split the sandbox pages and add the Laundry page.
   - Add the module skeleton and master toggle.
   - Move the hand-wash floors (and the DVF handshake).
   - Change wringing.
   - Tests: `test_laundry.lua`, plus the existing `test_washing.lua` adjusted.
2. **Damp, musty and odour:** the damp clock, sweat, the moodle, mood, Dry by
   the Fire, tooltip lines, and the Germaphobe and Infection hooks.
3. **Set-in stains and bleach.**
4. **Washboard:** item, recipes, loot, icon.
5. **Fabric wear.**
6. **Clotheslines:** map lines, the built line, the weather drying model.

Phases 1-2 are the core loop (wash, dry it properly, or it goes musty) and
deliver the part asked for first. Phases 3-5 are small once 1 is in. Phase 6
waits on its spikes.

## Open questions

1. **DVF:** step aside when Vitality's laundry is on (recommended), or delete
   the washing from DVF?
2. **Sandbox page names and grouping:** are "General / Health / Daily Life /
   Laundry" right?
3. **Wringing to 50:** this changes rain-soaked clothes too. Is that fine, or
   should only freshly washed garments keep the higher floor?
4. **Name and look of the moodle:** "Stale Clothes" and "Musty Clothes", with an
   icon of a shirt with stink lines?

## Later ideas (not in this plan)

- Traits: built 2026-10-11, see "Traits" below. Fastidious was dropped (Germaphobe
  already covers it).
- A rope line between two trees for wilderness camps.
- Bleach fading a garment's colour.
- Lifting the module out into a standalone laundry mod, with Vitality and DVF
  stepping aside for it.

## As built (2026-10-11)

The user's answers: Dan's Vanilla Fixes loses its washing entirely (files,
options and translations deleted; the bath floors moved into
`DanTraits_Bathing.lua`); the page names stand; wringing to 50 for rain-wet
clothes too is fine; the moodle names stand. Added on request: a way to keep
clothes clean (ponchos, fabric protector, fabric wax).

Files: `DanTraits_Laundry.lua` (state, damp clock, sweat, stains, wear,
moodle, washers, the Infection hook), `DanTraits_LaundryWash.lua` (wash and
wring wraps, bleach helpers), `DanTraits_LaundryDry.lua` (fire, clotheslines),
`DanTraits_LaundryGear.lua` (ponchos, protector), `TimedActions/ISLaundryAction.lua`
(bleach, dry by the fire, protect), `client/DanTraits_LaundryClient.lua`
(menus, tooltip lines), `server/DanTraits_LaundryMap.lua` (map clotheslines get
their container on load). Tests: `tests/test_laundry.lua`.

What changed from the design, from what the game files showed:

- **Unworn clothes already dry, 20 an hour** (Java `Clothing.updateWetness`,
  worked out only when the item is looked at or moved). The damp clock calls
  `updateWetness()` before reading an unworn garment, so in practice musty
  comes from wearing damp clothes (or rain on worn ones): the case asked for.
- **Clotheslines** are the pulley posts `appliances_laundry_01_26..29`
  (looked at: 26/27 face each other east-west, 29/28 north-south; 30/31 are
  wire spans). Each post gets a Lua-made container (capacity 15), made with
  `ItemContainer.new(type, square, parent)`: 42.21 has no five-argument
  constructor (the vanilla campfire's call is stale). A player puts a pair
  up a tile apart from a right-click (Lua-placed objects, `dtlBuilt` in their
  mod data), not from the build menu: a build entity whose sprites are the
  map's own posts claimed every map clothesline as it loaded and failed
  ("EntityScript not found: Clothesline"), found in play the same day. Line drying is
  40 an hour at base (it has to beat the containers' 20).
- **Ponchos already exist** (green, yellow, tarp, garbage bag, hood up or
  down; `base:jackethat`, which excludes jackets and sweaters), and so does a
  garbage bag poncho recipe (Tailoring 1, two bags, three duct tape). Added a
  rough one with no skill and the shield; only the garbage bag one tears.
- **The game's wash menu lists only dirty or bloody garments**, so stale
  clean ones get "Freshen up clothes" at a water source.
- **Machine washes** are seen by watching washers near the player
  (`d.lnWashers`): while one runs, its clothes are marked, and the effects
  (odour, must, stain floor, wear) land when a garment is next seen.
- **Dry by the fire** is a timed action at 0.05 wetness a tick (a soaked
  shirt in about a minute of real time), not the hour and a half first sketched.
- **Play test, same day.** Worn clothes dried at about 300 points a game
  hour at 26 C (a soaked tee in about 20 game minutes; carried 21 an hour), so
  musty could never reach worn clothes and wearing clothes straight out of the
  washer still cost nothing. The user chose "slow + smell": worn clothes keep
  25% of the game's drying each minute (sandbox LaundryBodyDryRate) and every
  hour worn damp adds 25 odour. Bleach and Freshen now include worn clothes.
  The first put-up clothesline was a pair of posts one tile apart with no
  container (the empty sprite name); now a five-tile line like the map's.
- **Fresh Clothes (added on request after the play test).** The good side of
  the moodle: everything worn that sweats, shoes aside, at odour under 15,
  dry, not dirty or bloody and not musty gives -1 Fresh Clothes (unhappiness
  -0.5 an hour, stress -0.01); -2 Line-Dried when half or more of it dried on
  a clothesline in daylight since its last wash (twice that). Germaphobe x2;
  LaundryMood scales it.
- Spikes S1 to S6 could not run without the game; each is now a field-test
  check (section 19 of the checklist).

## Traits (built 2026-10-11)

Chosen by the user from a shortlist; names and prices are theirs. All in
`DanTraits_LaundryTraits.lua`, through hooks laundry runs (`laundryOdour`,
`laundryMood`, `laundryFresh`, `laundryMoodle`, `laundrySkilled`, `laundryAtHome`,
`laundryWashed`, `laundryTooltip`), so the laundry module stays liftable.

| Trait | Cost | Effect |
|---|---|---|
| Sweaty | -2 | sweat odour x1.75 (worn-damp odour unchanged). Not with Cool Customer |
| Cool Customer | +3 | sweat odour x0.5. Not with Sweaty |
| Slob | +2 | no laundry moodle, so no mood either way; infection unchanged. Not with Germaphobe, Homemaker |
| Homemaker | +4 | hand wash at washboard floors, washboard floors halved, odour out without soap; wear x0.5; Line-Dried x1.5. Not with Slob |
| Sensitive Skin | -2 | damp, musty (x2) or never-washed worn garments hold discomfort 20 +10 each, cap 50; start outfit counts washed |

Hooks into other traits: Nomad (Stale/Musty mood x0.5), Homebody (Line-Dried
x2 when most of it dried on a line at home), Asthma (0.08 irritation a garment
bleached indoors), Fear of Blood (0.05 stress a bloody garment washed), Bad
Back (0.06 load a garment on a washboard; the user picked Bad Back over
Arthritis).

# Vitality Project: API for modders

Read a character's traits, Vitality, burnout, blood, illness and fever; add a page to the
Guide tab; mark your food as home cooking; adjust the values this mod computes; run on
its clocks; knock a head, pass a character out, start a fever or an illness of your own.
Everything lives in `media/lua/shared/DanTraits_API.lua` as the global table
`VitalityProject`. `VitalityProject.API_VERSION` is `1`.

The mod itself is a hundred-odd files that talk through `DanTraits_*` globals. Those are
internal and move between versions; this file is the part that is promised. Every
function checks that the system behind it is loaded (a sandbox switch may have left it
idle, a server has no client files) and returns `nil` when it is not, so you never have to.

## Making the Vitality Project optional

Put this at the top of one of your **shared** Lua files. It runs when the Vitality
Project is installed and does nothing when it isn't, so you don't need to list it in
`require=`:

```lua
local ok = pcall(require, "DanTraits_API")
if ok and VitalityProject and VitalityProject.API_VERSION then
    -- calls below
end
```

To make it a hard dependency instead, add `require=\DanTraits` to your `mod.info` (the mod
id is `DanTraits`, kept for save compatibility).

Two things need no API at all and work with the mod absent:

- **A Guide page.** Put it in `DanTraits_GuideExtra` (below). The table is a plain
  global; without the mod it sits unused.
- **Home cooking.** Set `item:getModData().slowCookerHome = true` on a dish, and
  `.slowCookerDish = "<id>"` for a named dish, and Vitality counts it as home cooking
  (1.5x on the diet score) and the dish as variety of its own. The Slow Cooker (in Vitality
  Appliances) does exactly this.

## Traits and options

```lua
VitalityProject.hasTrait(player, "asthma")          -- one of this mod's traits, by short id
VitalityProject.hasVanillaTrait(player, "base:insomniac")
VitalityProject.traits()                            -- every short id, sorted
VitalityProject.option("StrainEnabled")             -- a sandbox switch: true unless off
VitalityProject.optionNumber("IllnessFrequency", 100)
```

The ids: `adhd anemia arthritis asthma badday brittle caffeine cantswitchoff carpaltunnel
coolcustomer deepsleeper dependent diabetes1 diabetes2 earlyriser endorphinjunkie epilepsy
exerciseaverse fastrecovery germaphobe gluten goodclotter gout grit gymregular hayfever
heart hemophilia highlystrung hollowlegs homebody homemaker hunted huntedsprint inflexible
injuryprone lactose levelheaded lingeringsoreness mealprepper migraine ms naturalrunner
newbiegains nightshift nomad regimented renfaire robbed schizophrenia sensitiveskin sensory
slob smoker spiraling steadyhands straightedge swarmed sweaty thickskull thyroid tinnitus
tremor unwindseasily vegetarian weightlifter wellconditioned wounded`; the ages
`age20s age30s age40s age50s` and their traits `badback badknees bottomlesspit castiron
delicatestomach hotheaded natural oldbones oldhand oldinjury paceyourself quickstudy
readingglasses restless seenitall setinways settled`; and four retired ids still
registered for old saves (`bouncesback green ironstomach jinxed`). `spiraling` is Major
Depressive Disorder, `dependent` Caffeine Dependent, `schizophrenia` Hallucinations,
`renfaire` Renaissance Faire Geek. Option names are in `media/sandbox-options.txt`.

## Reading the character

```lua
local v = VitalityProject.vitality(player)
-- { score = 0..1, tier = 0..4, name = "Run Down" | "Sluggish" | "Steady" | "Fit" | "Thriving",
--   effect = -1..1 }   or nil with Vitality off

local b = VitalityProject.burnout(player)
-- { level = 0..100, tier = 0..4, name = "At Ease" | "Frayed" | "Worn Down" | "Burnt Out" | "Breaking Point" }

local blood = VitalityProject.blood(player)
-- { vol = 0..1, cells = 0..1, loss = per minute, tier = 0 fine .. 4 shock, ... }   or nil with Blood Loss off

VitalityProject.fever(player)          -- 0..1 as the character feels it; past 1 it drains health
VitalityProject.illness(player)
-- a list: { id, kind = "viral"|"bacterial", brewing = true, inH } while hidden,
--         { id, kind, day, rising, sev = 0..1, leftH } once it shows
VitalityProject.relief(player, "nausea")   -- the best relief working: 1 none, lower better
                                            -- kinds: nausea, cramps, ache, cold
VitalityProject.foodTags(item)             -- what this mod makes of a food: tags such as fresh, cooked,
                                            -- junk, rotten, meat, fish, dairy, wheat, alcohol, caffeine
VitalityProject.homeCooked(item)           -- home (true/false), dish id or nil
VitalityProject.isLocalPlayer(character)   -- a character this client runs
VitalityProject.data(player)               -- the raw per-player table: keys not promised, read only
```

## Doing things to the character

```lua
VitalityProject.knockHead(player, chance, score)   -- a knock: chance 0..1 it concusses, score 0..1 how hard;
                                                   -- helmets and the sandbox switch honoured; 0 when nothing
VitalityProject.passOut(player, minutes, "UI_MyMod_ComeTo")
VitalityProject.painFloor(player, "mymod", 20, 1, 10)   -- head pain at least 20 (0..100), reached over 1 minute,
                                                         -- held 10 minutes after you stop; call it each minute
VitalityProject.comfort(player, "pet")       -- a comfort eases burnout: shower, laundry, read, pumped, game,
                                             -- breathe, walk, pet, or your own word with an amount; the first of a
                                             -- kind today counts in full, the second at half, then nothing
VitalityProject.strainAdd(player, "mymod", 10, combat)   -- raw burnout, 0..100 scale
VitalityProject.strainEase(player, "mymod", 10)
VitalityProject.catchIllness(player, "cold")        -- hidden for its incubation; true when it took
VitalityProject.catchIllness(player, "flu", true)   -- the symptoms at once
-- ids: cold, flu, pneumonia, strep, stomach, food. Immunity, a running course and the sandbox are honoured.
VitalityProject.feverSource("mymod", function(player, d) return 0.3 end)
-- a fever of your own, 0..1 each minute: the worst source counts in full, the rest at half; the game's sick
-- moodle, the medicines and every system that reacts to a fever follow the one total
```

## Notices and story events

```lua
VitalityProject.notify(player, "UI_MyMod_Line", good, ...)   -- a line over the head for ten seconds, red or
                                                               -- green; extra arguments format the translation
VitalityProject.story(player, "mymod_thing", "Something happened", "good")   -- no halo, event only
```

Both publish the Lua event `OnStoryEvent` with `(player, { source = "DanTraits", kind, text,
tone })`. Listen with `Events.OnStoryEvent.Add(fn)`: PZ Chronicle and the companion app do.
Your own mod can trigger the same event with its own `source`; register it first if it is
missing (`LuaEventManager.AddEvent("OnStoryEvent")`).

## Adjusting what this mod computes

```lua
-- fn(value, ...) returns the new value, or nil to leave it. order: lower runs first
-- (default 100, after this mod's own subscribers). Factors multiply: scale, never add.
VitalityProject.addHook("nightQuality", function(quality, player, d, hoursSlept)
    if hasMyPillow(player) then return quality * 1.1 end
end)
```

The names kept across versions, with their arguments (`VitalityProject.HOOKS` has the same
list):

| Hook | Value | Arguments |
|---|---|---|
| `eat` | nil (a notification) | player, item, fraction eaten (0..1) |
| `drink` | nil | player, fluidContainer, litres, fluidName, ratio |
| `pill` | nil | player, kind (this mod's medicine id: `Antibiotics`, `Painkillers`, ...) |
| `prePill` | nil | player, kind, item (about to be taken) |
| `nightQuality` | the night's score 0..1 | player, d, hoursSlept |
| `foodGrade` | a food's diet grade 0..1 | player, item, why |
| `refuseFood` | nil; return anything true-ish to refuse | player, item |
| `infectionHazard` | a wound's infection chance | player, part |
| `infectionGrowth` | x1 on how fast infections grow | player |
| `woundHeal` | x1 on how fast a wound heals | player, part |
| `strainRelief` | x1 on how much a comfort eases burnout | player, d |
| `homeGood` | x1 on how much good being at home does this minute | player, d |
| `enduranceRegen` | stamina regained this frame | player, d |
| `panicRise` | panic gained this frame | player, d |
| `hungerRise`, `fatigueRise`, `boredomRise` | the stat's rise this minute | player, d |
| `catchCold` | the game's wet-and-cold meter's rise this minute | player, d |

The last six are stat pipelines: the hook sees how much the stat *rose* since the pipeline
last ran and returns the rise to apply, so several mods' factors multiply and none can see
another's. Offer values of your own with `VitalityProject.runHooks("mymod_name", value, ...)`
(prefix the name with your mod's).

## Running on this mod's clocks

```lua
VitalityProject.every("minute", "MyMod", function(player, d)
    -- every game minute, for each local player, after this mod's own systems
end)
VitalityProject.every("frame", "MyMod", fn, 100, { trait = "asthma", active = function(player, d) return d.asMyFlag end })
VitalityProject.onPlayerReady("MyMod", function(player) ... end)   -- on creation and on each load: run twice without effect
VitalityProject.later(60, function() ... end, "mymod job")
VitalityProject.wrap(ISEatFoodAction, "perform", "mymod", function(original, self, ...)
    local r = original(self, ...)
    return r
end)   -- one layer on a game method, keyed by method and tag; never for new()
```

Cadences are `"minute"`, `"ten"` and `"frame"`. `opts.trait` runs the entry only while the
character has that trait and `opts.clear(player, d)` once when it goes; a frame entry's
`opts.active` says whether it needs frames right now (a character with nothing happening
runs nothing). The order table is the comment at the top of `DanTraits.lua`.

## A page in the Guide tab

```lua
VitalityProject.guidePage({
    id = "mymod", title = "My Mod", order = 100,          -- order sorts the extra pages, then title
    picture = "media/ui/Guide/mymod.png",                 -- optional; default media/ui/Guide/<id>.png, from your mod's media
    mod = "MyMod",                                        -- your mod id: the companion-mods page points at your page
    body = {
        "A paragraph. Plain English only: the pages are not translated.",
        "",
        "## A sub-heading",
        "- A bullet.",
    },
})
```

Or, with no API call at all (the Guide reads the table when the window opens, so load
order and the mod's absence do not matter):

```lua
DanTraits_GuideExtra = DanTraits_GuideExtra or {}
table.insert(DanTraits_GuideExtra, { id = "mymod", title = "My Mod", body = { ... } })
```

The page sits after this mod's pages and before What's New. A later page with the same id
replaces the earlier one; a built-in id cannot be taken over.

## Good to know

- Singleplayer and split-screen are what this mod is built for; its systems run for local
  players only, so your hooks and clocks see those.
- Everything here is a thin wrapper. If you need something that is not, open an issue on
  GitHub and say what for: promising it is cheap, guessing at it is not.
- The companion mods (Vitality Cartridges, Vitality Challenges, Vitality Appliances) are
  worked examples in this repository.

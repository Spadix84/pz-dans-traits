# Vitality Appliances: API for modders

Vitality Appliances holds two appliances, and each has its own API, loaded on its own:

| Appliance | Lua file | Table |
|---|---|---|
| [Slow Cooker](#slow-cooker) | `media/lua/shared/SlowCooker_API.lua` | `SlowCooker` |
| [Brick Smoker](#brick-smoker) | `media/lua/shared/Smoker_API.lua` | `Smoker` |

Both were mods of their own before (`SlowCooker` and `BrickSmoker`). The file names, the
tables, the item types, the tiles and the mod data are the same as they were, so
`pcall(require, "SlowCooker_API")` and `pcall(require, "Smoker_API")` written against
those still work. Only the mod id is new: a hard dependency is now
`require=\VitalityAppliances` in your `mod.info`.

## Slow Cooker

Add your own slow cooker recipes, extend the built-in ones, let your bowls and pots
take a serving, and react when someone cooks or serves. Everything lives in
`media/lua/shared/SlowCooker_API.lua`. `SlowCooker.API_VERSION` is `1`.

### Making the Slow Cooker optional

Put this at the top of one of your **shared** Lua files. It runs when the Slow Cooker
is installed and does nothing when it isn't, so you don't need to list it in `require=`:

```lua
local ok = pcall(require, "SlowCooker_API")
if ok and SlowCooker and SlowCooker.API_VERSION then
    -- calls below
end
```

To make it a hard dependency instead, add `require=\VitalityAppliances` to your `mod.info`.

### Ingredients must go in a stew

The crock is filled by the game's own evolved recipe (`CrockStew`, with the vanilla Stew
template). An item can go in only if its item script lists `Stew` in `EvolvedRecipe`,
for example:

```
EvolvedRecipe = Soup:10;Stew:10;Pie:10,
```

The window hides anything else, and anything that doesn't exist. At game start the
console lists every recipe item that doesn't exist, prefixed `[SlowCooker]`, so
typos are easy to spot.

### Adding a recipe

```lua
SlowCooker.addRecipe({
    id = "mymod_gumbo",            -- unique; prefix it with your mod's name
    level = 4,                     -- Cooking level that unlocks it, 0-10
    name = "IGUI_MyMod_Gumbo",     -- translation key, or plain text like "Gumbo"
    groups = {
        { label = "IGUI_MyMod_Seafood", need = 1, items = { "Base.Shrimp", "Base.Crayfish" } },
        { label = "IGUI_SlowCooker_Onion", need = 1, items = { "Base.Onion", "Base.GreenOnions" } },
        { label = "IGUI_SlowCooker_Extras", need = 0, items = { "Base.BellPepper", "Base.Pepper" } },
    },
    unhappy = -20,                 -- optional: mood bonus over plain stew, whole crock
    boredom = -20,                 -- optional
})
```

- `need = 1` (the default) means one item from the group; `need = 2` means two
  *different* items (Kentucky Burgoo uses that for its two meats); `need = 0` means
  optional extras.
- Recipes are kept in unlock order. The player sees a notice when Cooking reaches the
  level, and the *Kentucky Slow Cooker Favorites* booklet teaches every recipe,
  including yours.
- The finished crock is `Base.CrockOfStew`, renamed to your dish. Its mod data has
  `slowCookerDish = "mymod_gumbo"` and `slowCookerHome = true`.

#### A recipe card

Reading any literature item with `LearnedRecipes = SlowCooker_<id>` teaches that recipe
at any level:

```
item MyGumboCard
{
    DisplayCategory = RecipeResource,
    ItemType = base:literature,
    Weight = 0.1,
    Icon = RecipeClipping,
    ReadType = photo,
    LearnedRecipes = SlowCooker_mymod_gumbo,
    StaticModel = RecipeClipping,
    WorldStaticModel = RecipeClipping,
    Tags = base:newspaperread,
}
```

Add your card to the loot tables yourself, for example in `ProceduralDistributions`.

### Changing the built-in recipes

```lua
-- Bison counts as chili meat. Find a group by its label or its position (1, 2, ...).
SlowCooker.addIngredients("chili", "IGUI_SlowCooker_Meat", { "MyMod.Bison" })

-- An unknown label adds a new optional group.
SlowCooker.addIngredients("beefstew", "IGUI_MyMod_Herbs", { "MyMod.Sage" })

-- Take a recipe out (for an overhaul).
SlowCooker.removeRecipe("sloppyjoes")
```

The built-in ids are `soupbeans`, `chili`, `beefstew`, `cornchowder`, `potroast`,
`sloppyjoes`, `chickendumplings`, `pulledpork` and `burgoo`. `SlowCooker.getRecipes()`
returns the live list.

### Bowls and pots

**Serve a Bowl** takes an empty bowl, and **Move to Cooking Pot** an empty pot. Register
your own types, each with the full Food item it turns into:

```lua
SlowCooker.addBowl("MyMod.WoodBowl", "MyMod.WoodBowlOfStew")   -- like Base.Bowl -> Base.StewBowl
SlowCooker.addPot("MyMod.Cauldron", "MyMod.CauldronOfStew")    -- like Base.Pot -> Base.PotOfStew
```

The full item gets the meal's nutrition, age, ingredients and mod data. Give it
`ReplaceOnUse` back to your empty type.

### Power

On a generator a running cooker uses 0.02 L of fuel an hour (times the server's
generator fuel setting). The game itself charges every switched-on stove, oven and
microwave 0.09, so the Slow Cooker takes its cookers back off the generator's total
each time the generator recalculates, and its info window shows the cooker's own
figure. To change it:

```lua
SlowCooker.setPowerDraw(0.04)   -- litres an hour; 0 makes it free
```

Mods that work out generator load themselves (solar or battery mods) can ask
`SlowCooker.isCooker(obj)` and charge `SlowCooker.POWER_DRAW` for a cooker that
`obj:Activated()`.

### Events

```lua
SlowCooker.on("dishMade", function(character, dish, recipe)
    -- ingredients just went into the crock; recipe is nil for plain crock stew
end)

SlowCooker.on("served", function(character, dish, filled, kind)
    -- kind is "bowl" or "pot"; filled is the new item; dish is what's left in the
    -- crock, or nil if it's now empty
end)
```

Listeners run where the action completes, which in multiplayer is the server. An error in
one listener is logged and doesn't stop the others. Remove a listener with
`SlowCooker.off(event, fn)`.

### Questions

```lua
local home, dishId = SlowCooker.isHomeCooked(item)  -- the crock, or a bowl or pot served from it
SlowCooker.playerKnows(player, "burgoo")             -- by level, booklet or card
SlowCooker.recipeById("chili")
```

To check without depending on this mod, read the mod data directly:
`item:getModData().slowCookerHome` and `.slowCookerDish`. The Vitality Project does
this for its home-cooking bonus.

## Brick Smoker

Make your own wood burn in the smoker, let your meats (or cheeses, or anything else)
smoke, give them their own smoked products, tune the times, and react when the fire
is lit, goes out or finishes a batch. Everything lives in
`media/lua/shared/Smoker_API.lua`. `Smoker.API_VERSION` is `1`.

### Making the Brick Smoker optional

Put this at the top of one of your **shared** Lua files. It runs when the Brick Smoker is
installed and does nothing when it isn't, so you don't need to list it in `require=`:

```lua
local ok = pcall(require, "Smoker_API")
if ok and Smoker and Smoker.API_VERSION then
    -- calls below
end
```

To make it a hard dependency instead, add `require=\VitalityAppliances` to your `mod.info`.

Calls that register things (fuel, foods, kinds, times) are tables read whenever the
smoker runs, so make them at load time on every machine: a shared file does that.

### How a food is smoked

Every food that smokes has a **kind**. The kind decides what it turns into:

| Kind | After 8 h | After 24 h |
|---|---|---|
| `meat` | `Base.SmokedMeat` | `Base.SmokeDriedMeat` |
| `poultry` | `Base.SmokedPoultry` | `Base.SmokeDriedMeat` |
| `fish` | `Base.SmokedFish` | `Base.SmokeDriedFish` |

A food's kind is, in order:

1. what it was made as, if it's already smoked (mod data `smokerKind`);
2. its own registration (`Smoker.addSmokable`);
3. its item script's `FoodType`: `Beef`, `Meat`, `Venison`, `Game`, `Sausage` and
   `Bacon` are `meat`; `Poultry` is `poultry`; `Fish` and `Seafood` are `fish`.

By food type, only foods that are cookable and not packaged count, and a short exclude
list keeps out processed foods (nuggets, fish fingers, open cans...).

When a piece is done, the smoker makes the product item and copies across **that
piece's own** hunger (current and base), calories, carbohydrates, protein, fat,
taint and mod data, scales its weight (×0.85 smoked, ×0.6 again dried), resets its age,
and names it `Smoked <name>` / `Smoke-Dried <name>` after what went in. Shelf life
(`DaysFresh`, `DaysTotallyRotten`), mood and thirst come from the product's item script.

### Fuel

```lua
Smoker.setFuel("MyMod.HickoryChunks", 3)   -- hours of fire per item
Smoker.setFuel("Base.Charcoal", 0)          -- 0 or nil: not fuel any more
Smoker.getFuel("Base.Log")                  -- 6
Smoker.setFuelCapacity(36)                  -- the firebox holds 36 h (default 24)
```

Built in: log 6 h, plank, firewood and perced wood 2 h, unusable wood 1.4 h, branches
and charcoal 1 h, pinecones 30 min, sticks and twigs 15 min. Fuel items are used up
whole. The *Add Fuel* menu finds them in the player's inventory and anything in reach.

### Foods

```lua
-- This item smokes as meat, whatever its FoodType. Registration skips the cookable,
-- packaged and exclude-list checks.
Smoker.addSmokable("MyMod.BisonSteak", "meat")

-- Every cookable, unpackaged food with FoodType = Mutton smokes as meat.
Smoker.addFoodType("Mutton", "meat")
Smoker.addFoodType("Mutton", nil)           -- and undo it

-- This item never smokes and can't go in the chamber.
Smoker.removeSmokable("Base.Sausage")
```

### Your own kinds and products

```lua
-- Smoked cheese, with no dried stage: it's finished at 8 h and stays as it is.
Smoker.addKind("cheese", "MyMod.SmokedCheese")
Smoker.addSmokable("MyMod.Cheddar", "cheese")

-- Two stages, like the built-in kinds.
Smoker.addKind("sausage", "MyMod.SmokedSausage", "MyMod.DrySausage")
Smoker.addFoodType("Sausage", "sausage")

-- Change a built-in kind's products: fish dries into your stockfish instead.
Smoker.addKind("fish", "Base.SmokedFish", "MyMod.Stockfish")
```

Products must be Food items. Give them shelf life, mood and thirst in their script; the
nutrition and weight are overwritten from the piece that went in, so script values are
only defaults for one spawned some other way. For example:

```
item SmokedCheese
{
    DisplayCategory = Food,
    ItemType = base:food,
    Weight = 0.2,
    Icon = Cheese,
    FoodType = Cheese,
    DaysFresh = 30,
    DaysTotallyRotten = 60,
    HungerChange = -15.0,
    UnhappyChange = -10,
    Calories = 200.0,
    Carbohydrates = 1.0,
    Lipids = 16.0,
    Proteins = 12.0,
    EvolvedRecipe = Sandwich:5;Salad:5;Pasta:5,
    StaticModel = Cheese,
    WorldStaticModel = Cheese,
}
```

Add a `Base.<Type>` line to your `ItemName.json` as usual. At game start the console lists
every registered item that doesn't exist, prefixed `[BrickSmoker]`, so typos are easy to
spot.

### Times

```lua
Smoker.setTimes(6, 18)    -- Smoked at 6 h of smoke, Smoke-Dried at 18 h (defaults 8, 24)
```

Hours count from when the food went in, while the fire burns, and the food doesn't
age meanwhile.

### Questions

```lua
local smoked, stage, kind, name = Smoker.isSmokedFood(item)
-- true, "smoked" | "dried" | "done", "fish", "Bass Fillet"   (false for anything else)

local hours, need, stage = Smoker.getProgress(item)
-- hours of smoke towards the next stage, hours it needs (nil when finished), and stage

Smoker.canSmoke(item)       -- could it go in the chamber right now?
Smoker.stage(item)          -- "raw", "smoked", "dried", "done" or nil
Smoker.kindOf(item)         -- "meat", "poultry", "fish", your kind, or nil

local smoker = Smoker.findOnSquare(square)
Smoker.isSmoker(obj)
Smoker.isLit(smoker)
Smoker.fuelHours(smoker)    -- hours of fuel in the firebox
Smoker.room(smoker)         -- hours more it can take
Smoker.isOutdoors(smoker)
Smoker.lightProblem(smoker) -- nil, or why it can't be lit (a translation key)
```

Stages: `raw` smokes into the kind's Smoked item; `smoked` dries into its Smoke-Dried
item; `dried` and `done` (a Smoked item whose kind has no dried stage) are finished.

To check without depending on this mod, read the mod data directly: a smoked food has
`smokerKind` (its kind) and `smokerName` (what went in) in `item:getModData()`.

### Running a smoker from code

These change the world, so call them where the world runs: in singleplayer, or on the
server in multiplayer (for example from a timed action's `complete()`).

```lua
local added = Smoker.addFuel(smoker, 6)             -- hours actually added
local ok = Smoker.light(smoker, nil, character)     -- false if lightProblem says no
Smoker.extinguish(smoker, "mymod_rain", character)  -- reason is passed to listeners
```

### Events

```lua
Smoker.on("lit", function(character, smoker)
    -- character is nil if a mod lit it
end)

Smoker.on("putOut", function(character, smoker, reason)
    -- reason: "player", "fuel" (burned out), "roof" (roofed over), or a mod's own
end)

Smoker.on("fuelAdded", function(character, smoker, item, hours)
    -- hours actually added; item has just been used up
end)

Smoker.on("smoked", function(smoker, food, product, stage)
    -- food is gone; product took its place; stage is the product's
    -- ("smoked", "dried" or "done"). After a long time away a raw piece can go
    -- straight to dried: you get one call, with stage "dried".
end)
```

Listeners run where the world runs, which in multiplayer is the server. Time away is
caught up when the area loads again, so "smoked" and "putOut" can fire then rather
than at the moment they'd have happened. An error in one listener is logged and doesn't
stop the others. Remove a listener with `Smoker.off(event, fn)`.

### Mod data

On a food: `smokerHours` (hours of smoke so far), `smokerKind`, `smokerName`, and
`smokerAge` (internal: the age held while the fire burns).

On the smoker object: `smokerFuel` (hours), `smokerLit` (true while burning) and
`smokerLast` (world hours it last ran). Change these through the calls above, not
directly, so the lit sprite and multiplayer sync follow.

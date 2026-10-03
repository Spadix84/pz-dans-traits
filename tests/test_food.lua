local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
-- Offline test for DanTraits_Food.lua: the one food classifier. A table of item
-- names (every name the six consumers' tests use, plus the word conflicts the
-- file header settles) against the tags they must earn; the food-type tags; the
-- tags a dish takes from its ingredients; the per-instance state; and that a
-- type is scanned once per getFullType().
H.events()
H.stubs()
H.load()

local tags = DanTraits_FoodTags
local function item(name, foodType, extras, state)
  state = state or {}
  return { getType = function() return name end, getFoodType = function() return foodType end,
    haveExtraItems = function() return extras ~= nil end,
    getExtraItems = function() local t = extras or {}; return { size = function() return #t end, get = function(_, i) return t[i + 1] end } end,
    isRotten = function() return state.rotten == true end, isBurnt = function() return state.burnt == true end,
    isPackaged = function() return state.packaged == true end, isFresh = function() return state.fresh ~= false end,
    isCooked = function() return state.cooked == true end }
end

-- 1. names against tags: the listed tags are true (numbers for iron and caffeine), every other tag false
local BOOLS = { "junk", "wheat", "fastCarb", "meat", "egg", "greens" }
local cases = {
  -- Gluten's tests
  { "Bread", wheat = true }, { "BreadSlices", wheat = true }, { "BagelPlain", wheat = true },
  { "PastaBowl", wheat = true }, { "Ramen", wheat = true }, { "NoodleSoup", wheat = true },
  { "Cereal", wheat = true, fastCarb = true }, { "Crackers", wheat = true },
  { "CookiesOatmeal", wheat = true, junk = true, fastCarb = true }, { "PieApple", wheat = true, fastCarb = true },
  { "PizzaWhole", wheat = true }, { "Sandwich", wheat = true }, { "Burger", wheat = true, meat = true },
  { "BeerBottle", wheat = true }, { "Gingerbreadman", wheat = true, fastCarb = true },
  { "MeatSteamBun", wheat = true, meat = true, iron = 1 }, { "BunsHamburger", wheat = true, meat = true },
  { "Tortilla", wheat = true }, { "Cornbread", wheat = true }, { "PotatoPancakes", wheat = true, junk = true, fastCarb = true },
  { "Rice" }, { "Potato" }, { "Corn" }, { "Apple", fastCarb = true }, { "Steak", meat = true },
  { "WhiteCrappie", meat = true, fastCarb = true }, { "Poppies", junk = true, fastCarb = true },
  { "GamePieceRed", iron = 1, fastCarb = true }, { "TortillaChips", junk = true }, { "Oatmeal" }, { "OatsRaw" },
  { "GranolaBar", fastCarb = true }, { "Cornflour2" }, { "RiceCake", junk = true, fastCarb = true },
  -- Diabetes' tests
  { "Chocolate", junk = true, fastCarb = true, caffeine = 15 }, { "CandyPackage", junk = true, fastCarb = true },
  { "Lollipop", junk = true, fastCarb = true }, { "Sugar", junk = true, fastCarb = true }, { "Honey", fastCarb = true },
  { "JamStrawberry", fastCarb = true }, { "Banana", fastCarb = true },
  { "IcecreamConeChoc", junk = true, fastCarb = true }, { "CakeSlice", junk = true, wheat = true, fastCarb = true },
  { "Milk", fastCarb = true }, { "Popcorn", junk = true },
  -- Vegetarian's tests (by name; food types are below)
  { "Chicken", meat = true, iron = 1 }, { "Salmon", meat = true }, { "Shrimp", meat = true }, { "Worm", meat = true },
  { "Dogfood", meat = true }, { "Bologna", meat = true }, { "DeadRat", meat = true }, { "PorkRinds", meat = true, iron = 1 },
  { "GrahamCrackers", wheat = true }, { "CannedEggplant", canned = true }, { "KidneyBeans", greens = true },
  { "Gooseberry", fastCarb = true }, { "CarrotGrated" }, { "SushiEgg", egg = true }, { "Carrot" }, { "Egg", egg = true },
  { "Cheese" },
  -- Vitality's, Anemia's and Caffeine's tests
  { "Crisps", junk = true }, { "Peanuts" }, { "Cabbage" }, { "Bass", meat = true }, { "Venison", meat = true, iron = 1 },
  { "CannedBeans", greens = true, canned = true }, { "Chocolate_SnikSnak", junk = true, fastCarb = true, caffeine = 15 },
  { "ChocolateCoveredCoffeeBeans", junk = true, fastCarb = true, greens = true, caffeine = 300 },
  { "Coffee2", caffeine = 600 }, { "CocoaPowder", caffeine = 30 }, { "TeaBag2", caffeine = 40 },
  -- the conflicts settled in the header
  { "Jerky", junk = true, meat = true }, { "Sugarcane", fastCarb = true }, { "ChipsBowl" },
  { "Eggplant" }, { "SweetPotatoDried", canned = true }, { "CakeChocolate", junk = true, wheat = true, fastCarb = true },
}
local n = 0
for _, c in ipairs(cases) do
  local t = tags(item(c[1]))
  for _, k in ipairs(BOOLS) do assert((t[k] == true) == (c[k] == true), c[1] .. "." .. k .. ": expected " .. tostring(c[k] == true) .. ", got " .. tostring(t[k])) end
  assert(t.iron == (c.iron or 0), c[1] .. ".iron: expected " .. tostring(c.iron or 0) .. ", got " .. tostring(t.iron))
  assert(t.caffeine == (c.caffeine or 0), c[1] .. ".caffeine: expected " .. tostring(c.caffeine or 0) .. ", got " .. tostring(t.caffeine))
  assert((t.canned == true) == (c.canned == true), c[1] .. ".canned")
  n = n + 1
end
assert(tags(item("ChipsBowl")).junkSafe == true and tags(item("Chips")).junkSafe == false, "junkSafe marks the safe names only")
assert(tags(item("")).wheat == false and tags(item("")).iron == 0, "an empty name is plain")
print("names: " .. n .. " items classified")

-- 2. food types: meat by type even with a plain name; the iron classes; eggs and greens
local byType = {
  { "Beef", meat = true, iron = 1 }, { "Poultry", meat = true, iron = 1 }, { "Fish", meat = true, iron = 1 },
  { "Seafood", meat = true, iron = 1 }, { "Insect", meat = true, iron = 1 }, { "Game", meat = true, iron = 1 },
  { "DogFood", meat = true }, { "Stock", meat = true }, { "Sausage", meat = true }, { "Bacon", meat = true },
  { "Meat", meat = true, iron = 1 }, { "Egg", egg = true }, { "Vegetables", greens = true }, { "Herb", greens = true },
  { "Fruits" }, { "Bread" }, { "Cheese" }, { "Rice" }, { "NoExplicit" }, { "Bean" },
}
for _, c in ipairs(byType) do
  local t = tags(item("Thing", c[1]))
  assert((t.meat == true) == (c.meat == true), c[1] .. " food type: meat")
  assert(t.iron == (c.iron or 0), c[1] .. " food type: iron")
  assert((t.egg == true) == (c.egg == true) and (t.greens == true) == (c.greens == true), c[1] .. " food type: egg and greens")
  assert(t.wheat == false and t.junk == false, c[1] .. " food type: only meat, iron, egg and greens come from the type")
end
assert(tags(item("Thing", nil)).meat == false, "no food type, plain name: nothing")

-- 3. a dish takes meat and wheat from its ingredients, nothing else
local stew = tags(item("Stew", "NoExplicit", { "Base.Carrot", "Base.Steak" }))
assert(stew.meat == true and stew.wheat == false and stew.iron == 0 and stew.junk == false, "a steak in a stew: meat")
local plainStew = tags(item("Stew", "NoExplicit", { "Base.Carrot", "Base.Potato", "Base.Cabbage" }))
assert(plainStew.meat == false and plainStew.wheat == false, "a vegetable stew is neither")
local bake = tags(item("Casserole", nil, { "Base.PastaBowl", "Base.Cheese" }))
assert(bake.wheat == true and bake.meat == false and bake.ingredients == 2, "pasta in a bake: wheat, two ingredients")
assert(tags(item("Soup", nil, { "Base.Smallanimalmeat" })).meat == true, "small animal meat in a soup")
assert(tags(item("Salad", nil, { "Base.Lettuce", "Base.TunaTinOpen" })).meat == true, "tuna in a salad")
assert(tags(item("Stew", nil, { "Base.KidneyBeans", "Base.Crabapple" })).meat == false, "safe ingredient names stay safe")
assert(tags(item("Bowl")).ingredients == 0, "no extras: no ingredients")
-- a hot drink is a food item whose caffeine is what went in: coffee 100 a spoon, a tea bag 40, cocoa 5
assert(tags(item("HotDrinkWhite", nil, { "Base.Coffee2" })).caffeine == 100, "a mug of coffee")
assert(tags(item("HotDrinkWhite", nil, { "Base.Coffee2", "Base.Coffee2", "Base.Sugar" })).caffeine == 200, "a double coffee with sugar")
assert(tags(item("HotDrinkTea", nil, { "Base.Teabag2", "Base.Milk" })).caffeine == 40, "a cup of tea")
assert(tags(item("HotDrinkClay", nil, { "Base.CocoaPowder" })).caffeine == 5, "cocoa")
assert(tags(item("HotDrinkWhite", nil, { "Base.Sugar", "Base.Honey" })).caffeine == 0, "hot sugar water: nothing")
assert(tags(item("HotDrinkWhite")).caffeine == 0, "a mug of hot water: nothing")

-- 4. state is the instance's own, read fresh (not remembered with the type)
local function typed(name, state)
  local it = item(name, nil, nil, state)
  it.getFullType = function() return "Base." .. name end
  return it
end
local a, b = tags(typed("Steak", { rotten = true })), tags(typed("Steak", {}))
assert(a.rotten == true and b.rotten == false, "rotten is per item even for the same type")
assert(tags(typed("Steak", { burnt = true })).burnt == true and tags(typed("Steak", { cooked = true })).cooked == true, "burnt and cooked")
assert(tags(typed("Steak", { packaged = true })).packaged == true and tags(typed("Steak", {})).packaged == false, "packaged")
assert(tags(typed("Steak", {})).fresh == true and tags(typed("Steak", { fresh = false })).fresh == false, "fresh")
assert(b.meat == true and a.meat == true, "the type's tags are shared")

-- 5. a type is scanned once: with a full type, getType is asked the first time only
local calls = 0
local counted = { getFullType = function() return "Base.CountedCake" end, getType = function() calls = calls + 1; return "CountedCake" end }
for _ = 1, 5 do assert(tags(counted).wheat == true, "counted cake is wheat") end
assert(calls == 1, "getType called once for five classifications, got " .. calls)
local bare = { getType = function() calls = calls + 1; return "BareCake" end }
for _ = 1, 3 do tags(bare) end
assert(calls == 4, "an item with no full type is classified every time")

-- 6. things that answer nothing are plain, not errors
local nothing = tags({})
assert(nothing.wheat == false and nothing.meat == false and nothing.junk == false and nothing.iron == 0 and nothing.caffeine == 0, "an empty object is plain")
local blank = tags(nil)
assert(blank.wheat == false and blank.rotten == false and blank.ingredients == 0, "nil is plain")

H.pass("food")

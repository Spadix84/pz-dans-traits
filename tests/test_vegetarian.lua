
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
-- Offline test for DanTraits_Vegetarian.lua: what counts as meat (by food
-- type, by name, and by ingredients), only vegetarians refuse and only meat,
-- and the eat action will not start, validate or eat it, with one notice.
H.events()
H.stubs()

local eaten = {}
ISEatFoodAction = {
  isValidStart = function(self) return "start-ok" end,
  isValid = function(self) return "valid-ok" end,
  complete = function(self) eaten[#eaten+1] = self.item.name; return true end,
  eat = function(self, food, pct) eaten[#eaten+1] = self.item.name .. "@" .. pct end }

H.load("Dependent", "MDD", "Brittle", "Arthritis", "Jinxed", "BadDay", "Hallucinations", "Asthma", "Gluten", "Vegetarian", "Diabetes")

local halo = H.halo
local function list(t) return { size = function() return #t end, get = function(_, i) return t[i + 1] end } end
local function item(name, foodType, extras)
  return { name = name, getType = function() return name end, getFoodType = function() return foodType end,
    haveExtraItems = function() return extras ~= nil end, getExtraItems = function() return list(extras or {}) end,
    getCarbohydrates = function() return 0 end, getHungChange = function() return -0.1 end }
end
local function newPlayer(veg) return H.player({ traits = veg and { "vegetarian" } or {} }) end

-- 1. what counts as meat
local meat = { item("Steak", "Beef"), item("Chicken", "Poultry"), item("Salmon", "Fish"), item("Shrimp", "Seafood"), item("Worm", "Insect"),
  item("Dogfood", "DogFood"), item("BouillonCube", "Stock"), item("Bologna", nil), item("MeatSteamBun", nil), item("WhiteCrappie", nil),
  item("DeadRat", nil), item("PorkRinds", nil), item("Stew", "NoExplicit", { "Base.Carrot", "Base.Steak" }), item("Soup", nil, { "Base.Smallanimalmeat" }),
  item("Salad", nil, { "Base.Lettuce", "Base.TunaTinOpen" }) }
local veg = { item("Carrot", "Vegetables"), item("Egg", "Egg"), item("Cheese", "Cheese"), item("Milk", nil), item("Bread", "Bread"), item("Rice", "Rice"),
  item("GrahamCrackers", nil), item("CannedEggplant", nil), item("KidneyBeans", "Bean"), item("Gooseberry", "Berry"), item("CarrotGrated", nil),
  item("Stew", "NoExplicit", { "Base.Carrot", "Base.Potato", "Base.Cabbage" }), item("SushiEgg", nil), item("Apple", "Fruits") }
for _, it in ipairs(meat) do assert(DanTraits_IsMeat(it), it.name .. " should be meat") end
for _, it in ipairs(veg) do assert(not DanTraits_IsMeat(it), it.name .. " should be fine") end
print("meat detection: " .. #meat .. " meat, " .. #veg .. " fine")

-- 2. only vegetarians refuse, and only meat
local v, plain = newPlayer(true), newPlayer(false)
assert(DanTraits_RefusesFood(v, item("Steak", "Beef")) and not DanTraits_RefusesFood(v, item("Carrot", "Vegetables")), "vegetarian refuses meat only")
assert(not DanTraits_RefusesFood(plain, item("Steak", "Beef")), "others eat anything")

-- 3. the action will not start, will not validate, and will not eat; one notice per attempt
local act = setmetatable({ character = v, item = item("Steak", "Beef"), percentage = 1 }, { __index = ISEatFoodAction })
assert(act:isValidStart() == false and act:isValid() == false, "refused at start and during")
assert(halo[#halo] == "UI_DanTraits_VegetarianRefuse" and #halo == 1, "one notice")
assert(act:complete() == true and #eaten == 0, "complete does not eat")
act:eat(act.item, 0.5); assert(#eaten == 0, "interrupted eat does not eat either")
local ok = setmetatable({ character = v, item = item("Carrot", "Vegetables"), percentage = 1 }, { __index = ISEatFoodAction })
assert(ok:isValidStart() == "start-ok" and ok:isValid() == "valid-ok", "vegetables pass through to vanilla")
ok:complete(); assert(eaten[1] == "Carrot", "and get eaten")
local other = setmetatable({ character = plain, item = item("Steak", "Beef"), percentage = 1 }, { __index = ISEatFoodAction })
assert(other:isValidStart() == "start-ok", "non-vegetarian eats steak")
other:complete(); assert(eaten[2] == "Steak", "steak eaten by others")
H.pass()

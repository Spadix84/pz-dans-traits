local handlers, lists = {}, {}
Events = setmetatable({}, { __index = function(t, k) local e = { Add = function(f) lists[k] = lists[k] or {}; table.insert(lists[k], f); handlers[k] = function(...) for _, g in ipairs(lists[k]) do g(...) end end end, Remove = function() end }; rawset(t, k, e); return e end })
BodyPartType = { Groin = "Groin", ForeArm_L=1, ForeArm_R=2, LowerLeg_L=3, LowerLeg_R=4, Hand_L=5, Hand_R=6, Torso_Upper=7 }
CharacterStat = { INTOXICATION = "intox", STRESS = "stress", PAIN = "pain", UNHAPPINESS = "unhappy", FATIGUE = "fatigue", PANIC = "panic", ENDURANCE = "endurance", FOOD_SICKNESS = "foodsick", WETNESS = { getMaximumValue = function() return 100 end } }
local halo = {}
HaloTextHelper = { addBadText = function(_, t) halo[#halo+1] = t end, addGoodText = function(_, t) halo[#halo+1] = "+" .. t end }
function getText(k) return k end
DanTraitsRegistry = { vegetarian = "vegetarian", gluten = "gluten" }
ArrayList = { new = function() return { add = function() end } end }
IsoFireManager = { explode = function() end }
function instanceof() return false end
ItemBodyLocation = { MASK = "mask", MASK_EYES = "maskeyes", MASK_FULL = "maskfull" }
function getWorld() return { getFreeEmitter = function() return { playSound = function() return 1 end, setPos = function() end } end } end
function getTexture() return "TEX" end
function getGameTime() return { getHour = function() return 12 end } end
function ZombRand() return 0 end
function getClimateManager() return { getAirTemperatureForCharacter = function() return 20 end } end
function getCell() return { getGridSquare = function() return { getObjects = function() return { size = function() return 0 end } end, getDeadBodys = function() return { size = function() return 0 end } end } end } end
function addSound() end
DanTraitsTestCharge = false

local eaten = {}
ISEatFoodAction = {
  isValidStart = function(self) return "start-ok" end,
  isValid = function(self) return "valid-ok" end,
  complete = function(self) eaten[#eaten+1] = self.item.name; return true end,
  eat = function(self, food, pct) eaten[#eaten+1] = self.item.name .. "@" .. pct end }

function require() end
for _, f in ipairs({ "DanTraits", "DanTraits_Dependent", "DanTraits_MDD", "DanTraits_Brittle", "DanTraits_Fumbler", "DanTraits_Jinxed", "DanTraits_BadDay", "DanTraits_Hallucinations", "DanTraits_Asthma", "DanTraits_Gluten", "DanTraits_Vegetarian", "DanTraits_Diabetes" }) do
  assert(loadfile("../DanTraits/42/media/lua/shared/" .. f .. ".lua"))()
end

local function list(t) return { size = function() return #t end, get = function(_, i) return t[i + 1] end } end
local function item(name, foodType, extras)
  return { name = name, getType = function() return name end, getFoodType = function() return foodType end,
    haveExtraItems = function() return extras ~= nil end, getExtraItems = function() return list(extras or {}) end,
    getCarbohydrates = function() return 0 end, getHungChange = function() return -0.1 end }
end
local function makePlayer(veg)
  local st = {}
  return { hasTrait = function(_, t) return veg and t == "vegetarian" end, isDead = function() return false end,
    isAsleep = function() return false end, getModData = function() return {} end,
    getStats = function() return { get = function(_, k) return st[k] or 0 end, set = function(_, k, v) st[k] = v end } end }
end

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
local v, plain = makePlayer(true), makePlayer(false)
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
print("ALL OK")

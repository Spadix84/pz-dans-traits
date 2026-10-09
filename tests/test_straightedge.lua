-- Offline test for DanTraits_StraightEdge.lua: tobacco and alcoholic food
-- refused through the eat action with Straight Edge's own reason, packs and
-- chewing tobacco through the pill action, alcoholic drinks through the drink
-- action, another mod's smoke actions (I Don't Need A Lighter's stove, car and
-- take-a-cigarette), and everyone else left alone.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
ISEatFoodAction.isValidStart = function() return "start-ok" end
ISEatFoodAction.isValid = function() return "valid-ok" end
ISTakePillAction.isValidStart = function() return "pill-ok" end
ISTakePillAction.isValid = function() return "pill-ok" end
ISDrinkFluidAction.isValidStart = function() return "drink-ok" end
ISDrinkFluidAction.isValid = function() return "drink-ok" end
-- I Don't Need A Lighter's actions: lit off a stove, and a cigarette out of a pack
IsStoveSmoking = { isValidStart = function() return "stove-ok" end, isValid = function() return "stove-ok" end }
IDNALTakeCigarette = { isValidStart = function() return "pack-ok" end, isValid = function() return "pack-ok" end }
H.load("Smoker", "Vegetarian", "StraightEdge")

local function item(name, alcoholic)
  return { getType = function() return name end, getOnEat = function() return "" end,
    isAlcoholic = function() return alcoholic == true end }
end

-- 0. a non-food item (no getOnEat) is checked without an error, even a caught one:
-- debug mode's Break On Error stops the game on errors inside pcall too
do
  local realPcall, failed = pcall, 0
  pcall = function(f, ...)
    local res = table.pack(realPcall(f, ...))
    if not res[1] then failed = failed + 1 end
    return table.unpack(res, 1, res.n)
  end
  local shirt = { getType = function() return "Tshirt_DefaultTEXTURE" end,
    isAlcoholic = function() return false end }
  local seCheck = H.player({ traits = { "straightedge" } })
  assert(DanTraits_RefuseReason(seCheck, shirt) == nil, "a shirt is not tobacco")
  pcall = realPcall
  assert(failed == 0, "no caught errors on a non-food item, got " .. failed)
end
local function act(class, fields)
  return setmetatable(fields, { __index = class })
end
local function bottle(alcohol) return { getProperties = function() return { getAlcohol = function() return alcohol end } end } end

local se = H.player({ traits = { "straightedge" } }); H.current = se
local plain = H.player()

-- 1. the reasons
assert(DanTraits_RefuseReason(se, item("CigaretteSingle")) == "UI_DanTraits_StraightEdgeRefuse", "cigarette refused")
assert(DanTraits_RefuseReason(se, item("Cigar")) == "UI_DanTraits_StraightEdgeRefuse", "cigar refused")
assert(DanTraits_RefuseReason(se, item("BeerCan", true)) == "UI_DanTraits_StraightEdgeRefuse", "alcoholic food refused")
assert(DanTraits_RefuseReason(se, item("Bread")) == nil, "bread fine")
assert(DanTraits_RefuseReason(se, item("NicotineGum")) == nil, "gum is not tobacco")
assert(DanTraits_RefuseReason(plain, item("CigaretteSingle")) == nil, "others smoke")

-- 2. the eat action will not start on a cigarette; one notice
local smoke = act(ISEatFoodAction, { character = se, item = item("CigaretteSingle"), percentage = 1 })
assert(smoke:isValidStart() == false and smoke:isValid() == false, "eat action refused")
assert(H.halo[#H.halo] == "UI_DanTraits_StraightEdgeRefuse" and #H.halo == 1, "one notice")

-- 3. a pack through the pill action
local pack = act(ISTakePillAction, { character = se, item = item("CigarettePack") })
assert(pack:isValidStart() == false, "pack refused")
local pills = act(ISTakePillAction, { character = se, item = item("PillsBeta") })
assert(pills:isValidStart() == "pill-ok", "real pills pass")

-- 4. drinks: alcohol refused, water fine, others drink
assert(act(ISDrinkFluidAction, { character = se, fluidContainer = bottle(0.4) }):isValidStart() == false, "whiskey refused")
assert(act(ISDrinkFluidAction, { character = se, fluidContainer = bottle(0) }):isValidStart() == "drink-ok", "water fine")
assert(act(ISDrinkFluidAction, { character = plain, fluidContainer = bottle(0.4) }):isValidStart() == "drink-ok", "others drink")

-- 6. another mod's smoke actions: lit off a stove, a cigarette out of a pack
local stove = act(IsStoveSmoking, { character = se, item = item("Cigar") })
assert(stove:isValidStart() == false and stove:isValid() == false, "a cigar off the stove refused")
assert(act(IsStoveSmoking, { character = plain, item = item("Cigar") }):isValidStart() == "stove-ok", "others smoke off the stove")
assert(act(IDNALTakeCigarette, { character = se, pack = item("CigarettePack") }):isValidStart() == false, "a cigarette out of the pack refused")
-- a class that loads after this file is picked up at game start
IsCarSmoking = { isValidStart = function() return "car-ok" end, isValid = function() return "car-ok" end }
assert(act(IsCarSmoking, { character = se, item = item("CigaretteSingle") }):isValidStart() == "car-ok", "not wrapped yet")
H.fire("OnGameStart")
assert(act(IsCarSmoking, { character = se, item = item("CigaretteSingle") }):isValidStart() == false, "the car lighter refused after game start")
assert(act(IsCarSmoking, { character = plain, item = item("CigaretteSingle") }):isValidStart() == "car-ok", "others use the car lighter")

-- 5. Vegetarian's reason still comes first for meat
local veg = H.player({ traits = { "vegetarian", "straightedge" } })
assert(DanTraits_RefuseReason(veg, { getType = function() return "Steak" end, getFoodType = function() return "Beef" end }) == "UI_DanTraits_VegetarianRefuse", "meat: vegetarian's reason")

H.pass()

-- Offline test for DanTraits_StraightEdge.lua: tobacco and alcoholic food
-- refused through the eat action with Straight Edge's own reason, packs and
-- chewing tobacco through the pill action, alcoholic drinks through the drink
-- action, and everyone else left alone.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
ISEatFoodAction.isValidStart = function() return "start-ok" end
ISEatFoodAction.isValid = function() return "valid-ok" end
ISTakePillAction.isValidStart = function() return "pill-ok" end
ISTakePillAction.isValid = function() return "pill-ok" end
ISDrinkFluidAction.isValidStart = function() return "drink-ok" end
ISDrinkFluidAction.isValid = function() return "drink-ok" end
H.load("Smoker", "Vegetarian", "StraightEdge")

local function item(name, alcoholic)
  return { getType = function() return name end, getOnEat = function() return "" end,
    isAlcoholic = function() return alcoholic == true end }
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

-- 5. Vegetarian's reason still comes first for meat
local veg = H.player({ traits = { "vegetarian", "straightedge" } })
assert(DanTraits_RefuseReason(veg, { getType = function() return "Steak" end, getFoodType = function() return "Beef" end }) == "UI_DanTraits_VegetarianRefuse", "meat: vegetarian's reason")

H.pass()

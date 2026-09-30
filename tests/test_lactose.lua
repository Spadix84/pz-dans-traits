-- Offline test for DanTraits_Lactose.lua and the dairy tag: what counts as
-- dairy, a dose by portion or by litres of milk, the onset wait, the flare's
-- floors, and fading.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("Caffeine", "Lactose")
H.expectEvery("minute", "Lactose")

local near = H.near
local function food(name, hunger, extras)
  local list = extras or {}
  return { getType = function() return name end, getHungChange = function() return -(hunger or 0) / 100 end,
    haveExtraItems = function() return extras ~= nil end,
    getExtraItems = function() return { size = function() return #list end, get = function(_, i) return list[i + 1] end } end }
end

-- 1. dairy by name and in a dish; the safe words
for _, n in ipairs({ "Cheese", "Milk", "Yogurt", "Butter", "IcecreamSandwich", "Pizza", "MacAndCheese" }) do
  assert(DanTraits_IsDairy(food(n)), n .. " is dairy")
end
for _, n in ipairs({ "PeanutButter", "Bread", "Steak", "CoconutMilk", "ButternutSquash" }) do
  assert(not DanTraits_IsDairy(food(n)), n .. " is not")
end
assert(DanTraits_IsDairy(food("Stew", 0, { "Base.Potato", "Base.Cheese" })), "cheese in the stew")

-- 2. a wedge of cheese: a full flare after the onset
local p = H.player({ traits = { "lactose" } }); H.current = p
local d = DanTraits_Data(p)
DanTraits_OnEat(p, food("Cheese", 15), 1)
near(d.lacPending, 1, 1e-9, "a full dose")
assert(H.halo[#H.halo] == "UI_DanTraits_LactoseAte", "notice")
H.mins(30); assert(d.lacFlare == 0, "nothing during the onset")
H.mins(30); near(d.lacFlare, 1, 1e-9, "full flare after the ramp")
assert(H.pain(p) > 0 and p._st.foodsick > 0 and p._st.unhappy > 0, "cramps, queasy, low")
assert(p._st.foodsick <= 35, "no worse than Queasy")
H.mins(400); assert(d.lacFlare == 0, "gone in about six hours")

-- 3. half a glass of milk through the drink hook: half a flare
-- (the game's fluid is CowMilk, not Milk)
local function fluid(name) return { getPrimaryFluid = function() return { getFluidTypeString = function() return name end } end } end
local milk = fluid("CowMilk")
DanTraits_RunHooks("drink", nil, p, milk, 0.15)
near(d.lacPending, 0.5, 1e-9, "0.15 l is half a dose")
for _, n in ipairs({ "cowmilk", "sheepmilk", "animalmilk", "milkchocolate", "cream" }) do
  assert(DanTraits_IsDairyFluid(n), n .. " is a dairy fluid")
end
for _, n in ipairs({ "water", "coffee", "coconutmilk", "soymilk", "beer" }) do
  assert(not DanTraits_IsDairyFluid(n), n .. " is not")
end
local water = fluid("Water")
DanTraits_RunHooks("drink", nil, p, water, 1)
near(d.lacPending, 0.5, 1e-9, "water: nothing")

-- 4. without the trait nothing
local plain = H.player(); H.current = plain
DanTraits_OnEat(plain, food("Cheese", 15), 1)
assert(not DanTraits_Data(plain).lacPending, "no trait: no dose")

H.pass()

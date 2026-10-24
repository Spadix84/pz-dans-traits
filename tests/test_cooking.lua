-- Offline test for the cooking overhaul (DanTraits_Cooking.lua, the fitnessXpAll hook and
-- the experience cap in DanTraits_Fitness.lua, the Good Meal moodle, the tooltip line in
-- client/DanTraits_CookingClient.lua; plans/cooking-overhaul.md): a dish's tier, a proper
-- meal from bites, the afterglow and what scales it, Fuelled and the buff by what the dish
-- is mostly, a side stitch, diet goals and weight, the cook's stamp.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
SandboxVars = { DanTraits = {} }
MoodleType.HEAVY_LOAD, MoodleType.FOOD_EATEN = "heavy", "foodeaten"
BodyPartType.Torso_Lower = "Torso_Lower"
ISTimedActionQueue = { getTimedActionQueue = function() return { queue = { H.action } } end }

-- the game's add-ingredient action, as far as the stamp needs it
ISAddItemInRecipe = { complete = function(self) return true end }

-- Age's quiet experience adjust, recorded
local adjusts = {}
function DanTraits_AgeXpAdjust(player, perk, extra) adjusts[#adjusts + 1] = { perk = perk, extra = extra } end
function DanTraits_AgeXpBusy() return false end

H.load("FitnessData", "Fitness", "Cooking", "Moodles")
H.expectEvery("minute", "Cooking")

-- a dish: o.n ingredients, o.kcal, o.p / o.c / o.f grams, o.unhappy, o.stress, flags
local function dish(o)
  o = o or {}
  local it = { _md = o.md or {} }
  local function v(x, default) if x == nil then return default end return x end
  function it:getFullType() return o.type or "Base.PotOfStew" end
  function it:getType() return (o.type or "Base.PotOfStew"):gsub("^.*%.", "") end
  function it:isBurnt() return o.burnt == true end
  function it:isRotten() return o.rotten == true end
  function it:isCooked() return v(o.cooked, true) end
  function it:isCookable() return v(o.cookable, true) end
  function it:isFresh() return v(o.fresh, true) end
  function it:haveExtraItems() return (o.n or 0) > 0 end
  function it:getExtraItems() local n = o.n or 0; return { size = function() return n end, get = function() return "Base.Carrots" end } end
  function it:getSpices() return o.spices and { size = function() return 1 end } or nil end
  function it:getCalories() return v(o.kcal, 600) end
  function it:getUnhappyChange() return o.unhappy or 0 end
  function it:getStressChange() return o.stress or 0 end
  function it:getProteins() return v(o.p, 40) end
  function it:getCarbohydrates() return v(o.c, 20) end
  function it:getLipids() return v(o.f, 10) end
  function it:getModData() return self._md end
  return it
end

local newPlayer = H.factory({}, function(p, o)
  p._levels = o.levels or {}
  p.getPerkLevel = function(_, perk) return p._levels[perk] or 0 end
  p._food = 0
  p.getMoodles = function() return { getMoodleLevel = function(_, t) return t == "foodeaten" and p._food or 0 end } end
  p._inc, p._dec, p._cal = false, false, 0
  p.getNutrition = function()
    return { getWeight = function() return p._weight end, setWeight = function(_, w) p._weight = w end,
             getCalories = function() return p._cal end, isIncWeight = function() return p._inc end,
             isDecWeight = function() return p._dec end }
  end
  local stiff = { _s = 0 }
  function stiff:getStiffness() return self._s end
  function stiff:setStiffness(x) self._s = x end
  p._lower = stiff
  local bdFn = p.getBodyDamage
  p.getBodyDamage = function()
    local bd = bdFn()
    bd.getBodyPart = function(_, t) if t == "Torso_Lower" then return stiff end end
    return bd
  end
end)
local function data(p) return p:getModData().DanTraits end

-- 1. the tier
H.hours = 100
local p = newPlayer({ levels = { Cooking = 0 } }); H.current = p
assert(DanTraits_CookTier(p, dish({ n = 1 })) == 0, "one ingredient: not a dish")
assert(DanTraits_CookTier(p, dish({ n = 2 })) == 1, "two ingredients, cooked: Home-cooked")
assert(DanTraits_CookTier(p, dish({ n = 5 })) == 1, "Cooking 0: Home-cooked however many")
assert(DanTraits_CookTier(p, dish({ n = 3, burnt = true })) == 0, "burnt: none")
assert(DanTraits_CookTier(p, dish({ n = 3, rotten = true })) == 0, "rotten: none")
assert(DanTraits_CookTier(p, dish({ n = 3, cooked = false })) == 0, "a raw stew: none")
assert(DanTraits_CookTier(p, dish({ n = 3, cooked = false, cookable = false })) == 1, "a sandwich: Home-cooked")
p._levels.Cooking = 3
assert(DanTraits_CookTier(p, dish({ n = 3 })) == 2, "Cooking 3, three ingredients: Hearty")
assert(DanTraits_CookTier(p, dish({ n = 2 })) == 1, "Cooking 3, two ingredients: Home-cooked")
assert(DanTraits_CookTier(p, dish({ n = 6, cooked = false, cookable = false })) == 1, "a big sandwich stays Home-cooked")
p._levels.Cooking = 7
assert(DanTraits_CookTier(p, dish({ n = 4 })) == 3, "Cooking 7, four ingredients: Chef's")
assert(DanTraits_CookTier(p, dish({ n = 3, spices = true })) == 3, "three and a spice: Chef's")
assert(DanTraits_CookTier(p, dish({ n = 3 })) == 2, "three, no spice: Hearty")
assert(DanTraits_CookTier(p, dish({ n = 4, fresh = false })) == 2, "stale: a tier down")
-- the cook's stamp wins over the eater's level
assert(DanTraits_CookTier(p, dish({ n = 4, md = { dtCook = 2 } })) == 1, "stamped Cooking 2: Home-cooked")
p._levels.Cooking = 0
assert(DanTraits_CookTier(p, dish({ n = 4, md = { dtCook = 8 } })) == 3, "stamped Cooking 8: Chef's for anyone")

-- 2. what the dish is mostly
assert(DanTraits_CookMacro(40, 20, 10) == "protein", "a meat stew: protein")
assert(DanTraits_CookMacro(5, 100, 5) == "carbs", "pasta: carbs")
assert(DanTraits_CookMacro(5, 10, 40) == "fat", "fried: fat")
assert(DanTraits_CookMacro(0, 0, 0) == nil, "no data: nothing")

-- 3. bites add up to a meal: 300 kcal
p = newPlayer({ levels = { Cooking = 3 } }); H.current = p
local stew = dish({ n = 3, kcal = 400, unhappy = -20, stress = -0.1 })
DanTraits_OnEat(p, stew, 0.5)
local d = data(p)
assert(d.ckGlow == nil and d.ckFuel == nil, "200 kcal: not yet a meal")
H.clearHalo()
DanTraits_OnEat(p, stew, 0.5)
assert(d.ckGlow and d.ckGlow.tier == 2, "the second half makes a Hearty meal")
assert(d.ckFuel and d.ckFuel.tier == 2 and d.ckFuel.min == 240, "Fuelled for four hours")
assert(d.ckMacro and d.ckMacro.kind == "protein" and d.ckMacro.min == 360, "mostly protein: Recovering, six hours")
assert(H.halo[1] == "+UI_DanTraits_CookMealMacro:IGUI_DanTraits_CookTier_Hearty", "a notice: " .. tostring(H.halo[1]))
-- Hearty: 10 + half of the meal's own 20, over four hours; stress 0.05 + half of 0.1
H.near(d.ckGlow.unhappy, 20, 1e-9, "unhappiness to pay")
H.near(d.ckGlow.stress, 0.1, 1e-9, "stress to pay")
assert(d.ckGlow.max == 240, "Hearty glows four hours")
-- bites far apart do not add up
local q = newPlayer(); H.current = q
DanTraits_OnEat(q, dish({ n = 2, kcal = 200 }), 1)
H.hours = H.hours + 2
DanTraits_OnEat(q, dish({ n = 2, kcal = 200 }), 1)
assert(data(q).ckGlow == nil, "two snacks two hours apart: no meal")
H.hours = 100
-- a dish that is not one: nothing
DanTraits_OnEat(q, dish({ n = 1, kcal = 900 }), 1)
assert(data(q).ckGlow == nil, "one ingredient: nothing")

-- 4. the glow pays out awake, a minute at a time, and ends
H.current = p
p._st.unhappy, p._st.stress = 60, 0.5
H.minute()
H.near(p._st.unhappy, 60 - 20 / 240, 1e-6, "a minute's unhappiness")
H.near(p._st.stress, 0.5 - 0.1 / 240, 1e-6, "a minute's stress")
p._asleep = true
local u = p._st.unhappy
H.minute()
H.near(p._st.unhappy, u, 1e-9, "asleep: nothing paid")
p._asleep = false
assert(d.ckMoodle == -1, "Good Meal moodle")
H.mins(240)
assert(d.ckGlow == nil, "over after four hours")
assert(d.ckFuel == nil, "Fuelled over too")
assert(d.ckMacro and d.ckMacro.min > 0, "Recovering still running")
H.mins(120)
assert(d.ckMacro == nil, "Recovering over after six hours")
assert(d.ckMoodle == 0, "moodle off")

-- 5. what scales the glow: home, the same dish within a day, Sensory, Depression
local h = newPlayer({ levels = { Cooking = 0 }, traits = { "homebody" } }); H.current = h
data(h) -- nothing yet
h:getModData().DanTraits = { hmAtHome = true }
DanTraits_OnEat(h, dish({ n = 2, kcal = 400, type = "Base.Salad" }), 1)
H.near(data(h).ckGlow.unhappy, 6 * 1.5, 1e-9, "a Homebody at home: x1.5")
local r = newPlayer({ levels = { Cooking = 0 } }); H.current = r
r:getModData().DanTraits = { hmAtHome = true }
DanTraits_OnEat(r, dish({ n = 2, kcal = 400 }), 1)
H.near(data(r).ckGlow.unhappy, 6 * 1.25, 1e-9, "at home: x1.25")
-- the same dish again tomorrow is fine, within the day it is halved
data(r).ckGlow = nil
data(r).ckBite = nil
DanTraits_OnEat(r, dish({ n = 2, kcal = 400 }), 1)
H.near(data(r).ckGlow.unhappy, 6 * 1.25 * 0.5, 1e-9, "the same dish within a day: halved")
-- a smaller glow does not replace a bigger one still running
local big = data(r).ckGlow
data(r).ckBite = nil
DanTraits_OnEat(r, dish({ n = 2, kcal = 400, type = "Base.Soup" }), 1)
assert(data(r).ckGlow ~= big, "a fresh dish's glow pays more than what is left: replaces")
local now = data(r).ckGlow
data(r).ckBite = nil
DanTraits_OnEat(r, dish({ n = 2, kcal = 400, type = "Base.Soup" }), 1)
assert(data(r).ckGlow == now, "the same again, halved: does not replace")
-- Sensory Issues: a texture they cannot stand gives no glow, the training buffs still come
local s = newPlayer(); H.current = s
DanTraits_SensoryFood = function() return "disliked" end
DanTraits_OnEat(s, dish({ n = 2, kcal = 400 }), 1)
assert(data(s).ckGlow == nil and data(s).ckFuel ~= nil, "disliked: no glow, still Fuelled")
DanTraits_SensoryFood = nil
-- Depression: the comfort-food timer runs as long as the glow
local m = newPlayer({ levels = { Cooking = 7 }, traits = { "spiraling" } }); H.current = m
DanTraits_OnEat(m, dish({ n = 4, kcal = 400 }), 1)
assert(data(m).mddFoodTimer == 300, "Chef's: five hours of comfort food, got " .. tostring(data(m).mddFoodTimer))
H.minute()
assert(data(m).ckMoodle == -2, "Great Meal moodle")

-- 6. the buffs: Recovering, Energised, Full
local f = newPlayer({ levels = { Cooking = 3 } }); H.current = f
DanTraits_OnEat(f, dish({ n = 3, kcal = 400, p = 40, c = 10, f = 5 }), 1)
local fd = data(f)
H.near(DanTraits_RunHooks("fitnessRecovery", 1, f, fd), 1.2, 1e-9, "Hearty protein: recovery x1.2")
fd.ckMacro = nil
H.near(DanTraits_RunHooks("fitnessRecovery", 1, f, fd), 1, 1e-9, "without it: unchanged")
-- Energised: carbs give back part of the endurance spent
fd.ckMacro = { kind = "carbs", tier = 3, min = 100 }
f._st.endurance = 0.8
H.minute()
f._st.endurance = 0.7
H.minute()
H.near(f._st.endurance, 0.7 + 0.1 * 0.15, 1e-9, "Chef's carbs: 15% of the endurance spent back")
assert(fd.deltaLast.enduranceRegen == f._st.endurance, "the frame pipeline told it is not recovery")
-- Full: hunger rises slower
fd.ckMacro = { kind = "fat", tier = 1, min = 100 }
H.near(DanTraits_RunHooks("hungerRise", 0.01, f, fd), 0.01 * 0.95, 1e-12, "Home-cooked fat: hunger rise x0.95")
fd.ckMacro = nil

-- 7. Fuelled, the diet goals and the cap, through Fitness's experience handler
fd.ckFuel = { tier = 3, min = 100 }
adjusts = {}
H.fire("AddXP", f, Perks.Fitness, 10)
H.near(adjusts[1].extra, 1.5, 1e-9, "Chef's Fuelled: +15% on a jog's Fitness")
fd.ckFuel = nil
fd.ckDiet = "bulk"
f._inc = true
adjusts = {}
H.fire("AddXP", f, Perks.Strength, 10)
H.near(adjusts[1].extra, 1, 1e-9, "Bulk, gaining: Strength +10%")
adjusts = {}
H.fire("AddXP", f, Perks.Fitness, 10)
assert(#adjusts == 0, "Bulk: Fitness untouched")
f._inc = false
adjusts = {}
H.fire("AddXP", f, Perks.Strength, 10)
assert(#adjusts == 0, "Bulk, not gaining: nothing")
fd.ckDiet = "cut"
f._dec = true
adjusts = {}
H.fire("AddXP", f, Perks.Fitness, 10)
H.near(adjusts[1].extra, 1, 1e-9, "Cut, losing: Fitness +10%")
f._dec = false
fd.ckDiet = nil
-- the cap: everything together tops out at x2
DanTraits_AddHook("fitnessXpAll", function(k) if TEST_BOOST then return k * TEST_BOOST end end)
TEST_BOOST = 5
adjusts = {}
H.fire("AddXP", f, Perks.Fitness, 10)
H.near(adjusts[1].extra, 10, 1e-9, "x5 capped at x2")
TEST_BOOST = nil
-- the sandbox's pace still applies on top of the cap
TEST_BOOST = 5
SandboxVars.DanTraits.FitnessXp = 50
adjusts = {}
H.fire("AddXP", f, Perks.Fitness, 10)
assert(#adjusts == 0, "x2 then the sandbox's 50%: unchanged, no adjust")
SandboxVars.DanTraits.FitnessXp = nil
TEST_BOOST = nil

-- 8. a side stitch: running while stuffed
local st = newPlayer(); H.current = st
st._food = 3
st._run, st._moving = true, true
H.rollf = 0.01
H.clearHalo()
H.minute()
local sd = data(st)
assert(st._lower._s == 25, "the lower torso stiffens")
assert(sd.ckStitch == 20 and sd.ckMoodle == 1, "Side Stitch moodle")
assert(H.halo[1] == "UI_DanTraits_CookStitch", "a notice")
st._lower._s = 0
H.minute()
assert(st._lower._s == 0, "no second stitch within the hour")
H.rollf = 0.99
st._food = 2
H.mins(70)
H.rollf = 0.01
H.minute()
assert(st._lower._s == 0, "Well Fed is fine")
H.rollf = 0.99
st._run, st._moving = false, false

-- 9. weight: Cut takes it off faster; well fed and trained, back toward normal
local w = newPlayer({ weight = 90 }); H.current = w
w:getModData().DanTraits = { ckDiet = "cut" }
w._dec, w._cal = true, -2500
H.minute()
H.near(w._weight, 90 - 0.25 * 8.5e-6 * 60, 1e-9, "Cut: a quarter more of the game's loss")
w._dec = false
local before = w._weight
local wd = data(w)
wd.ckDiet = nil
wd.ckFuel = { tier = 1, min = 100 }
H.minute()
H.near(w._weight, before, 1e-12, "no training today: no drift")
wd.ftLog = { [tostring(DanTraits_FitDayIndex())] = { pushups = 25 } }
H.minute()
H.near(w._weight, before - 0.2 / 1440, 1e-9, "Fuelled and trained: drifts down")
wd.ckDiet = "bulk"
local held = w._weight
H.minute()
H.near(w._weight, held, 1e-12, "Bulk: no drift down")
local lo = newPlayer({ weight = 65 }); H.current = lo
lo:getModData().DanTraits = { ckFuel = { tier = 1, min = 100 }, ftLog = { [tostring(DanTraits_FitDayIndex())] = { squats = 30 } } }
H.minute()
H.near(lo._weight, 65 + 0.2 / 1440, 1e-9, "underweight: drifts up")

-- 10. the cook's stamp: the highest level of anyone who put an ingredient in
local pot = dish({ n = 2 })
local cook = newPlayer({ levels = { Cooking = 5 } })
ISAddItemInRecipe.complete({ baseItem = pot, character = cook })
assert(pot._md.dtCook == 5, "stamped 5")
ISAddItemInRecipe.complete({ baseItem = pot, character = newPlayer({ levels = { Cooking = 2 } }) })
assert(pot._md.dtCook == 5, "a worse cook adding a carrot keeps the 5")

-- 11. the sandbox option off: nothing, and what was running is cleared
SandboxVars.DanTraits.CookingEnabled = false
H.current = m
H.minute()
assert(data(m).ckGlow == nil and data(m).ckMoodle == 0, "off: cleared")
local o = newPlayer({ levels = { Cooking = 7 } }); H.current = o
DanTraits_OnEat(o, dish({ n = 4, kcal = 900 }), 1)
assert(data(o) == nil or data(o).ckGlow == nil, "off: no meal")
SandboxVars.DanTraits.CookingEnabled = nil

-- 12. the tooltip line
ISToolTipInv = { render = function() end }
function instanceof(obj, cls) return cls == "Food" and type(obj) == "table" and obj.getCalories ~= nil end
H.load("client/DanShared_Tooltip.lua", "client/DanTraits_CookingClient.lua")
local chef = newPlayer({ levels = { Cooking = 7 } })
local lines = DanTraits_CookTooltipLines(chef, dish({ n = 4 }))
assert(lines and lines[1][1] == "Tooltip_DanTraits_CookMealMacro:IGUI_DanTraits_CookTier_Chef", "a Chef's protein dish has a line: " .. tostring(lines and lines[1][1]))
lines = DanTraits_CookTooltipLines(chef, dish({ n = 3, cooked = false }))
assert(lines and lines[1][1] == "Tooltip_DanTraits_CookRaw", "a raw stew: cook it")
assert(DanTraits_CookTooltipLines(chef, dish({ n = 1 })) == nil, "not a dish: nothing")

H.pass("cooking")

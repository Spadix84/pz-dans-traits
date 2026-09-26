-- Offline test for DanTraits_Positives.lua: Iron Stomach's grade and food
-- sickness cuts, Early Riser's start and night bonus, Meal Prepper's start
-- and longer variety window.
local handlers, lists = {}, {}
Events = setmetatable({}, { __index = function(t, k) local e = { Add = function(f) lists[k] = lists[k] or {}; table.insert(lists[k], f); handlers[k] = function(...) for _, g in ipairs(lists[k]) do g(...) end end end, Remove = function() end }; rawset(t, k, e); return e end })
CharacterStat = { INTOXICATION = "intox", STRESS = "stress", PAIN = "pain", FOOD_SICKNESS = "foodsick" }
HaloTextHelper = { addBadText = function() end, addGoodText = function() end }
function getText(k) return k end
DanTraitsRegistry = { ironstomach = "ironstomach", earlyriser = "earlyriser", mealprepper = "mealprepper" }
ISEatFoodAction = { complete = function() return true end, eat = function() end, isValid = function() return true end, isValidStart = function() return true end }
ISTakePillAction = { complete = function() return true end }

function require() end
for _, f in ipairs({ "DanTraits", "DanTraits_Positives" }) do
  assert(loadfile("../DanTraits/42/media/lua/shared/" .. f .. ".lua"))()
end
assert(handlers.OnCreatePlayer and handlers.OnGameStart and handlers.EveryOneMinute, "hooks in place")

local function makePlayer(o)
  o = o or {}
  local traits = {}
  for _, t in ipairs(o.traits or {}) do traits[t] = true end
  local st = { foodsick = 0 }
  local md = {}
  return { hasTrait = function(_, t) return traits[t] == true end, isDead = function() return false end,
    getModData = function() return md end, getHoursSurvived = function() return o.hours or 0 end,
    getStats = function() return { get = function(_, k) return st[k] end, set = function(_, k, v) st[k] = v end } end,
    _st = st, _md = md }
end
local current
function getSpecificPlayer() return current end
local minute = handlers.EveryOneMinute
local function near(a, b, eps, msg) assert(math.abs(a - b) <= eps, msg .. ": expected " .. b .. ", got " .. a) end

-- 1. Iron Stomach: rotten food's grade penalty halved (0.0 -> 0.25); burnt likewise; fresh untouched; without the trait untouched
local iron = makePlayer({ traits = { "ironstomach" } }); current = iron
near(DanTraits_RunHooks("foodGrade", 0.0, iron, {}, "rotten"), 0.25, 1e-9, "rotten: half the penalty")
near(DanTraits_RunHooks("foodGrade", 0.2, iron, {}, "burnt"), 0.35, 1e-9, "burnt: half the penalty")
near(DanTraits_RunHooks("foodGrade", 0.8, iron, {}, "fresh"), 0.8, 1e-9, "fresh: untouched")
local plain = makePlayer(); current = plain
near(DanTraits_RunHooks("foodGrade", 0.0, plain, {}, "rotten"), 0.0, 1e-9, "no trait: full penalty")
-- food sickness climbs half as fast: +20 in a minute becomes +10; a drop is left alone
current = iron; minute()
iron._st.foodsick = 20; minute(); near(iron._st.foodsick, 10, 1e-9, "increase halved")
iron._st.foodsick = 4; minute(); near(iron._st.foodsick, 4, 1e-9, "a fall is left alone")
current = plain; minute(); plain._st.foodsick = 20; minute(); near(plain._st.foodsick, 20, 1e-9, "no trait: untouched")

-- 2. Early Riser: sleep score starts at 0.8 for a new character, once; nights score +0.1, capped at 1
local er = makePlayer({ traits = { "earlyriser" } }); current = er
handlers.OnCreatePlayer(0, er)
near(er._md.DanTraits.vitSleep, 0.8, 1e-9, "sleep starts high")
er._md.DanTraits.vitSleep = 0.3; handlers.OnGameStart(); near(er._md.DanTraits.vitSleep, 0.3, 1e-9, "applied once")
near(DanTraits_RunHooks("nightQuality", 0.5, er, er._md.DanTraits), 0.6, 1e-9, "night +0.1")
near(DanTraits_RunHooks("nightQuality", 0.95, er, er._md.DanTraits), 1.0, 1e-9, "capped")
near(DanTraits_RunHooks("nightQuality", 0.5, plain, {}), 0.5, 1e-9, "no trait: untouched")
local old = makePlayer({ traits = { "earlyriser" }, hours = 10 }); current = old
handlers.OnCreatePlayer(0, old); assert(old._md.DanTraits == nil or old._md.DanTraits.vitSleep == nil, "existing character: untouched")

-- 3. Meal Prepper: diet score starts at 0.8; the variety window is 120 hours for the current player, 72 otherwise
local mp = makePlayer({ traits = { "mealprepper" } }); current = mp
handlers.OnCreatePlayer(0, mp)
near(mp._md.DanTraits.vitDiet, 0.8, 1e-9, "diet starts high")
assert(mp._md.DanTraits.vitSleep == nil, "only the diet")
near(DanTraits_RunHooks("varietyHours", 72), 120, 1e-9, "five-day window")
current = plain; near(DanTraits_RunHooks("varietyHours", 72), 72, 1e-9, "no trait: three days")

print("test_positives: all passed")

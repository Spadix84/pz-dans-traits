-- Offline test for DanTraits_Anemia.lua: iron drains over five days, meat,
-- greens, eggs and pills top it up, and the deficit slows endurance
-- recovery, tires and makes colds easier to catch.
local handlers, lists = {}, {}
Events = setmetatable({}, { __index = function(t, k) local e = { Add = function(f) lists[k] = lists[k] or {}; table.insert(lists[k], f); handlers[k] = function(...) for _, g in ipairs(lists[k]) do g(...) end end end, Remove = function() end }; rawset(t, k, e); return e end })
CharacterStat = { INTOXICATION = "intox", STRESS = "stress", PAIN = "pain", FATIGUE = "fatigue", ENDURANCE = "endurance" }
local halo = {}
HaloTextHelper = { addBadText = function(_, t) halo[#halo+1] = t end, addGoodText = function(_, t) halo[#halo+1] = "+" .. t end }
function getText(k) return k end
DanTraitsRegistry = { anemia = "anemia" }
ISEatFoodAction = { complete = function() return true end, eat = function() end, isValid = function() return true end, isValidStart = function() return true end }
ISTakePillAction = { complete = function() return true end }

function require() end
for _, f in ipairs({ "DanTraits", "DanTraits_Anemia" }) do
  assert(loadfile("../DanTraits/42/media/lua/shared/" .. f .. ".lua"))()
end
assert(handlers.EveryOneMinute and handlers.OnPlayerUpdate, "hooks in place")

local function makePlayer(o)
  o = o or {}
  local traits = {}
  for _, t in ipairs(o.traits or { "anemia" }) do traits[t] = true end
  local st = { fatigue = 0, endurance = 0.5 }
  local md = {}
  local p = { hasTrait = function(_, t) return traits[t] == true end, isDead = function() return false end,
    isAsleep = function() return false end, getModData = function() return md end,
    getStats = function() return { get = function(_, k) return st[k] end, set = function(_, k, v) st[k] = v end } end,
    _st = st, _md = md, _catch = 0 }
  p.getBodyDamage = function() return { getCatchACold = function() return p._catch end, setCatchACold = function(_, v) p._catch = v end } end
  return p
end
local function food(name, foodType, kcal) return { getType = function() return name end, getFoodType = function() return foodType end, getCalories = function() return kcal end } end
local current
function getSpecificPlayer() return current end
local minute, frame = handlers.EveryOneMinute, handlers.OnPlayerUpdate
local function A(p) return p._md.DanTraits end
local function near(a, b, eps, msg) assert(math.abs(a - b) <= eps, msg .. ": expected " .. b .. ", got " .. a) end

-- 1. starts at 0.6 and drains: a day takes 0.2
local p = makePlayer(); current = p
minute(); near(A(p).anIron, 0.6 - 1 / 7200, 1e-9, "start 0.6, one minute of drain")
for _ = 1, 24 * 60 - 1 do minute() end
near(A(p).anIron, 0.4, 1e-6, "a day: -0.2")
assert(DanTraits_IronDeficit(p) < 1e-6, "no deficit at 0.4")

-- 2. food: a 300 kcal steak +0.15, a 150 kcal fish +0.075, half a portion half; greens +0.04; an egg +0.05; bread nothing
DanTraits_RunHooks("eat", nil, p, food("Steak", "Meat", 300), 1); near(A(p).anIron, 0.55, 1e-6, "steak")
DanTraits_RunHooks("eat", nil, p, food("Bass", "Fish", 150), 1); near(A(p).anIron, 0.625, 1e-6, "small fish")
DanTraits_RunHooks("eat", nil, p, food("Venison", "Game", 600), 0.5); near(A(p).anIron, 0.7, 1e-6, "half a big portion, capped at a full 0.15")
DanTraits_RunHooks("eat", nil, p, food("Cabbage", "Vegetables", 30), 1); near(A(p).anIron, 0.74, 1e-6, "greens")
DanTraits_RunHooks("eat", nil, p, food("Egg", "Egg", 80), 1); near(A(p).anIron, 0.79, 1e-6, "egg")
DanTraits_RunHooks("eat", nil, p, food("Bread", "Bread", 700), 1); near(A(p).anIron, 0.79, 1e-6, "bread: nothing")
DanTraits_RunHooks("pill", nil, p, "IronPills"); near(A(p).anIron, 1.0, 1e-6, "a pill +0.25, capped at 1")

-- 3. the deficit: at iron 0.2 it is 0.5: a notice, fatigue creeps, endurance recovers 20% slower, colds catch 25% easier
local d = makePlayer(); current = d
d._md.DanTraits = { anIron = 0.2 + 1 / 7200 }
minute(); near(A(d).anDeficit, 0.5, 1e-6, "deficit 0.5 at iron 0.2")
assert(halo[#halo] == "UI_DanTraits_Anemia1", "faint")
assert(d._st.fatigue > 0, "fatigue creeps")
A(d).anLastEndurance = 0.5; d._st.endurance = 0.6; frame(d)
near(d._st.endurance, 0.5 + 0.1 * 0.8, 1e-9, "endurance gain x 0.8")
d._catch = 10; minute(); near(d._catch, 10 * 1.25, 0.01, "cold catching x 1.25 (deficit drifts a hair during the minute)")
d._md.DanTraits.anIron = 0.01; minute(); assert(halo[#halo] == "UI_DanTraits_Anemia2", "light-headed at deficit 0.9+")

-- 4. no trait: no drain, no effects, food ignored
local n = makePlayer({ traits = {} }); current = n
minute(); assert(n._md.DanTraits == nil or n._md.DanTraits.anIron == nil, "no trait: nothing tracked")
DanTraits_RunHooks("eat", nil, n, food("Steak", "Meat", 300), 1); assert(n._md.DanTraits == nil or n._md.DanTraits.anIron == nil, "no trait: food ignored")

print("test_anemia: all passed")

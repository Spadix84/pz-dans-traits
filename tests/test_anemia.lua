-- Offline test for DanTraits_Anemia.lua: iron drains over five days, meat,
-- greens, eggs and pills top it up, and the deficit slows endurance
-- recovery, tires and makes colds easier to catch.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("Anemia")
H.expectEvery("minute", "Anemia")
H.expectEvery("frame", "Delta:enduranceRegen"); H.expectEvery("minute", "Delta:catchCold")   -- Anemia subscribes to the pipeline

local newPlayer = H.factory({ traits = { "anemia" }, endurance = 0.5 })
local function food(name, foodType, kcal) return { getType = function() return name end, getFoodType = function() return foodType end, getCalories = function() return kcal end } end
local halo, near = H.halo, H.near
local minute, frame = H.minute, H.frame
local function A(p) return p._md.DanTraits end

-- 1. starts at 0.6 and drains: a day takes 0.2
local p = newPlayer(); H.current = p
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
local d = newPlayer(); H.current = d
d._md.DanTraits = { anIron = 0.2 + 1 / 7200 }
minute(); near(A(d).anDeficit, 0.5, 1e-6, "deficit 0.5 at iron 0.2")
assert(halo[#halo] == "UI_DanTraits_Anemia1", "faint")
assert(d._st.fatigue > 0, "fatigue creeps")
DanTraits_DeltaRemember(A(d), "enduranceRegen", 0.5); d._st.endurance = 0.6; frame(d)
near(d._st.endurance, 0.5 + 0.1 * 0.8, 1e-9, "endurance gain x 0.8")
d._catch = 10; minute(); near(d._catch, 10 * 1.25, 0.01, "cold catching x 1.25 (deficit drifts a hair during the minute)")
d._md.DanTraits.anIron = 0.01; minute(); assert(halo[#halo] == "UI_DanTraits_Anemia2", "light-headed at deficit 0.9+")

-- 4. no trait: no drain, no effects, food ignored
local n = newPlayer({ traits = {} }); H.current = n
minute(); assert(n._md.DanTraits == nil or n._md.DanTraits.anIron == nil, "no trait: nothing tracked")
DanTraits_RunHooks("eat", nil, n, food("Steak", "Meat", 300), 1); assert(n._md.DanTraits == nil or n._md.DanTraits.anIron == nil, "no trait: food ignored")

H.pass()

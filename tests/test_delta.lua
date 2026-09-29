-- Offline test for the stat delta pipeline (DanTraits_DeltaHook in
-- DanTraits_Util.lua, registered in core): the game's rise is offered to every
-- subscriber once, the cuts multiply (two of 0.5 leave 0.25, at every frame, not
-- decaying), a fall is never touched, the stat's maximum holds, the mod's own
-- floors are told apart from the game's rise (Iron Stomach), and the real
-- subscribers (Vitality, Anemia, Asthma) compose.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("Vitality", "Anemia", "Asthma", "Positives")
local near, minute, frame = H.near, H.minute, H.frame

-- the pipeline is first in its cadence, and one entry per hook
local function firstOf(cadence) return DanTraits_Drivers[cadence][1].label end
assert(firstOf("frame") == "Delta:enduranceRegen", "frame: the pipeline runs first, got " .. firstOf("frame"))
assert(DanTraits_Drivers.minute[1].label == "Delta:catchCold" and DanTraits_Drivers.minute[2].label == "Delta:foodSicknessRise", "minute: pipeline first")
assert(DanTraits_Drivers.frame[1].order == 0 and DanTraits_Drivers.minute[1].order == 0, "order 0")
H.expectEvery("frame", "Delta:enduranceRegen"); H.expectEvery("minute", "Delta:catchCold"); H.expectEvery("minute", "Delta:foodSicknessRise")

-- 1. the real subscribers multiply: Vitality +1 (x1.2), Asthma tier 2 (x0.5), Anemia at deficit 0.5 (x0.8)
local p = H.player({ traits = { "asthma", "anemia" }, endurance = 0.2 }); H.current = p
p._md.DanTraits = { vitality = 1, asthma = 0.6, anIron = 0.2 }
frame(p)                                   -- first look: adopts 0.2, nothing to scale
near(p._st.endurance, 0.2, 1e-12, "first frame adopts the value")
p._st.endurance = 0.4; frame(p)            -- the game gave +0.2
near(p._st.endurance, 0.2 + 0.2 * 1.2 * 0.5 * 0.8, 1e-9, "1.2 x 0.5 x 0.8 of the game's regen")
p._st.endurance = p._st.endurance + 0.2; frame(p)   -- and again: no drift, the same factor every frame
near(p._st.endurance, 0.2 + 2 * 0.2 * 0.48, 1e-9, "the same factor the second frame")
-- a fall passes through, and the next rise is measured from the fall
p._st.endurance = 0.1; frame(p); near(p._st.endurance, 0.1, 1e-12, "a fall is untouched")
p._st.endurance = 0.2; frame(p); near(p._st.endurance, 0.1 + 0.1 * 0.48, 1e-9, "a rise after a fall")
-- catch-a-cold: Vitality +1 (x0.7) and Anemia 0.5 (x1.25)
minute()
p._catch = 10; minute(); near(p._catch, 10 * 0.7 * 1.25, 0.05, "colds: 0.7 x 1.25")
p._catch = 2; minute(); near(p._catch, 2, 1e-12, "a fall in catch-a-cold is untouched")

-- 2. two synthetic subscribers of 0.5 leave exactly 0.25 of the game's regen; the maximum holds
DanTraits_Hooks.enduranceRegen = {}
DanTraits_AddHook("enduranceRegen", function(delta) return delta * 0.5 end)
DanTraits_AddHook("enduranceRegen", function(delta) return delta * 0.5 end)
local q = H.player({ endurance = 0.3 }); H.current = q
frame(q)
q._st.endurance = 0.7; frame(q); near(q._st.endurance, 0.3 + 0.4 * 0.25, 1e-12, "0.5 x 0.5 = exactly 0.25 of the regen")
q._st.endurance = 0.9; frame(q); near(q._st.endurance, 0.4 + 0.5 * 0.25, 1e-12, "and again, no compounding through last frame's cuts")
q._st.endurance = 0.3; frame(q); near(q._st.endurance, 0.3, 1e-12, "negative delta untouched")
local function rise(p, from, to) DanTraits_DeltaRemember(p._md.DanTraits, "enduranceRegen", from); p._st.endurance = to; frame(p); return p._st.endurance end
DanTraits_Hooks.enduranceRegen = {}
DanTraits_AddHook("enduranceRegen", function(delta) return delta * 10 end)
near(rise(q, 0.5, 0.6), 1, 1e-12, "never above the stat's maximum")
DanTraits_Hooks.enduranceRegen = {}
DanTraits_AddHook("enduranceRegen", function() error("boom") end)
DanTraits_AddHook("enduranceRegen", function(delta) return delta * 0.5 end)
near(rise(q, 0.2, 0.6), 0.4, 1e-12, "a failing subscriber is skipped, the rest still apply")
DanTraits_Hooks.enduranceRegen = {}
DanTraits_AddHook("enduranceRegen", function(delta) return -delta end)
near(rise(q, 0.2, 0.6), 0.2, 1e-12, "a subscriber cannot turn a rise into a fall")
DanTraits_Hooks.enduranceRegen = {}
near(rise(q, 0.2, 0.6), 0.6, 1e-12, "no subscribers: the game's rise as it is")

-- 3. DanTraits_DeltaRemember: a later writer's clamp is the new starting point
DanTraits_Hooks.enduranceRegen = {}
DanTraits_AddHook("enduranceRegen", function(delta) return delta * 0.5 end)
local r = H.player({ endurance = 0.9 }); H.current = r
frame(r)
r._st.endurance = 0.3; DanTraits_DeltaRemember(r._md.DanTraits, "enduranceRegen", 0.3)   -- a ceiling pulled it down
r._st.endurance = 0.5; frame(r); near(r._st.endurance, 0.4, 1e-12, "regen after a clamp is measured from the clamp")

-- 4. Iron Stomach: the game's rise is halved, a mod floor's is not
local iron = H.player({ traits = { "ironstomach" } }); H.current = iron
minute()
iron._st.foodsick = 20; minute(); near(iron._st.foodsick, 10, 1e-9, "the game's rise: halved")
-- a hangover-style floor raises it by 5: recorded, not halved
DanTraits_FloorUp(iron:getStats(), CharacterStat.FOOD_SICKNESS, 30, 5)
near(iron._st.foodsick, 15, 1e-9, "the floor raised it")
assert(iron._md.DanTraits.floorsThisMinute.foodSicknessRise == true, "floor recorded")
minute(); near(iron._st.foodsick, 15, 1e-9, "a mod floor's rise is left alone")
assert(not iron._md.DanTraits.floorsThisMinute.foodSicknessRise, "flag cleared after the run")
iron._st.foodsick = 25; minute(); near(iron._st.foodsick, 20, 1e-9, "the next game rise is halved again")
-- a floor that does not raise anything (already there) records nothing
DanTraits_FloorUp(iron:getStats(), CharacterStat.FOOD_SICKNESS, 10, 5)
assert(not iron._md.DanTraits.floorsThisMinute.foodSicknessRise, "a floor already met records nothing")
-- a floor on a stat with no hook records nothing
DanTraits_FloorUp(iron:getStats(), CharacterStat.PAIN, 10, 5)
local n = 0; for _ in pairs(iron._md.DanTraits.floorsThisMinute) do n = n + 1 end
assert(n == 0, "only hooked stats are recorded")
-- no trait: untouched
local plain = H.player(); H.current = plain
minute(); plain._st.foodsick = 20; minute(); near(plain._st.foodsick, 20, 1e-12, "no trait: food sickness untouched")

H.pass()

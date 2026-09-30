-- Offline test for DanTraits_Positives.lua: Iron Stomach's grade and food
-- sickness cuts, Early Riser's start and night bonus, Meal Prepper's start
-- and longer variety window, Night Shift by day, Hollow Legs' hangovers and
-- drinks, and Fast Recovery's grant and blood.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("Positives")
H.expectHooks("OnCreatePlayer", "OnGameStart")
H.expectEvery("minute", "Delta:foodSicknessRise")   -- Iron Stomach subscribes to the pipeline

local near = H.near
local minute = H.minute

-- 1. Iron Stomach: rotten food's grade penalty halved (0.0 -> 0.25); burnt likewise; fresh untouched; without the trait untouched
local iron = H.player({ traits = { "ironstomach" } }); H.current = iron
near(DanTraits_RunHooks("foodGrade", 0.0, iron, {}, "rotten"), 0.25, 1e-9, "rotten: half the penalty")
near(DanTraits_RunHooks("foodGrade", 0.2, iron, {}, "burnt"), 0.35, 1e-9, "burnt: half the penalty")
near(DanTraits_RunHooks("foodGrade", 0.8, iron, {}, "fresh"), 0.8, 1e-9, "fresh: untouched")
local plain = H.player(); H.current = plain
near(DanTraits_RunHooks("foodGrade", 0.0, plain, {}, "rotten"), 0.0, 1e-9, "no trait: full penalty")
-- food sickness climbs half as fast: +20 in a minute becomes +10; a drop is left alone
H.current = iron; minute()
iron._st.foodsick = 20; minute(); near(iron._st.foodsick, 10, 1e-9, "increase halved")
iron._st.foodsick = 4; minute(); near(iron._st.foodsick, 4, 1e-9, "a fall is left alone")
H.current = plain; minute(); plain._st.foodsick = 20; minute(); near(plain._st.foodsick, 20, 1e-9, "no trait: untouched")

-- 2. Early Riser: sleep score starts at 0.8 for a new character, once; nights score +0.1, capped at 1
local er = H.player({ traits = { "earlyriser" } }); H.current = er
H.fire("OnCreatePlayer", 0, er)
near(er._md.DanTraits.vitSleep, 0.8, 1e-9, "sleep starts high")
er._md.DanTraits.vitSleep = 0.3; H.fire("OnGameStart"); near(er._md.DanTraits.vitSleep, 0.3, 1e-9, "applied once")
near(DanTraits_RunHooks("nightQuality", 0.5, er, er._md.DanTraits), 0.6, 1e-9, "night +0.1")
near(DanTraits_RunHooks("nightQuality", 0.95, er, er._md.DanTraits), 1.0, 1e-9, "capped")
near(DanTraits_RunHooks("nightQuality", 0.5, plain, {}), 0.5, 1e-9, "no trait: untouched")
local old = H.player({ traits = { "earlyriser" }, hours = 10 }); H.current = old
H.fire("OnCreatePlayer", 0, old); assert(old._md.DanTraits == nil or old._md.DanTraits.vitSleep == nil, "existing character: untouched")

-- 3. Meal Prepper: diet score starts at 0.8; the variety window is 120 hours for the current player, 72 otherwise
local mp = H.player({ traits = { "mealprepper" } }); H.current = mp
H.fire("OnCreatePlayer", 0, mp)
near(mp._md.DanTraits.vitDiet, 0.8, 1e-9, "diet starts high")
assert(mp._md.DanTraits.vitSleep == nil, "only the diet")
near(DanTraits_RunHooks("varietyHours", 72), 120, 1e-9, "five-day window")
H.current = plain; near(DanTraits_RunHooks("varietyHours", 72), 72, 1e-9, "no trait: three days")

-- 4. Night Shift: by day light wakes you a quarter as easily and costs a quarter as much
local ns = H.player({ traits = { "nightshift" } }); H.current = ns
local hour = 12
getGameTime = function() return { getHour = function() return hour end, getWorldAgeHours = function() return H.hours end } end
near(DanTraits_RunHooks("sleepWake", 1, ns, {}), 0.25, 1e-9, "day: wakes less")
near(DanTraits_RunHooks("sleepBright", 1, ns), 0.25, 1e-9, "day: bright light costs less")
hour = 23
near(DanTraits_RunHooks("sleepWake", 1, ns, {}), 1, 1e-9, "night: as anyone")
near(DanTraits_RunHooks("sleepWake", 1, plain, {}), 1, 1e-9, "no trait: as anyone")
hour = 12

-- 5. Hollow Legs: milder and shorter hangovers, a fifth less from a drink
local hl = H.player({ traits = { "hollowlegs" } }); H.current = hl
near(DanTraits_RunHooks("hangoverSeverity", 1, hl), 0.6, 1e-9, "milder")
near(DanTraits_RunHooks("hangoverHours", 10, hl), 7, 1e-9, "shorter")
hl._st.intox = 10
DanTraits_HollowLegsSip(hl, 0)
near(hl._st.intox, 8, 1e-9, "a drink adds a fifth less")
plain._st.intox = 10; DanTraits_HollowLegsSip(plain, 0); near(plain._st.intox, 10, 1e-9, "no trait: as is")

-- 6. Fast Recovery: Fast Healer granted once; blood back half as fast again
CharacterTrait.FAST_HEALER = "base:fasthealer"
local fr = H.player({ traits = { "fastrecovery" } }); H.current = fr
H.fire("OnCreatePlayer", 0, fr); H.fire("OnGameStart")
assert(fr._traits["base:fasthealer"] and fr._adds == 1, "Fast Healer granted once")
near(DanTraits_RunHooks("bloodVolRefill", 0.01, fr, {}), 0.015, 1e-9, "volume x1.5")
near(DanTraits_RunHooks("bloodCellRebuild", 0.01, fr, {}), 0.015, 1e-9, "cells x1.5")
near(DanTraits_RunHooks("bloodCellRebuild", 0.01, plain, {}), 0.01, 1e-9, "no trait: as is")

H.pass()

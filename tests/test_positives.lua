-- Offline test for DanTraits_Positives.lua: Iron Gut's grade and food
-- sickness cuts, Early Riser's start and night bonus, Meal Prepper's start
-- and longer variety window, Night Shift by day, Hollow Legs' hangovers and
-- drinks, Fast Recovery's grant and blood, Thick Skull (with Bounces Back
-- folded in) and Grit's share of pain reduction.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("Positives")
H.expectHooks("OnCreatePlayer", "OnGameStart")
H.expectEvery("minute", "Delta:foodSicknessRise")
H.expectEvery("minute", "GoodClotter")   -- Iron Gut subscribes to the pipeline
H.expectEvery("minute", "Grit")

local near = H.near
local minute = H.minute

-- 1. Iron Gut (vanilla, Iron Stomach folded in): rotten food's grade penalty halved (0.0 -> 0.25); burnt likewise; fresh untouched; without the trait untouched
local iron = H.player({ vanilla = { "base:irongut" } }); H.current = iron
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


-- 7. Good Clotter: a quarter less blood; whatever vanilla ran a bleed down by is taken off again
local function bleeder(t, o)
  o = o or {}
  local q = { _time = t, _glass = o.glass or false }
  function q:getBleedingTime() return self._time end
  function q:setBleedingTime(v) self._time = v end
  function q:haveGlass() return self._glass end
  function q:haveBullet() return false end
  return q
end
local b1, b2, shard = bleeder(8), bleeder(0), bleeder(5, { glass = true })
local gc = H.player({ traits = { "goodclotter" }, parts = { b1, b2, shard } }); H.current = gc
near(DanTraits_RunHooks("bloodBleed", 0.01, gc, b1, false), 0.0075, 1e-9, "a quarter less blood")
near(DanTraits_RunHooks("bloodBleed", 0.01, plain, b1, false), 0.01, 1e-9, "no trait: as is")
minute()
near(b1._time, 8, 1e-9, "first minute: only remembered")
b1._time = 7.5; minute()
near(b1._time, 7, 1e-9, "vanilla took 0.5: another 0.5 off")
b1._time = 6.8; minute()
near(b1._time, 6.6, 1e-9, "vanilla took 0.2: another 0.2 off")
b1._time = 9; minute()
near(b1._time, 9, 1e-9, "a fresh wound on the part: left alone, remembered")
b1._time = 0.2; minute()
near(b1._time, 0.01, 1e-9, "never cut to nothing: the game ends the bleed itself")
shard._time = 3; minute()
near(shard._time, 3, 1e-9, "glass still in: left alone")
b1._time = 0; minute()
assert(gc._md.DanTraits.gcBleed == nil, "a stopped bleed is forgotten (and nothing else is bleeding but the shard)")
assert(b2._time == 0, "a part that never bled: untouched")
local pb = bleeder(8)
local noclot = H.player({ parts = { pb } }); H.current = noclot
minute(); pb._time = 7; minute(); near(pb._time, 7, 1e-9, "no trait: as vanilla")

-- 8. Thick Skull: half the chance, a quarter less bad, heals half as fast again
local ts = H.player({ traits = { "thickskull" } })
near(DanTraits_RunHooks("concussionChance", 0.6, ts), 0.3, 1e-9, "half the chance")
near(DanTraits_RunHooks("concussionScore", 0.8, ts), 0.6, 1e-9, "a quarter less bad")
near(DanTraits_RunHooks("concussionHeal", 0.001, ts, {}), 0.0015, 1e-9, "heals x1.5")
near(DanTraits_RunHooks("concussionChance", 0.6, plain), 0.6, 1e-9, "no trait: as is")
-- Bounces Back folded in: knockouts and faints half as long, the sumatriptan day-after too
near(DanTraits_RunHooks("passOutMinutes", 10, ts), 5, 1e-9, "out half as long")
near(DanTraits_RunHooks("passOutMinutes", 10, plain), 10, 1e-9, "no trait: out as long")
near(DanTraits_RunHooks("tripAfterMinutes", 1440, ts), 720, 1e-9, "the sumatriptan day-after half a day")

-- 9. Grit: its own share of painReduction is 35% of the pain felt without it; others' share is kept
local gr = H.player({ traits = { "grit" } }); H.current = gr
local red = 0
gr.getBodyDamage = function() return {
  getPainReduction = function() return red end,
  setPainReduction = function(_, v) red = v end,
} end
gr._st.pain = 40; minute()
near(red, 14, 1e-9, "35% of 40")
-- the game now feels 40 - 14 = 26: the share stays at 35% of the pain without Grit
gr._st.pain = 26; minute(); near(red, 14, 1e-9, "steady: still 14")
-- a drink adds 10 of its own: kept, Grit's share follows the felt pain
red = red + 10; gr._st.pain = 16; minute(); near(red, 10 + 0.35 * 30, 1e-9, "the drink's share kept")
-- trait gone: only Grit's share comes off
gr._traits.grit = nil; minute(); near(red, 10, 1e-9, "Grit's share removed")
assert(gr._md.DanTraits.gritCut == nil, "forgotten")
minute(); near(red, 10, 1e-9, "nothing more")

H.pass()

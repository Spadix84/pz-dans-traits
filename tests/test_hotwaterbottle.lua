-- Offline test for the hot water bottle (DanTraits_HotWaterBottle.lua): a bottle seen hot
-- with water in it is full, it cools by its own clock (indoors, in bed, out in the frost),
-- emptying loses the warmth, a bottle heating in a stove is caught, and held on a muscle
-- group it speeds that group's recovery (the fitnessGroupRecovery hook in
-- DanTraits_Fitness.lua), eases its stiffness and a pulled muscle, eases a Bad Back on the
-- core and Arthritis's joints; carried in bed it helps every group and a cold night's score.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
SandboxVars = { DanTraits = {} }
MoodleType.HEAVY_LOAD, MoodleType.HYPOTHERMIA = "heavy", "cold"
for _, n in ipairs({ "Torso_Upper", "Torso_Lower", "UpperArm_L", "UpperArm_R" }) do BodyPartType[n] = n end

-- the action queue: H.action is at its head
ISTimedActionQueue = { getTimedActionQueue = function() return { queue = { H.action } } end }

-- what the game is heating (a stove's contents)
local heating = {}
getCell = function()
  return {
    getGridSquare = function() return nil end,
    getProcessItems = function() return { size = function() return #heating end, get = function(_, i) return heating[i + 1] end } end,
  }
end

-- Bad Back's ease, recorded (the real one is tested in test_agetraits)
local eased = {}
function DanTraits_BadBackEase(player, amount, outMin) eased[#eased + 1] = { amount = amount, out = outMin } end

H.load("FitnessData", "Fitness", "HotWaterBottle")
H.expectEvery("minute", "HotWaterBottle")

local function bottle(o)
  o = o or {}
  local b = { _md = {}, _heat = o.heat or 1, _water = o.water ~= false }
  function b:getFullType() return "Base.HotWaterBottle" end
  function b:getModData() return self._md end
  function b:getItemHeat() return self._heat end
  function b:getFluidContainer()
    local me = self
    return { isEmpty = function() return not me._water end }
  end
  return b
end

local newPlayer = H.factory({}, function(p)
  p._bag = {}
  p.getVehicle = function() return nil end
  p.getFitness = function() return { init = function() end, getCurrentExe = function() return nil end,
    setCurrentExercise = function() end, incRegularity = function() end, getRegularity = function() return 0 end } end
  local inv = p.getInventory
  p.getInventory = function()
    local i = inv()
    i.getAllTypeRecurse = function(_, t)
      local hits = {}
      for _, it in ipairs(p._bag) do if it:getFullType() == t then hits[#hits + 1] = it end end
      return { size = function() return #hits end, get = function(_, n) return hits[n + 1] end }
    end
    return i
  end
  p._parts = {}
  for _, n in ipairs({ "UpperArm_L", "UpperArm_R", "ForeArm_L", "ForeArm_R", "Torso_Upper", "Torso_Lower",
                       "UpperLeg_L", "UpperLeg_R", "LowerLeg_L", "LowerLeg_R" }) do
    local part = { _n = n, _s = 0 }
    function part:getStiffness() return self._s end
    function part:setStiffness(v) self._s = v end
    p._parts[n] = part
  end
  local bdFn = p.getBodyDamage
  p.getBodyDamage = function()
    local bd = bdFn()
    bd.getBodyPart = function(_, t) return p._parts[t] end
    bd.getThermoregulator = function() return { getMetabolicRate = function() return 0 end } end
    return bd
  end
  p._moodles = {}
  p.getMoodles = function() return { getMoodleLevel = function(_, t) return p._moodles[t] or 0 end } end
end)

local function step(n)
  for _ = 1, n do
    H.hours = H.hours + 1 / 60
    H.minute()
  end
end
local function data(p) return p:getModData().DanTraits end
local function heatAction(item, group) return { Type = "ISDanTraitsHeatAction", item = item, group = group } end

H.hours, H.timeOfDay = 100, 12
H.climate.temp = 20

-- 1. carried, fresh from the stove: full; the game's own heat can then fall away
local p = newPlayer(); H.current = p
local b = bottle({ heat = 2.4 })
p._bag[1] = b
step(1)
H.near(b._md.dtHwbLeft, 4, 1e-9, "seen hot with water: four hours of warmth")
assert(DanTraits_HwbStage(b) == "hot", "Hot")
b._heat = 1   -- out of the heat, the game cools it at once
-- 2. indoors: hot for an hour, warm to three, tepid, cold at four
step(59)
assert(DanTraits_HwbStage(b) == "hot", "still Hot at 59 minutes")
step(2)
assert(DanTraits_HwbStage(b) == "warm", "Warm after an hour")
local stage, left = DanTraits_HwbStageLeft(b)
H.near(left, 2 - 1 / 60, 0.02, "about two hours left Warm")
step(120)
assert(DanTraits_HwbStage(b) == "tepid", "Tepid after three hours")
step(60)
assert(DanTraits_HwbStage(b) == nil and b._md.dtHwbLeft == nil, "cold at four hours, and forgotten")

-- 3. in bed it lasts half as long again; out in the frost half as long
b._heat = 2; step(1); b._heat = 1
p._asleep = true
step(90)
H.near(b._md.dtHwbLeft, 4 - 90 / 60 * 2 / 3, 0.02, "asleep: two thirds of an hour an hour")
p._asleep = false
b._heat = 2; step(1); b._heat = 1
p._outside = true; H.climate.temp = -5
step(30)
H.near(b._md.dtHwbLeft, 4 - 1, 0.02, "outdoors below freezing: twice as fast")
H.climate.temp = 5
step(30)
H.near(b._md.dtHwbLeft, 3 - 0.5, 0.02, "outdoors above freezing: the indoor rate")
-- a look at the bottle between minutes (the tooltip, the Hold action's isValid every tick)
-- reads the clock without writing it, so the frost's rate stands (2026-10-22)
b._heat = 2; step(1); b._heat = 1
H.climate.temp = -5
for _ = 1, 30 do
  H.hours = H.hours + 1 / 60
  local stage, left = DanTraits_HwbStageLeft(b)
  assert(stage == "hot" and left > 0, "still Hot while looked at")
  H.minute()
end
H.near(b._md.dtHwbLeft, 4 - 1, 0.02, "looked at every minute in the frost: still twice as fast")
local stampedAt, stampedLeft = b._md.dtHwbAt, b._md.dtHwbLeft
H.hours = H.hours + 0.5
local _, peeked = DanTraits_HwbStage(b)
H.near(peeked, stampedLeft - 0.5, 1e-6, "a look half an hour on reads the time gone (at the indoor rate)")
assert(b._md.dtHwbAt == stampedAt and b._md.dtHwbLeft == stampedLeft, "and moves no stamp")
p._outside, H.climate.temp = false, 20

-- 4. emptied: the warmth goes with the water; an empty bottle never warms
b._water = false
assert(DanTraits_HwbStage(b) == nil and b._md.dtHwbLeft == nil, "emptied: cold")
b._heat = 2.5; step(1)
assert(b._md.dtHwbLeft == nil, "an empty bottle heated is no use")
b._water, b._heat = true, 1

-- 5. a bottle heating in a stove is caught, and counts down at the indoor rate once out
local s = bottle({ heat = 2.8 })
heating[1] = s
step(5)
H.near(s._md.dtHwbLeft, 4, 1e-9, "in the stove: kept full")
heating[1] = nil; s._heat = 1
H.hours = H.hours + 2
assert(DanTraits_HwbStage(s) == "warm", "two hours on the counter: Warm")

-- 6. held on the legs, Hot: they recover twice as fast as the arms, and stiffness eases
p._bag = { b }
b._heat = 2; step(1); b._heat = 1
local d = data(p)
d.ftLoad = { arms = 0.8, legs = 0.8 }
p._parts.UpperLeg_R._s, p._parts.UpperArm_L._s = 20, 20
d.ftStrain = { g = "legs", part = "UpperLeg_L", h = 10 }
H.action = heatAction(b, "legs")
step(30)
local armsFell, legsFell = 0.8 - d.ftLoad.arms, 0.8 - d.ftLoad.legs
H.near(legsFell / armsFell, 2, 1e-6, "Hot on the legs: twice the recovery")
assert(p._parts.UpperLeg_R._s == 0 and p._parts.UpperLeg_L._s == 30, "the legs' stiffness eases (the pulled one held at 30)")
assert(p._parts.UpperArm_L._s == 20, "the arms' does not")
H.near(d.ftStrain.h, 10 - 30 / 60 - 2, 0.01, "a pulled leg muscle: two hours off for a Hot session")
assert(#eased == 0, "not the core: no back ease")
H.near(DanTraits_RunHooks("arthritisJoint", 1, p), 0.8, 1e-9, "Arthritis: joints x0.8 while held Hot")

-- 7. Warm: x1.5; on the core it eases a Bad Back
b._md.dtHwbLeft = 2
d.ftLoad = { arms = 0.8, core = 0.8 }
H.action = heatAction(b, "core")
step(10)
H.near((0.8 - d.ftLoad.core) / (0.8 - d.ftLoad.arms), 1.5, 1e-6, "Warm: x1.5")
assert(#eased == 10 and math.abs(eased[1].amount - 0.0024) < 1e-9, "Bad Back eased each minute, the Warm amount")
H.near(DanTraits_RunHooks("arthritisJoint", 1, p), 0.9, 1e-9, "Arthritis: x0.9 while held Warm")

-- 8. put down: soothed for an hour after, then nothing
H.action = nil
step(1)
H.near(DanTraits_RunHooks("arthritisJoint", 1, p), 0.9, 1e-9, "the hour after: x0.9")
step(60)
H.near(DanTraits_RunHooks("arthritisJoint", 1, p), 1, 1e-9, "after the hour: nothing")
d.ftLoad = { arms = 0.8, legs = 0.8 }
step(10)
H.near(d.ftLoad.arms, d.ftLoad.legs, 1e-12, "not held: every group alike")

-- 9. a tepid or cold bottle held does nothing
b._md.dtHwbLeft = 0.5
H.action = heatAction(b, "legs")
step(5)
H.near(d.ftLoad.arms, d.ftLoad.legs, 1e-12, "Tepid: no help")
assert(data(p).hwbGroup == nil, "not counted as held")
H.action = nil

-- 10. in bed with a warm bottle: every group recovers x1.25 (Hot); a cold night scores better
local q = newPlayer(); H.current = q
local qb = bottle({ heat = 2 })
q._bag = { qb }
step(1); qb._heat = 1
local qd = data(q)
local plain = newPlayer()
plain:getModData().DanTraits = { ftLoad = { arms = 0.8 }, ftLast = {}, ftLog = {} }
qd.ftLoad = { arms = 0.8 }
q._asleep, plain._asleep = true, true
H.climate.temp = 5
for _ = 1, 30 do
  H.hours = H.hours + 1 / 60
  H.current = q; H.minute()
  H.current = plain; H.minute()
end
H.near((0.8 - qd.ftLoad.arms) / (0.8 - plain:getModData().DanTraits.ftLoad.arms), 1.25, 1e-6, "Hot in bed: x1.25")
assert(qd.hwbNightMin == 30, "a cold night counted")
H.near(DanTraits_RunHooks("nightQuality", 0.5, q, qd, 8), 0.5 + 0.05 * 30 / 240, 1e-9, "the night scores better")
assert(qd.hwbNightMin == nil, "read once")
-- a warm night: no lift
H.climate.temp = 20
H.current = q; step(30)
assert(qd.hwbNightMin == nil, "not cold: nothing to score")
-- awake: the count waits for Vitality, which scores the night gapMin (60) minutes after
-- waking (2026-10-22: it was dropped after ten and the lift never landed); unscored, it
-- is dropped a little after that
H.climate.temp = 5; step(5); q._asleep = false
step(11)
assert(qd.hwbNightMin == 5, "awake ten minutes: still counted")
step(DanTraits_NIGHT.gapMin - 11)
assert(qd.hwbNightMin == 5, "awake the whole gap: still there for Vitality's nightQuality")
H.near(DanTraits_RunHooks("nightQuality", 0.5, q, qd, 8), 0.5 + 0.05 * 5 / 240, 1e-9, "and it scores")
local function reheat() qb._heat = 2; step(1); qb._heat = 1 end
H.climate.temp = 5; reheat(); q._asleep = true; step(5); q._asleep = false
step(DanTraits_NIGHT.gapMin + 11)
assert(qd.hwbNightMin == nil, "never read: dropped after the gap and a margin")
-- Restless Sleeper's longer gap holds it longer
DanTraits_AddHook("nightGap", function(gap) return gap * 2 end)
reheat(); q._asleep = true; step(5); q._asleep = false
step(DanTraits_NIGHT.gapMin + 11)
assert(qd.hwbNightMin == 5, "a longer night gap: kept through it")
step(DanTraits_NIGHT.gapMin)
assert(qd.hwbNightMin == nil, "and dropped after that")
H.climate.temp = 20

H.pass()

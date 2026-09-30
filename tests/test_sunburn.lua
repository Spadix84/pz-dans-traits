-- Offline test for DanTraits_Sunburn.lua: bare skin in full sun burns in
-- about three hours, clothing and shade protect, cool weather, cloud and
-- the hour slow it, a burn hurts on the burnt part for a day and heals, skin
-- toughens, sun block keeps the sun off for eight hours, and the sandbox switch.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("Sunburn")
H.expectEvery("minute", "Sunburn")

local near = H.near
H.climate = { temp = 25, rain = 0, humidity = 0.5, night = 0, cloud = 0 }
function instanceof(o, class) return class == "Clothing" and o._covers ~= nil end
local function worn(...)
  local covers = { ... }
  return { _covers = covers, getCoveredParts = function()
    return { size = function() return #covers end, get = function(_, i) return covers[i + 1] end } end }
end

-- a shirt, trousers and shoes: head, neck and hands bare
local shirt = worn("Torso_Upper", "Torso_Lower", "UpperArm_L", "UpperArm_R", "ForeArm_L", "ForeArm_R")
local trousers = worn("Groin", "UpperLeg_L", "UpperLeg_R", "LowerLeg_L", "LowerLeg_R")
local shoes = worn("Foot_L", "Foot_R")
-- body parts that keep their own additional pain, as the game's do
local function part(name)
  local q = { _pain = 0 }
  function q:getType() return name end
  function q:getAdditionalPain() return self._pain end
  function q:setAdditionalPain(v) self._pain = v end
  return q
end
local parts = {}
for _, n in ipairs(DanTraits_SunburnParts) do parts[#parts + 1] = part(n) end
local function partNamed(name) for _, q in ipairs(parts) do if q:getType() == name then return q end end end
local p = H.player({ outside = true, parts = parts }); H.current = p
local wornList = { shirt, trousers, shoes, { name = "a bag" } }
p.getWornItems = function()
  return { size = function() return #wornList end, getItemByIndex = function(_, i) return wornList[i + 1] end }
end
local d = DanTraits_Data(p)

-- 1. the sun: full in summer, none at night, indoors or in the rain, less when cool or cloudy
near(DanTraits_SunOn(p), 1, 1e-9, "summer noon")
H.climate.cloud = 0.5; near(DanTraits_SunOn(p), 0.6, 1e-9, "half cloud")
H.climate.cloud = 0; H.climate.temp = 12.5; near(DanTraits_SunOn(p), 0.5, 1e-9, "cool")
H.climate.temp = 25; H.climate.night = 1; near(DanTraits_SunOn(p), 0, 1e-9, "night")
H.climate.night = 0; p._outside = false; near(DanTraits_SunOn(p), 0, 1e-9, "indoors")
p._outside = true
-- by the clock: full from 11 to 3, half at 9 and 5, nothing by 7 either end
near(DanTraits_SunHeight(13), 1, 1e-9, "midday")
near(DanTraits_SunHeight(11), 1, 1e-9, "eleven"); near(DanTraits_SunHeight(15), 1, 1e-9, "three")
near(DanTraits_SunHeight(9), 0.5, 1e-9, "nine"); near(DanTraits_SunHeight(17), 0.5, 1e-9, "five")
near(DanTraits_SunHeight(7), 0, 1e-9, "seven"); near(DanTraits_SunHeight(20.5), 0, 1e-9, "evening")
local clock = getGameTime
getGameTime = function() return { getTimeOfDay = function() return 9 end } end
near(DanTraits_SunOn(p), 0.5, 1e-9, "nine in the morning: half the sun")
getGameTime = clock
near(DanTraits_SunOn(p), 1, 1e-9, "noon again")

-- 2. two hours: covered parts untouched, bare ones warming, the hot-skin warning
H.mins(130)
assert(not d.sbExp.Torso_Upper and not d.sbExp.Foot_L, "covered: no exposure")
near(d.sbExp.Head, 130 / 180, 1e-9, "bare head warming")
assert(H.halo[#H.halo] == "UI_DanTraits_SunburnHot", "skin feels hot")
assert(not d.sbBurn, "not burnt yet")

-- 3. three hours: the bare parts burn, one notice, pain
H.mins(55)
assert(d.sbBurn and d.sbBurn.Head and d.sbBurn.Neck and d.sbBurn.Hand_L and d.sbBurn.Hand_R, "bare parts burnt")
assert(not d.sbBurn.Torso_Upper, "the shirt kept the torso safe")
local burnt = 0
for _, t in ipairs(H.halo) do if t == "UI_DanTraits_SunburnBurnt" then burnt = burnt + 1 end end
assert(burnt == 1, "one notice")
H.minute()
assert(not (d.painFloors and d.painFloors.sunburn) and not (d.painHurting and d.painHurting.sunburn), "no head floor: the pain is on the parts")
near(partNamed("Head")._pain, 20, 1e-9, "the head hurts: a burnt part settles at 20")
near(partNamed("Hand_L")._pain, 20, 1e-9, "and the hand")
assert(partNamed("Torso_Upper")._pain == 0, "the covered chest does not")
partNamed("Head")._pain = 0   -- the game decays it; the top-up ramps back
H.minute()
near(partNamed("Head")._pain, 4, 1e-9, "topped up by 4 a minute")
partNamed("Hand_L")._pain = 60   -- a wound there hurts more: left alone
H.minute()
near(partNamed("Hand_L")._pain, 60, 1e-9, "never lowered")
near(DanTraits_SunburnShare(p), 4 / 17, 1e-9, "four parts of seventeen")
assert(DanTraits_RunHooks("nightQuality", 1, p, d) < 1, "a worse night")
near(d.sbTan, 0.25, 1e-3, "the skin toughens a little with the burn")
near(DanTraits_SunBurnMinutes(d), 180 * 1.5, 0.5, "and takes half as long again to burn next time")

-- 4. indoors: exposure fades; a day later the burns have healed
p._outside = false
H.mins(19 * 60)
partNamed("Head")._pain = 0
H.minute()
assert(partNamed("Head")._pain > 3.9 and partNamed("Head")._pain < 4.1, "still topped up: ramping again from 0")
H.mins(4)
local easing = partNamed("Head")._pain
assert(easing > 15 and easing < 20, "the last six hours: easing off (about 16 of 20 with five hours left), got " .. tostring(easing))
H.mins(5 * 60 + 5)
assert(not d.sbBurn, "healed in a day")
assert(H.halo[#H.halo] == "+UI_DanTraits_SunburnHealed", "healed notice")
assert(not d.sbExp.Head, "exposure faded")

-- 5. a tan: three hours no longer burns, and a full tan takes three times the sun
p._outside = true
H.mins(200)
assert(not d.sbBurn, "toughened skin: three hours and a bit is not enough now")
d.sbTan = 1
near(DanTraits_SunBurnMinutes(d), 540, 1e-9, "a full tan: nine hours")
d.sbTan, d.sbExp = nil, nil
p._outside = false
H.minute()

-- 6. sun block: the item through the pill hook, eight hours of nothing getting through,
--    a notice when it wears off, and then the sun again
assert(DanTraits_IsSunblock({ getFullType = function() return "DanTraits.Sunblock" end }), "the item is recognised")
assert(not DanTraits_IsSunblock({ getFullType = function() return "Base.Soap2" end }), "soap is not")
H.clearHalo()
DanTraits_RunHooks("pill", nil, p, "Sunblock")
assert(d.sbBlockMin == 480 and H.halo[#H.halo] == "+UI_DanTraits_SunblockOn", "applied: eight hours")
near(DanTraits_SunblockLeft(p), 480, 1e-9, "read by the moodle")
p._outside = true
H.mins(479)
assert(not d.sbBurn and not d.sbExp.Head, "eight hours of summer sun: nothing")
H.minute()
assert(not d.sbBlockMin and H.halo[#H.halo] == "UI_DanTraits_SunblockOff", "worn off, and told so")
H.mins(10)
near(d.sbExp.Head, 10 / 180, 1e-9, "the sun gets through again")
DanTraits_ApplySunblock(p); DanTraits_ApplySunblock(p)
assert(d.sbBlockMin == 480, "a second coat does not stack")
d.sbBlockMin = nil

-- 7. the sandbox switch clears everything
p._outside = true
H.mins(200)
assert(d.sbBurn, "burnt again")
d.sbBlockMin = 100
SandboxVars = { DanTraits = { SunburnEnabled = false } }
H.minute()
assert(not d.sbBurn and not d.sbExp and not d.sbBlockMin, "off: nothing")
SandboxVars = nil

-- 8. Outdoorsman: twice the sun to burn, on top of a tan
local od = H.player({ vanilla = { "base:outdoorsman" } })
local odd = DanTraits_Data(od)
near(DanTraits_SunBurnMinutes(odd, od), 360, 1e-9, "Outdoorsman: six hours")
odd.sbTan = 1
near(DanTraits_SunBurnMinutes(odd, od), 1080, 1e-9, "Outdoorsman with a full tan: eighteen hours")
near(DanTraits_SunBurnMinutes(odd, H.player()), 540, 1e-9, "no trait: nine")

H.pass()

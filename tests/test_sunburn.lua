-- Offline test for DanTraits_Sunburn.lua: bare skin in full sun burns in
-- about three hours, clothing and shade protect, cool weather and cloud
-- slow it, a burn hurts for a day and heals, and the sandbox switch.
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
local p = H.player({ outside = true }); H.current = p
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
assert(H.pain(p) > 0, "it hurts")
near(DanTraits_SunburnShare(p), 4 / 17, 1e-9, "four parts of seventeen")
assert(DanTraits_RunHooks("nightQuality", 1, p, d) < 1, "a worse night")

-- 4. indoors: exposure fades; a day later the burns have healed
p._outside = false
H.mins(24 * 60 + 5)
assert(not d.sbBurn, "healed in a day")
assert(H.halo[#H.halo] == "+UI_DanTraits_SunburnHealed", "healed notice")
assert(not d.sbExp.Head, "exposure faded")

-- 5. the sandbox switch clears everything
p._outside = true
H.mins(200)
assert(d.sbBurn, "burnt again")
SandboxVars = { DanTraits = { SunburnEnabled = false } }
H.minute()
assert(not d.sbBurn and not d.sbExp, "off: nothing")
SandboxVars = nil

H.pass()

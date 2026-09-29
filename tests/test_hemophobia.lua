-- Offline test for DanTraits_Hemophobia.lua: fainting when first aid is
-- done (by action, only on a bleeding wound for dressings, not when
-- removing), a gap before the next faint, slower first aid, the splint,
-- fainting from fast blood loss, and nothing for anyone without the trait.
local handlers, lists = {}, {}
Events = setmetatable({}, { __index = function(t, k) local e = { Add = function(f) lists[k] = lists[k] or {}; table.insert(lists[k], f); handlers[k] = function(...) for _, g in ipairs(lists[k]) do g(...) end end end, Remove = function() end }; rawset(t, k, e); return e end })
CharacterStat = {}
HaloTextHelper = { addBadText = function() end, addGoodText = function() end }
function getText(k) return k end
DanTraitsRegistry = {}
ISEatFoodAction = { complete = function() return true end, eat = function() end, isValid = function() return true end, isValidStart = function() return true end }
ISTakePillAction = { complete = function() return true end }
local nextRoll = 0.99
function ZombRandFloat(lo, hi) if lo == 0 and hi == 1 then return nextRoll end return (lo + hi) / 2 end
local fainted = {}
function DanTraits_PassOut(p, minutes, key) fainted[#fainted + 1] = { p = p, minutes = minutes, key = key } return true end
local done = {}
local function action(name, duration)
  local c = { complete = function(self) done[#done + 1] = name return true end, getDuration = function() return duration or 100 end }
  return c
end
ISApplyBandage, ISStitch, ISRemoveGlass, ISRemoveBullet, ISCleanBurn, ISDisinfect = action("bandage"), action("stitch"), action("glass"), action("bullet"), action("burn"), action("disinfect")
ISPlantainCataplasm, ISComfreyCataplasm, ISGarlicCataplasm = action("plantain"), action("comfrey"), action("garlic")
ISSplint = { new = function(self, character) return { maxTime = 140, character = character } end }

function require() end
for _, f in ipairs({ "DanTraits", "DanTraits_Hemophobia" }) do
  assert(loadfile("../DanTraits/42/media/lua/shared/" .. f .. ".lua"))()
end

local function makePlayer(afraid)
  local md = {}
  local known = afraid and { "base:hemophobic" } or {}
  return { _md = md, getModData = function() return md end, isDead = function() return false end, isAsleep = function() return false end,
    getCharacterTraits = function() return { getKnownTraits = function() return { size = function() return #known end, get = function(_, i) return known[i + 1] end } end } end }
end
local current
function getSpecificPlayer() return current end
local minute = handlers.EveryOneMinute
local function part(bleed) return { getBleedingTime = function() return bleed end } end

-- 1. stitching: 25%; the action still completes first
local p = makePlayer(true); current = p
nextRoll = 0.24; ISStitch.complete({ character = p, bodyPart = part(0), doIt = true })
assert(done[#done] == "stitch" and #fainted == 1 and fainted[1].minutes == 1 and fainted[1].key == "UI_DanTraits_FaintBlood", "stitched, then fainted")

-- 2. not again for ten minutes
nextRoll = 0; ISRemoveBullet.complete({ character = p, bodyPart = part(0), doIt = true }); assert(#fainted == 1, "too soon")
for _ = 1, 10 do minute() end
ISRemoveBullet.complete({ character = p, bodyPart = part(0), doIt = true }); assert(#fainted == 2, "ten minutes on: can again")

-- 3. dressings only on a bleeding wound; removing never; by chance
p = makePlayer(true); current = p
nextRoll = 0.05; ISApplyBandage.complete({ character = p, bodyPart = part(0), doIt = true }); assert(#fainted == 2, "a dry wound: no")
ISApplyBandage.complete({ character = p, bodyPart = part(3), doIt = false }); assert(#fainted == 2, "taking a bandage off: no")
ISApplyBandage.complete({ character = p, bodyPart = part(3), doIt = true }); assert(#fainted == 3, "bandaging a bleed, 5% under 10%: fainted")
p = makePlayer(true); current = p
nextRoll = 0.21; ISRemoveGlass.complete({ character = p, bodyPart = part(0), doIt = true }); assert(#fainted == 3, "glass: 21% misses 20%")

-- 4. without the trait: nothing, and no slowdown
local calm = makePlayer(false); current = calm
nextRoll = 0; ISRemoveBullet.complete({ character = calm, bodyPart = part(0), doIt = true }); assert(#fainted == 3, "not afraid: no faint")
assert(ISStitch.getDuration({ character = calm }) == 100, "not afraid: normal speed")

-- 5. slower first aid, and the splint
p = makePlayer(true)
assert(ISStitch.getDuration({ character = p }) == 125 and ISDisinfect.getDuration({ character = p }) == 125, "a quarter longer")
assert(ISSplint:new(p).maxTime == 175 and ISSplint:new(calm).maxTime == 140, "splint: longer for the afraid only")

-- 6. losing blood fast: 3% a minute from 0.3% a minute
p = makePlayer(true); current = p; p._md.DanTraits = { bloodLossMin = 0.002 }
nextRoll = 0; minute(); assert(#fainted == 3, "a slow bleed: no")
p._md.DanTraits.bloodLossMin = 0.004; nextRoll = 0.04; minute(); assert(#fainted == 3, "4% misses 3%")
nextRoll = 0.02; minute(); assert(#fainted == 4, "fast bleed: fainted")

-- 7. wrapping again changes nothing
handlers.OnGameStart(); assert(ISStitch.getDuration({ character = p }) == 125, "not wrapped twice")

print("test_hemophobia: all passed")

-- Offline test for DanTraits_Hemophobia.lua: fainting when first aid is
-- done (by action, only on a bleeding wound for dressings, not when
-- removing), a gap before the next faint, slower first aid, the splint,
-- fainting from fast blood loss, and nothing for anyone without the trait.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
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

H.load("Hemophobia")

local function newPlayer(afraid) return H.player({ vanilla = afraid and { "base:hemophobic" } or {} }) end
local minute = H.minute
local function part(bleed) return { getBleedingTime = function() return bleed end } end

-- 1. stitching: 25%; the action still completes first
local p = newPlayer(true); H.current = p
H.rollf = 0.24; ISStitch.complete({ character = p, bodyPart = part(0), doIt = true })
assert(done[#done] == "stitch" and #fainted == 1 and fainted[1].minutes == 1 and fainted[1].key == "UI_DanTraits_FaintBlood", "stitched, then fainted")

-- 2. not again for ten minutes
H.rollf = 0; ISRemoveBullet.complete({ character = p, bodyPart = part(0), doIt = true }); assert(#fainted == 1, "too soon")
for _ = 1, 10 do minute() end
ISRemoveBullet.complete({ character = p, bodyPart = part(0), doIt = true }); assert(#fainted == 2, "ten minutes on: can again")

-- 3. dressings only on a bleeding wound; removing never; by chance
p = newPlayer(true); H.current = p
H.rollf = 0.05; ISApplyBandage.complete({ character = p, bodyPart = part(0), doIt = true }); assert(#fainted == 2, "a dry wound: no")
ISApplyBandage.complete({ character = p, bodyPart = part(3), doIt = false }); assert(#fainted == 2, "taking a bandage off: no")
ISApplyBandage.complete({ character = p, bodyPart = part(3), doIt = true }); assert(#fainted == 3, "bandaging a bleed, 5% under 10%: fainted")
p = newPlayer(true); H.current = p
H.rollf = 0.21; ISRemoveGlass.complete({ character = p, bodyPart = part(0), doIt = true }); assert(#fainted == 3, "glass: 21% misses 20%")

-- 4. without the trait: nothing, and no slowdown
local calm = newPlayer(false); H.current = calm
H.rollf = 0; ISRemoveBullet.complete({ character = calm, bodyPart = part(0), doIt = true }); assert(#fainted == 3, "not afraid: no faint")
assert(ISStitch.getDuration({ character = calm }) == 100, "not afraid: normal speed")

-- 5. slower first aid, and the splint
p = newPlayer(true)
assert(ISStitch.getDuration({ character = p }) == 125 and ISDisinfect.getDuration({ character = p }) == 125, "a quarter longer")
assert(ISSplint:new(p).maxTime == 175 and ISSplint:new(calm).maxTime == 140, "splint: longer for the afraid only")

-- 6. losing blood fast: 3% a minute from 0.3% a minute
p = newPlayer(true); H.current = p; p._md.DanTraits = { bloodLossMin = 0.002 }
H.rollf = 0; minute(); assert(#fainted == 3, "a slow bleed: no")
p._md.DanTraits.bloodLossMin = 0.004; H.rollf = 0.04; minute(); assert(#fainted == 3, "4% misses 3%")
H.rollf = 0.02; minute(); assert(#fainted == 4, "fast bleed: fainted")

-- 7. wrapping again changes nothing
H.fire("OnGameStart"); assert(ISStitch.getDuration({ character = p }) == 125, "not wrapped twice")

-- 8. end to end with the real DanTraits_Faint.lua (the sections above stub PassOut): Fear of Blood
-- after a stitch passes out, and comes round only after the real-time floor (H.now advanced) and the game minute
local faded
UIManager = { FadeOut = function() faded = true end, FadeIn = function() faded = false end }
H.load("Faint")
local tick = H.on("OnTick")
p = newPlayer(true); H.current = p
p.setBlockMovement = function(_, b) p._blocked = b end
p.setIgnoreMovement = function() end
p.setAuthorizeMeleeAction = function() end
p.setAuthorizeShoveStomp = function() end
p.isSitOnGround = function() return p._sitting == true end
p.reportEvent = function(_, e) if e == "EventSitOnGround" then p._sitting = true end end
local halo = H.halo
H.clearHalo(); H.now = 500000; H.hours = 900
H.rollf = 0.24; ISStitch.complete({ character = p, bodyPart = part(0), doIt = true })
assert(DanTraits_IsPassedOut(p), "stitched: passed out for real")
assert(p._bump == "stagger" and p._blocked and faded == true, "fell, held, screen black")
-- the game minute is up almost at once (HB_FAINT_MIN is 1), but the real-time floor (8 s) is not
H.hours = H.hours + 2 / 60; H.now = H.now + 7000; tick()
assert(DanTraits_IsPassedOut(p) and p._blocked, "8 real seconds have not passed: still out")
H.now = H.now + 1500; tick()
assert(not DanTraits_IsPassedOut(p) and not p._blocked and faded == false, "then comes round")
assert(halo[#halo] == "UI_DanTraits_FaintBlood", "the notice is the faint's own text key, got " .. tostring(halo[#halo]))

H.pass()

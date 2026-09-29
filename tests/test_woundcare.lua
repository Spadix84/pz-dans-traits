-- Offline test for DanTraits_WoundCare.lua: dressings wear out (time, wet,
-- blood through them) and say so once; unstitched deep wounds heal slowly
-- and can open again; fresh stitches tear under strain (legs by the
-- minute, arms by the swing), sound ones hold; the splint roll and a bad
-- set; walking on a broken leg; the sandbox switch; commands.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
BodyPartType.getDisplayName = function(t) return "the " .. t end
local stories = {}
function triggerEvent(name, pl, ev) if name == "OnStoryEvent" then stories[#stories + 1] = ev end end
local splintCompleted = 0
ISSplint = { complete = function(self) splintCompleted = splintCompleted + 1; self.bodyPart._splint = true; self.bodyPart._factor = (self.doctorLevel + 1) / 2 end }

H.load("WoundCare")
H.expectHooks("OnWeaponSwing")
H.expectEvery("minute", "WoundCare")
H.expectEvery("frame", "WoundCare")

local function makePart(name)
  local p = { _name = name, _bandaged = false, _life = 0, _stitch = 0, _stitched = false, _deep = 0, _deepWounded = false,
    _bleed = 0, _bleeding = false, _fracture = 0, _splint = false, _factor = 0, _pain = 0 }
  function p:getType() return self._name end
  function p:bandaged() return self._bandaged end
  function p:getBandageLife() return self._life end
  function p:setBandageLife(v) self._life = v end
  function p:getStitchTime() return self._stitch end
  function p:setStitchTime(v) self._stitch = v end
  function p:setStitched(b) if not b and self._stitched then self._stitched = false; self._deep = 7; self._bleed = 7 end end
  function p:getDeepWoundTime() return self._deep end
  function p:setDeepWoundTime(v) self._deep = v end
  function p:setDeepWounded(b) self._deepWounded = b end
  function p:getBleedingTime() return self._bleed end
  function p:setBleedingTime(v) self._bleed = v end
  function p:setBleeding(b) self._bleeding = b end
  function p:getFractureTime() return self._fracture end
  function p:setFractureTime(v) self._fracture = v end
  function p:isSplint() return self._splint end
  function p:getSplintFactor() return self._factor end
  function p:setSplintFactor(v) self._factor = v end
  function p:getAdditionalPain() return self._pain end
  function p:setAdditionalPain(v) self._pain = v end
  return p
end
local NAMES = { "Hand_R", "ForeArm_R", "ForeArm_L", "Torso_Upper", "UpperLeg_L", "LowerLeg_L" }
local newPlayer = H.factory(nil, function(p)
  for i, n in ipairs(NAMES) do p._parts[i] = makePart(n) end
end)
local halo, near, mins = H.halo, H.near, H.mins
local minute, frame, swing = H.minute, H.frame, H.on("OnWeaponSwing")
local function D(p) return p._md.DanTraits end
local function part(p, n) for _, x in ipairs(p._parts) do if x._name == n then return x end end end

-- 1. dressings: 0.2 life an hour dry, x3 soaking wet, plus blood through them; one notice when spent
local p = newPlayer(); H.current = p
local arm = part(p, "ForeArm_L"); arm._bandaged, arm._life = true, 5
mins(60); near(arm._life, 4.8, 1e-9, "an hour, dry")
p._st.wetness = 100; mins(60); near(arm._life, 4.2, 1e-9, "an hour, soaked: x3"); p._st.wetness = 0
DanTraits_BloodPartRate = function(x) if x == arm then return 0.001 end end   -- 0.1% a minute through it
minute(); near(arm._life, 4.2 - 0.2 / 60 - 0.1 * 1.5, 1e-9, "blood through it: 1.5 life per 1%")
DanTraits_BloodPartRate = nil
DanTraits_ExtraCommands.dressing(p, { "forearm_l", "0.001" }); H.clearHalo(); minute(); assert(arm._life == 0 and halo[1] == "UI_DanTraits_DressingSpent:the ForeArm_L", "spent, said once")
minute(); assert(#halo == 1, "not again")
arm._life = 3; minute(); near(arm._life, 3 - 0.2 / 60, 1e-9, "a new bandage: its own life")
arm._life = 1; minute(); near(arm._life, 3 - 0.4 / 60, 1e-9, "vanilla's drain in between is put back")
DanTraits_ExtraCommands.dressing(p, { "forearm_l", "0.001" }); minute(); assert(arm._life == 0 and #halo == 2, "spent: said again for the new bandage")
assert(string.find(D(p).wcSummary, "ForeArm_L dressing 0", 1, true), "summary: " .. D(p).wcSummary)

-- 2. unstitched deep wounds heal at 35%
p = newPlayer(); H.current = p; arm = part(p, "ForeArm_L")
arm._deep = 10; minute(); arm._deep = 9; minute()
near(arm._deep, 10 - 0.35, 1e-9, "a point of healing becomes 0.35")
arm._stitch = 5; arm._deep = 0; minute(); assert(D(p).wcParts.ForeArm_L == nil, "stitched: nothing held")

-- 3. strain on an unstitched deep wound that has stopped bleeding: it can open again
p = newPlayer(); H.current = p
local rf = part(p, "ForeArm_R"); rf._deep, rf._bleed = 8, 0
H.rollf = 0.5; swing(p, {}); assert(rf._bleed == 0, "a lucky swing")
H.rollf = 0.005; swing(p, {}); assert(rf._bleed == 4.5 and rf._bleeding, "1%: opened, bleeding")
assert(halo[#halo] == "UI_DanTraits_WoundOpened:the ForeArm_R", "notice")
local lf = part(p, "ForeArm_L"); lf._deep, lf._bleed = 8, 0
H.rollf = 0.005; swing(p, { isTwoHandWeapon = function() return false end }); assert(lf._bleed == 0, "one-handed: the left arm is spared")
swing(p, { isTwoHandWeapon = function() return true end }); assert(lf._bleed == 4.5, "two-handed: both arms")
H.rollf = 0.99

-- 4. stitches: fresh ones tear, sound ones hold; bandaged ones have the times set directly
p = newPlayer(); H.current = p; rf = part(p, "ForeArm_R")
rf._stitch, rf._stitched = 4, true   -- 10% strong: 2% x 0.9 = 1.8% a swing
H.rollf = 0.017; swing(p, {}); assert(rf._stitch == 0 and rf._deep == 7.5 and rf._bleed == 4.5 and rf._deepWounded and rf._bleeding, "torn: open and bleeding")
assert(halo[#halo] == "UI_DanTraits_StitchesTore:the ForeArm_R", "notice")
assert(stories[#stories].kind == "StitchesTore" and stories[#stories].text == "UI_DanTraits_StitchesTore:the ForeArm_R" and stories[#stories].tone == "bad", "the tear reaches the story event")
rf._stitch, rf._stitched, rf._deep, rf._bleed = 40, true, 0, 0
H.rollf = 0; swing(p, {}); assert(rf._stitch == 40, "sound stitches hold")
rf._stitch, rf._stitched, rf._bandaged, rf._bleeding = 4, false, true, false
H.rollf = 0.0125; swing(p, {}); assert(rf._stitch == 0 and rf._deep == 7.5 and not rf._bleeding, "under a bandage: times only, 1.8% x 0.7")
H.rollf = 0.99

-- 5. legs: a minute sprinting on stitched legs; running a third as likely; walking nothing
p = newPlayer(); H.current = p
local thigh = part(p, "UpperLeg_L"); thigh._stitch, thigh._stitched = 0.4, true   -- 1% strong
p._sprint = true; frame(p); H.rollf = 0.049; minute(); p._sprint = false
assert(thigh._stitch == 0, "sprinting: torn at 5%")
thigh._stitch, thigh._stitched = 0.4, true
p._run = true; frame(p); H.rollf = 0.02; minute(); p._run = false
assert(thigh._stitch == 0.4, "running: a third, 1.65% - held")
p._moving = true; frame(p); H.rollf = 0; minute(); p._moving = false
assert(thigh._stitch == 0.4, "walking: no strain")
H.rollf = 0.99

-- 6. the splint roll: level 0 half the time, less by level, never under 2%
near(DanTraits_BadSetChance(0), 0.5, 1e-12, "level 0")
near(DanTraits_BadSetChance(5), 0.2, 1e-12, "level 5")
near(DanTraits_BadSetChance(10), 0.02, 1e-12, "level 10: the floor")
p = newPlayer(); H.current = p
local shin = part(p, "LowerLeg_L"); shin._fracture = 30
H.clearHalo(); H.rollf = 0.3; ISSplint.complete({ doIt = true, bodyPart = shin, doctorLevel = 0, character = p })
assert(splintCompleted == 1 and shin._splint, "vanilla's splint went on")
near(shin._factor, 0.25, 1e-12, "set badly: half the splint factor")
assert(#halo == 0, "level 0 can't tell: no notice at all")
minute(); assert(shin._pain == 15, "a bad set hurts")
assert(string.find(D(p).wcSummary, "(set badly)", 1, true), "summary shows it")
local good = makePart("LowerLeg_R"); good._fracture = 30
H.rollf = 0.3; ISSplint.complete({ doIt = true, bodyPart = good, doctorLevel = 5, character = p })
near(good._factor, 3, 1e-12, "level 5, roll 0.3 over 0.2: set well")
local felt = makePart("UpperLeg_R"); felt._fracture = 30
H.rollf = 0; H.clearHalo(); ISSplint.complete({ doIt = true, bodyPart = felt, doctorLevel = 4, character = p })
assert(halo[1] == "UI_DanTraits_BadSet:the UpperLeg_R", "level 3+ can tell it's wrong")
H.rollf = 0.99

-- 7. walking on a broken leg, no splint
p = newPlayer(); H.current = p; shin = part(p, "LowerLeg_L"); shin._fracture = 30
p._moving = true; frame(p); minute(); near(shin._fracture, 30 + 1 / 60, 1e-9, "walking: worse")
p._run = true; frame(p); minute(); near(shin._fracture, 30 + 2 / 60, 1e-9, "'running' (the key held, limping): the same")
p._run, p._moving = false, false; minute(); near(shin._fracture, 30 + 2 / 60, 1e-9, "still: no change")
shin._splint = true; p._moving = true; frame(p); minute(); near(shin._fracture, 30 + 2 / 60, 1e-9, "splinted: no change")

-- 8. the sandbox switch
SandboxVars = { DanTraits = { WoundCareEnabled = false } }
p = newPlayer(); H.current = p; arm = part(p, "ForeArm_L"); arm._bandaged, arm._life = true, 5
minute(); assert(arm._life == 5, "off: nothing wears")
SandboxVars = nil

-- 9. commands
p = newPlayer(); H.current = p
part(p, "ForeArm_L")._stitch = 5; part(p, "ForeArm_L")._stitched = true
assert(DanTraits_ExtraCommands.tear(p, { "forearm_l" }) == "tore ForeArm_L" and part(p, "ForeArm_L")._stitch == 0, "tear")
assert(DanTraits_ExtraCommands.dressing(p, { "forearm_l", "0.5" }) == "bandage life 0.5", "dressing")
assert(DanTraits_ExtraCommands.badset(p, { "shin_l" }) == "badly set LowerLeg_L" and D(p).wcParts.LowerLeg_L.badSet, "badset")
assert(DanTraits_ExtraCommands.tear(p, { "tail" }) == "tear <part>", "usage")
assert(string.find(DanTraits_ExtraCommands.breakbone(p, { "shin_l" }), "^broke LowerLeg_L") and part(p, "LowerLeg_L")._fracture == 50, "breakbone")

-- 13. Vitality's reach: an unstitched deep wound heals x (1 + 0.25 e), never past full speed
H.load("Vitality")   -- loaded last: it runs for everyone. Its effect is stubbed to +1 / -1 from here.
local vitE = 0
DanTraits_VitalityEffect = function() return vitE end
for _, case in ipairs({ { 1, 0.4375 }, { -1, 0.2625 }, { 0, 0.35 } }) do
  vitE = case[1]
  p = newPlayer(); H.current = p; arm = part(p, "ForeArm_L")
  arm._deep = 10; minute(); arm._deep = 9; minute()
  near(arm._deep, 10 - case[2], 1e-9, "a point of healing becomes " .. case[2] .. " at e = " .. case[1])
end

H.pass()

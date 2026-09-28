-- Offline test for DanTraits_WoundCare.lua: dressings wear out (time, wet,
-- blood through them) and say so once; unstitched deep wounds heal slowly
-- and can open again; fresh stitches tear under strain (legs by the
-- minute, arms by the swing), sound ones hold; the splint roll and a bad
-- set; walking on a broken leg; the sandbox switch; commands.
local handlers, lists = {}, {}
Events = setmetatable({}, { __index = function(t, k) local e = { Add = function(f) lists[k] = lists[k] or {}; table.insert(lists[k], f); handlers[k] = function(...) for _, g in ipairs(lists[k]) do g(...) end end end, Remove = function() end }; rawset(t, k, e); return e end })
CharacterStat = { WETNESS = { getMaximumValue = function() return 1 end, name = "wetness" } }
local halo = {}
HaloTextHelper = { addBadText = function(_, t) halo[#halo+1] = t end, addGoodText = function(_, t) halo[#halo+1] = "+" .. t end }
function getText(k, a) return a and (k .. ":" .. a) or k end
DanTraitsRegistry = {}
ISEatFoodAction = { complete = function() return true end, eat = function() end, isValid = function() return true end, isValidStart = function() return true end }
ISTakePillAction = { complete = function() return true end }
local nextRoll = 0.99
function ZombRandFloat(lo, hi) if lo == 0 and hi == 1 then return nextRoll end return (lo + hi) / 2 end
BodyPartType = { getDisplayName = function(t) return "the " .. t end }
local splintCompleted = 0
ISSplint = { complete = function(self) splintCompleted = splintCompleted + 1; self.bodyPart._splint = true; self.bodyPart._factor = (self.doctorLevel + 1) / 2 end }

function require() end
for _, f in ipairs({ "DanTraits", "DanTraits_WoundCare" }) do
  assert(loadfile("../DanTraits/42/media/lua/shared/" .. f .. ".lua"))()
end
assert(handlers.EveryOneMinute and handlers.OnPlayerUpdate and handlers.OnWeaponSwing, "hooks in place")

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
local function makePlayer()
  local md = {}
  local parts = {}
  for i, n in ipairs(NAMES) do parts[i] = makePart(n) end
  local p = { _md = md, _parts = parts, _wet = 0, _sprint = false, _run = false, _moving = false,
    getModData = function() return md end, isDead = function() return false end }
  function p:isSprinting() return self._sprint end
  function p:isRunning() return self._run end
  function p:isPlayerMoving() return self._moving end
  function p:getStats() return { get = function(_, k) return p._wet end } end
  function p:getBodyDamage() return {
    getBodyParts = function() return { size = function() return #parts end, get = function(_, i) return parts[i + 1] end } end,
    getBodyPart = function(_, t) for _, x in ipairs(parts) do if x._name == t then return x end end end,
  } end
  return p
end
BodyPartType.ForeArm_L, BodyPartType.UpperLeg_L, BodyPartType.LowerLeg_L = "ForeArm_L", "UpperLeg_L", "LowerLeg_L"
local current
function getSpecificPlayer() return current end
local minute, frame, swing = handlers.EveryOneMinute, handlers.OnPlayerUpdate, handlers.OnWeaponSwing
local function D(p) return p._md.DanTraits end
local function near(a, b, tol, msg) assert(math.abs(a - b) <= tol, msg .. ": " .. tostring(a) .. " vs " .. tostring(b)) end
local function mins(n) for _ = 1, n do minute() end end
local function part(p, n) for _, x in ipairs(p._parts) do if x._name == n then return x end end end

-- 1. dressings: 0.2 life an hour dry, x3 soaking wet, plus blood through them; one notice when spent
local p = makePlayer(); current = p
local arm = part(p, "ForeArm_L"); arm._bandaged, arm._life = true, 5
mins(60); near(arm._life, 4.8, 1e-9, "an hour, dry")
p._wet = 1; mins(60); near(arm._life, 4.2, 1e-9, "an hour, soaked: x3"); p._wet = 0
DanTraits_BloodPartRate = function(x) if x == arm then return 0.001 end end   -- 0.1% a minute through it
minute(); near(arm._life, 4.2 - 0.2 / 60 - 0.1 * 1.5, 1e-9, "blood through it: 1.5 life per 1%")
DanTraits_BloodPartRate = nil
DanTraits_ExtraCommands.dressing(p, { "forearm_l", "0.001" }); halo = {}; minute(); assert(arm._life == 0 and halo[1] == "UI_DanTraits_DressingSpent:the ForeArm_L", "spent, said once")
minute(); assert(#halo == 1, "not again")
arm._life = 3; minute(); near(arm._life, 3 - 0.2 / 60, 1e-9, "a new bandage: its own life")
arm._life = 1; minute(); near(arm._life, 3 - 0.4 / 60, 1e-9, "vanilla's drain in between is put back")
DanTraits_ExtraCommands.dressing(p, { "forearm_l", "0.001" }); minute(); assert(arm._life == 0 and #halo == 2, "spent: said again for the new bandage")
assert(string.find(D(p).wcSummary, "ForeArm_L dressing 0", 1, true), "summary: " .. D(p).wcSummary)

-- 2. unstitched deep wounds heal at 35%
p = makePlayer(); current = p; arm = part(p, "ForeArm_L")
arm._deep = 10; minute(); arm._deep = 9; minute()
near(arm._deep, 10 - 0.35, 1e-9, "a point of healing becomes 0.35")
arm._stitch = 5; arm._deep = 0; minute(); assert(D(p).wcParts.ForeArm_L == nil, "stitched: nothing held")

-- 3. strain on an unstitched deep wound that has stopped bleeding: it can open again
p = makePlayer(); current = p
local rf = part(p, "ForeArm_R"); rf._deep, rf._bleed = 8, 0
nextRoll = 0.5; swing(p, {}); assert(rf._bleed == 0, "a lucky swing")
nextRoll = 0.005; swing(p, {}); assert(rf._bleed == 4.5 and rf._bleeding, "1%: opened, bleeding")
assert(halo[#halo] == "UI_DanTraits_WoundOpened:the ForeArm_R", "notice")
local lf = part(p, "ForeArm_L"); lf._deep, lf._bleed = 8, 0
nextRoll = 0.005; swing(p, { isTwoHandWeapon = function() return false end }); assert(lf._bleed == 0, "one-handed: the left arm is spared")
swing(p, { isTwoHandWeapon = function() return true end }); assert(lf._bleed == 4.5, "two-handed: both arms")
nextRoll = 0.99

-- 4. stitches: fresh ones tear, sound ones hold; bandaged ones have the times set directly
p = makePlayer(); current = p; rf = part(p, "ForeArm_R")
rf._stitch, rf._stitched = 4, true   -- 10% strong: 2% x 0.9 = 1.8% a swing
nextRoll = 0.017; swing(p, {}); assert(rf._stitch == 0 and rf._deep == 7.5 and rf._bleed == 4.5 and rf._deepWounded and rf._bleeding, "torn: open and bleeding")
assert(halo[#halo] == "UI_DanTraits_StitchesTore:the ForeArm_R", "notice")
rf._stitch, rf._stitched, rf._deep, rf._bleed = 40, true, 0, 0
nextRoll = 0; swing(p, {}); assert(rf._stitch == 40, "sound stitches hold")
rf._stitch, rf._stitched, rf._bandaged, rf._bleeding = 4, false, true, false
nextRoll = 0.0125; swing(p, {}); assert(rf._stitch == 0 and rf._deep == 7.5 and not rf._bleeding, "under a bandage: times only, 1.8% x 0.7")
nextRoll = 0.99

-- 5. legs: a minute sprinting on stitched legs; running a third as likely; walking nothing
p = makePlayer(); current = p
local thigh = part(p, "UpperLeg_L"); thigh._stitch, thigh._stitched = 0.4, true   -- 1% strong
p._sprint = true; frame(p); nextRoll = 0.049; minute(); p._sprint = false
assert(thigh._stitch == 0, "sprinting: torn at 5%")
thigh._stitch, thigh._stitched = 0.4, true
p._run = true; frame(p); nextRoll = 0.02; minute(); p._run = false
assert(thigh._stitch == 0.4, "running: a third, 1.65% - held")
p._moving = true; frame(p); nextRoll = 0; minute(); p._moving = false
assert(thigh._stitch == 0.4, "walking: no strain")
nextRoll = 0.99

-- 6. the splint roll: level 0 half the time, less by level, never under 2%
near(DanTraits_BadSetChance(0), 0.5, 1e-12, "level 0")
near(DanTraits_BadSetChance(5), 0.2, 1e-12, "level 5")
near(DanTraits_BadSetChance(10), 0.02, 1e-12, "level 10: the floor")
p = makePlayer(); current = p
local shin = part(p, "LowerLeg_L"); shin._fracture = 30
nextRoll = 0.3; ISSplint.complete({ doIt = true, bodyPart = shin, doctorLevel = 0, character = p })
assert(splintCompleted == 1 and shin._splint, "vanilla's splint went on")
near(shin._factor, 0.25, 1e-12, "set badly: half the splint factor")
assert(#halo == 0 or halo[#halo] ~= "UI_DanTraits_BadSet:the LowerLeg_L", "level 0 can't tell")
minute(); assert(shin._pain == 15, "a bad set hurts")
assert(string.find(D(p).wcSummary, "(set badly)", 1, true), "summary shows it")
local good = makePart("LowerLeg_R"); good._fracture = 30
nextRoll = 0.3; ISSplint.complete({ doIt = true, bodyPart = good, doctorLevel = 5, character = p })
near(good._factor, 3, 1e-12, "level 5, roll 0.3 over 0.2: set well")
local felt = makePart("UpperLeg_R"); felt._fracture = 30
nextRoll = 0; halo = {}; ISSplint.complete({ doIt = true, bodyPart = felt, doctorLevel = 4, character = p })
assert(halo[1] == "UI_DanTraits_BadSet:the UpperLeg_R", "level 3+ can tell it's wrong")
nextRoll = 0.99

-- 7. walking on a broken leg, no splint
p = makePlayer(); current = p; shin = part(p, "LowerLeg_L"); shin._fracture = 30
p._moving = true; frame(p); minute(); near(shin._fracture, 30 + 1 / 60, 1e-9, "walking: worse")
p._run = true; frame(p); minute(); near(shin._fracture, 30 + 2 / 60, 1e-9, "'running' (the key held, limping): the same")
p._run, p._moving = false, false; minute(); near(shin._fracture, 30 + 2 / 60, 1e-9, "still: no change")
shin._splint = true; p._moving = true; frame(p); minute(); near(shin._fracture, 30 + 2 / 60, 1e-9, "splinted: no change")

-- 8. the sandbox switch
SandboxVars = { DanTraits = { WoundCareEnabled = false } }
p = makePlayer(); current = p; arm = part(p, "ForeArm_L"); arm._bandaged, arm._life = true, 5
minute(); assert(arm._life == 5, "off: nothing wears")
SandboxVars = nil

-- 9. commands
p = makePlayer(); current = p
part(p, "ForeArm_L")._stitch = 5; part(p, "ForeArm_L")._stitched = true
assert(DanTraits_ExtraCommands.tear(p, { "forearm_l" }) == "tore ForeArm_L" and part(p, "ForeArm_L")._stitch == 0, "tear")
assert(DanTraits_ExtraCommands.dressing(p, { "forearm_l", "0.5" }) == "bandage life 0.5", "dressing")
assert(DanTraits_ExtraCommands.badset(p, { "shin_l" }) == "badly set LowerLeg_L" and D(p).wcParts.LowerLeg_L.badSet, "badset")
assert(DanTraits_ExtraCommands.tear(p, { "tail" }) == "tear <part>", "usage")
assert(string.find(DanTraits_ExtraCommands.breakbone(p, { "shin_l" }), "^broke LowerLeg_L") and part(p, "LowerLeg_L")._fracture == 50, "breakbone")

print("test_woundcare: all passed")

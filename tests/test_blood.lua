-- Offline test for DanTraits_Blood.lua: vanilla's bleed health loss is
-- refunded exactly; bleeding drains volume by bleeding time, place and
-- dressing; tiers, notices, shock health loss and the frame effects;
-- volume refills with water, red cells with food and rest; Hemophilia and
-- Anaemic hook in; the sandbox switch turns it all off; the commands.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
-- body parts in game order, with made-up modifiers
local NAMES = { "Hand_L", "ForeArm_L", "UpperLeg_L", "Neck" }
local MODS = { [0] = 0.1, [1] = 0.2, [2] = 0.2, [3] = 0.7 }
BodyPartType = { getDamageModifyer = function(i) return MODS[i] end }
for _, n in ipairs(NAMES) do BodyPartType[n] = n end

H.load("Blood", "Hemophilia", "Anemia")
H.expectHooks("OnPlayerGetDamage")
H.expectEvery("minute", "Blood")
H.expectEvery("frame", "Blood")

local made = {}
local function makePart(name)
  local p = { _name = name, _health = 100, _bleeding = false, _time = 0, _bandaged = false, _stitched = false, _glass = false }
  function p:getType() return self._name end
  function p:getHealth() return self._health end
  function p:AddHealth(n) self._health = math.min(100, self._health + n) end
  function p:ReduceHealth(n) self._health = math.max(0, self._health - n) end
  function p:bleeding() return self._bleeding end
  function p:getBleedingTime() return self._time end
  function p:setBleedingTime(t) self._time = t end
  function p:setBleeding(b) self._bleeding = b end
  function p:bandaged() return self._bandaged end
  function p:stitched() return self._stitched end
  function p:haveGlass() return self._glass end
  p._life = 5
  function p:getBandageLife() return self._life end
  function p:haveBullet() return false end
  -- open-wound clocks, which the real Faint counts to notice a new wound
  function p:getScratchTime() return self._scratchT or 0 end
  function p:getCutTime() return 0 end
  function p:getBiteTime() return 0 end
  function p:getDeepWoundTime() return 0 end
  function p:IsBleedingStemmed() return false end
  function p:scratched() return false end
  function p:isCut() return false end
  function p:deepWounded() return false end
  function p:generateDeepShardWound() made[#made + 1] = "glass " .. self._name; self._bleeding, self._time, self._glass = true, 9, true end
  function p:generateDeepWound() made[#made + 1] = "deep " .. self._name; self._bleeding, self._time = true, 8 end
  function p:setCut() made[#made + 1] = "cut " .. self._name end
  function p:setScratched() made[#made + 1] = "scratch " .. self._name end
  return p
end

-- the four parts, and vanilla's health arithmetic: overall health is 100 less each part's loss x its modifier
local build = H.factory(nil, function(p)
  local parts = {}
  for i, n in ipairs(NAMES) do parts[i] = makePart(n) end
  p._parts = parts
  p._sprint = true
  local function overall() local h = 100; for i, part in ipairs(parts) do h = h - (100 - part._health) * MODS[i - 1] end; return h end
  p.overall = overall
  p.getBodyDamage = function() return {
    getBodyParts = function() return { size = function() return #parts end, get = function(_, i) return parts[i + 1] end } end,
    getBodyPart = function(_, t) for _, part in ipairs(parts) do if part._name == t then return part end end end,
    getOverallBodyHealth = function() return overall() end,
    -- vanilla: x / count / modifier off every part
    ReduceGeneralHealth = function(_, x) for i, part in ipairs(parts) do part:ReduceHealth(x / #parts / MODS[i - 1]) end end,
  } end
end)
local function newPlayer(traits) return build({ traits = traits }) end
local function part(p, name) for _, x in ipairs(p._parts) do if x._name == name then return x end end end

local halo, near, mins = H.halo, H.near, H.mins
local minute, damage, frame = H.minute, H.on("OnPlayerGetDamage"), H.frame
local function D(p) return p._md.DanTraits end

-- 1. the refund: vanilla's ReduceGeneralHealth then the report; every part ends where it was
local p = newPlayer(); H.current = p
p:getBodyDamage():ReduceGeneralHealth(0.6); damage(p, "BLEEDING", 0.6)
for _, x in ipairs(p._parts) do near(x._health, 100, 1e-9, "refund: " .. x._name) end
near(D(p).bloodRefunded, 0.6, 1e-9, "refunded total")
p:getBodyDamage():ReduceGeneralHealth(5); damage(p, "FALLDOWN", 5)
near(p.overall(), 95, 1e-9, "a fall is not refunded")
damage(newPlayer(), "BLEEDING", 1); near(D(p).bloodRefunded, 0.6, 1e-9, "someone else's bleed is not ours")

-- 2. a full character: nothing moves
p = newPlayer(); H.current = p
minute(); assert(D(p).bloodVol == 1 and D(p).bloodCells == 1 and D(p).bloodTier == 0 and D(p).bloodLossMin == 0, "healthy: steady")

-- 3. bleed rate: 0.8% a minute at bleeding time 10 on an arm, by place and dressing
local arm = part(p, "ForeArm_L"); arm._bleeding, arm._time = true, 10
minute(); near(D(p).bloodLossMin, 0.008, 1e-12, "arm, time 10, open")
near(D(p).bloodVol, 1 - 0.008 + 0.35 / 1440, 1e-9, "volume down, refill starts")
assert(D(p).bloodSources == "ForeArm_L 0.8%", "sources: " .. D(p).bloodSources)
arm._time = 5; minute(); near(D(p).bloodLossMin, 0.004, 1e-12, "half the bleeding time, half the rate")
-- vanilla's bandage clears the bleeding flag and keeps the time
arm._bandaged, arm._bleeding = true, false; minute(); near(D(p).bloodLossMin, 0.0004, 1e-12, "bandaged: a tenth, flag or no flag")
assert(string.find(D(p).bloodSources, "(bandaged)", 1, true), "shown as bandaged")
arm._life = 0; minute(); near(D(p).bloodLossMin, 0.002, 1e-12, "a spent, soaked bandage: only half"); arm._life = 5
arm._glass = true; minute(); near(D(p).bloodLossMin, 0.004 * 0.35, 1e-12, "a shard under the bandage bleeds through")
-- stitching zeroes the bleeding time
arm._stitched, arm._time = true, 0; minute(); assert(D(p).bloodLossMin == 0, "stitched: stopped")
arm._stitched, arm._glass, arm._bandaged, arm._bleeding, arm._time = false, false, false, true, 10
part(p, "Neck")._bleeding, part(p, "Neck")._time = true, 10
part(p, "Hand_L")._bleeding, part(p, "Hand_L")._time = true, 10
minute(); near(D(p).bloodLossMin, 0.008 * (1 + 3 + 0.7), 1e-12, "neck x3, hand x0.7, added up")

-- 4. tiers and notices on the way down
p = newPlayer(); H.current = p; H.clearHalo()
local leg = part(p, "UpperLeg_L"); leg._bleeding, leg._time = true, 10   -- 1.2% a minute
local seen = {}
for _ = 1, 60 do minute(); seen[D(p).bloodTier] = seen[D(p).bloodTier] or D(p).bloodVol end
assert(seen[1] and seen[2] and seen[3], "went through pale, light-headed and shock")
near(seen[1], 0.85, 0.013, "pale at 15% lost")
near(seen[2], 0.70, 0.013, "light-headed at 30%")
assert(halo[1] == "UI_DanTraits_BloodPale" and halo[2] == "UI_DanTraits_BloodDizzy" and halo[3] == "UI_DanTraits_BloodShock", "notices in order")

-- 5. shock takes health, more the deeper; past half, fast
p = newPlayer(); H.current = p
D(p) ; p._md.DanTraits = { bloodVol = 0.58, bloodCells = 0.58 }
local h = p.overall(); minute()
near(h - p.overall(), 0.5 + 2.5 * ((0.42 - 0.40) / 0.10), 0.02, "shock at 42% lost")
assert(D(p).bloodTier == 3 and p._st.panic >= 40, "shock: tier 3, panic floor 40")
D(p).bloodVol = 0.49; h = p.overall(); minute(); near(h - p.overall(), 10, 0.02, "past half: 10 a minute")
assert(D(p).bloodTier == 4, "bleeding out")

-- 5b. shock: fainting spells, 2% a minute (6% bleeding out), not again for half an hour
local fainted = {}
function DanTraits_PassOut(pl, minutes, key) fainted[#fainted + 1] = { minutes = minutes, key = key } return true end
H.rollf = 0.5
p = newPlayer(); H.current = p
p._md.DanTraits = { bloodVol = 0.58, bloodCells = 0.58 }
H.rollf = 0.03; minute(); assert(#fainted == 0, "shock: 3% roll misses 2%")
H.rollf = 0.01; minute(); assert(#fainted == 1 and fainted[1].minutes == 10 and fainted[1].key == "UI_DanTraits_BloodComeTo", "shock: out for 5-15 (the middle, 10)")
for _ = 1, 29 do minute() end; assert(#fainted == 1, "not again for half an hour")
minute(); assert(#fainted == 2, "then it can")
D(p).bloodVol = 0.54; D(p).bloodFaintGap = 0; H.rollf = 0.05; minute(); assert(#fainted == 3, "bleeding out: 6%")
local r = newPlayer(); H.current = r; r._md.DanTraits = { bloodVol = 0.65, bloodCells = 1 }
H.rollf = 0; minute(); assert(#fainted == 3, "light-headed: no fainting")
DanTraits_PassOut, ZombRandFloat = nil, nil

-- 6. frame effects: endurance recovers slower, capped in shock, no sprinting when light-headed
p = newPlayer(); H.current = p
p._md.DanTraits = { bloodVol = 0.65, bloodCells = 1 }; minute()   -- 35% lost: tier 2
assert(D(p).bloodTier == 2 and p._st.panic >= 20, "light-headed: panic floor 20")
p._st.endurance = 0.5; frame(p); p._st.endurance = 0.6; frame(p)
near(p._st.endurance, 0.55, 1e-9, "tier 2: half the endurance recovery")
assert(p._sprint == false and p._cantSprint == true, "no sprinting")
p._cantSprint = false; frame(p)
assert(p._cantSprint == false, "the moodle only on an attempt to sprint (no blinking icon)")
p._sprint = true; frame(p)
assert(p._sprint == false and p._cantSprint == true, "and again on the next attempt")
D(p).bloodVol = 0.58; minute(); p._st.endurance = 1; frame(p)
near(p._st.endurance, 0.3, 1e-9, "shock: endurance ceiling 0.3")
p._st.endurance = 0.2; p._asleep = true; p._st.panic = 0; minute(); p._asleep = false
assert(p._st.panic == 0, "no panic floor asleep")

-- 7. volume refills with water, and costs thirst; not when parched
p = newPlayer(); H.current = p
p._md.DanTraits = { bloodVol = 0.8, bloodCells = 1 }
mins(60); near(D(p).bloodVol, 0.8 + 0.35 / 24, 1e-6, "an hour well watered")
assert(p._st.thirst > 0.02, "thirstier")
p._st.thirst = 0.8; local v = D(p).bloodVol; minute(); assert(D(p).bloodVol == v, "parched: no refill")
p._st.thirst = 0.5; v = D(p).bloodVol; minute(); near(D(p).bloodVol - v, 0.35 / 1440 * 0.5, 1e-9, "half thirsty: half rate")

-- 8. red cells: slow, faster asleep, slower starving; weakness while short
p = newPlayer(); H.current = p
p._md.DanTraits = { bloodVol = 1, bloodCells = 0.7 }
minute(); near(D(p).bloodCells, 0.7 + 0.05 / 1440, 1e-9, "a minute fed and awake")
near(D(p).bloodWeak, 0.5, 1e-3, "70% cells: half weak")
local f = p._st.fatigue; minute(); assert(p._st.fatigue > f, "weak: tires sooner")
p._asleep = true; local c = D(p).bloodCells; minute(); near(D(p).bloodCells - c, 0.05 / 1440 * 1.5, 1e-9, "asleep: x1.5"); p._asleep = false
p._st.hunger = 0.8; c = D(p).bloodCells; minute(); near(D(p).bloodCells - c, 0.05 / 1440 * 0.25, 1e-9, "starving: a quarter")
p._st.hunger = 0; p._st.endurance = 0.5; frame(p); p._st.endurance = 0.6; frame(p)
near(p._st.endurance, 0.5 + 0.1 * (1 - 0.5 * D(p).bloodWeak), 1e-9, "weak: slower endurance recovery")
D(p).bloodCells = 0.95; minute(); assert(D(p).bloodWeak == 0, "95%: not weak")

-- 9. Hemophilia: open bleeds x1.5, a bandage only slows to a quarter; no extra health loss on top
p = newPlayer({ "hemophilia" }); H.current = p
arm = part(p, "ForeArm_L"); arm._bleeding, arm._time = true, 10
h = p.overall(); minute()
near(D(p).bloodLossMin, 0.012, 1e-12, "hemophilia open: x1.5")
near(p.overall(), h, 1e-9, "no flat health loss with the blood system on")
arm._bandaged, arm._bleeding = true, false; minute(); near(D(p).bloodLossMin, 0.002, 1e-12, "hemophilia bandaged: 0.8% x 0.25")

-- 10. Anaemic: rebuilds at half speed, less short of iron, and spends iron doing it
p = newPlayer({ "anemia" }); H.current = p
p._md.DanTraits = { bloodVol = 1, bloodCells = 0.7, anIron = 0.6 }
c = D(p).bloodCells; local iron = D(p).anIron; minute()
near(D(p).bloodCells - c, 0.05 / 1440 * 0.5, 1e-9, "anaemic, iron fine: half speed")
near(iron - D(p).anIron, 1 / (5 * 24 * 60) + 0.05 / 1440 * 0.5 * 2, 1e-9, "iron: the daily drain plus what the cells took")

-- 11. the sandbox switch
SandboxVars = { DanTraits = { BloodEnabled = false } }
p = newPlayer(); H.current = p
arm = part(p, "ForeArm_L"); arm._bleeding, arm._time = true, 10
p:getBodyDamage():ReduceGeneralHealth(1); damage(p, "BLEEDING", 1); minute()
near(p.overall(), 99, 1e-9, "off: vanilla keeps its bleed damage")
assert(D(p) == nil or D(p).bloodVol == nil, "off: no blood kept")
SandboxVars = nil

-- 12. commands and test wounds
p = newPlayer(); H.current = p
assert(DanTraits_ExtraCommands.blood(p, { "0.6" }) == "blood: volume 0.6, cells 0.6", "blood 0.6")
assert(string.find(DanTraits_BloodCommand(p, { "1", "0.7" }), "cells 0.7", 1, true), "cells set")
assert(DanTraits_BloodCommand(p, { "reset" }) == "blood: full" and D(p).bloodVol == 1, "reset")
assert(DanTraits_BloodCommand(p, { "debug", "on" }) == "blood debug on"); minute()
assert(D(p).bloodDbgParts ~= nil, "debug readout")
DanTraits_BloodCommand(p, { "debug", "off" }); assert(D(p).bloodDbgParts == nil, "debug off clears it")
assert(string.find(DanTraits_BloodCommand(p, { "lots" }), "^blood <volume"), "usage")
local r = DanTraits_ExtraCommands.wound(p, { "forearm_l", "glass" })
assert(made[#made] == "glass ForeArm_L" and string.find(r, "bleeding time 9", 1, true), r)
DanTraits_BloodTestWound(p, "NECK", "deep"); assert(made[#made] == "deep Neck", "neck, any case")
assert(string.find(DanTraits_BloodTestWound(p, "tail", "deep"), "part is one of", 1, true), "unknown part")

-- 13. end to end with the real DanTraits_Faint.lua (sections above stub PassOut): shock at tier 3 with a
-- seeded roll passes out, the tick holds movement, coming round by time, and a new wound wakes a faint
local faded
UIManager = { FadeOut = function() faded = true end, FadeIn = function() faded = false end }
function ZombRandFloat(lo, hi) if lo == 0 and hi == 1 then return H.rollf end return (lo + hi) / 2 end
H.load("Faint")
local tick = H.on("OnTick")
p = newPlayer(); H.current = p
p.setBlockMovement = function(_, b) p._blocked = b end
p.setIgnoreMovement = function() end
p.setAuthorizeMeleeAction = function() end
p.setAuthorizeShoveStomp = function() end
p.isSitOnGround = function() return p._sitting == true end
p.reportEvent = function(_, e) if e == "EventSitOnGround" then p._sitting = true end end
p._md.DanTraits = { bloodVol = 0.58, bloodCells = 0.58 }
H.clearHalo(); H.now = 100000; H.hours = 500
H.rollf = 0.5; minute(); assert(not DanTraits_IsPassedOut(p), "shock, roll 0.5: keeps his feet")
H.rollf = 0.01; minute()
assert(DanTraits_IsPassedOut(p), "shock at tier 3, roll under 2%: passed out")
assert(p._bump == "stagger" and p._blocked and faded == true, "fell, movement blocked, screen black")
p._blocked = false; tick(); assert(p._blocked, "the tick holds movement")
H.hours = H.hours + 9 / 60; H.now = H.now + 60000; tick(); assert(DanTraits_IsPassedOut(p), "10 game minutes: not yet")
H.hours = H.hours + 2 / 60; tick()
assert(not DanTraits_IsPassedOut(p) and not p._blocked and faded == false, "comes round on time")
assert(halo[#halo] == "UI_DanTraits_BloodComeTo", "and says so")
-- a faint is shallow: a new wound (a scratch here) brings you round at once
H.clearHalo()
assert(DanTraits_PassOut(p, 10, "UI_DanTraits_BloodComeTo"), "out again")
for _ = 1, 10 do tick() end; assert(DanTraits_IsPassedOut(p), "nothing new: still out")
-- the fall itself can scratch: while landing that does not wake you
part(p, "UpperLeg_L")._scratchT = 10
for _ = 1, 10 do tick() end; assert(DanTraits_IsPassedOut(p), "a scratch from the fall: still out")
H.now = H.now + 5000
part(p, "Hand_L")._scratchT = 5
for _ = 1, 10 do tick() end
assert(not DanTraits_IsPassedOut(p) and halo[#halo] == "UI_DanTraits_JoltedAwake", "a new wound wakes")
assert(not p._blocked and faded == false, "free again")
part(p, "Hand_L")._scratchT = nil
part(p, "UpperLeg_L")._scratchT = nil

H.pass()

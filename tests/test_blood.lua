-- Offline test for DanTraits_Blood.lua: vanilla's bleed health loss is
-- refunded exactly; bleeding drains volume by bleeding time, place and
-- dressing; tiers, notices, shock health loss and the frame effects;
-- volume refills with water, red cells with food and rest; Hemophilia and
-- Anaemic hook in; the sandbox switch turns it all off; the commands.
local handlers, lists = {}, {}
Events = setmetatable({}, { __index = function(t, k) local e = { Add = function(f) lists[k] = lists[k] or {}; table.insert(lists[k], f); handlers[k] = function(...) for _, g in ipairs(lists[k]) do g(...) end end end, Remove = function() end }; rawset(t, k, e); return e end })
local function statKey(name) return { name = name, getMaximumValue = function() return name == "panic" and 100 or 1 end } end
CharacterStat = { THIRST = statKey("thirst"), HUNGER = statKey("hunger"), PANIC = statKey("panic"), FATIGUE = statKey("fatigue"), ENDURANCE = statKey("endurance") }
local halo = {}
HaloTextHelper = { addBadText = function(_, t) halo[#halo+1] = t end, addGoodText = function(_, t) halo[#halo+1] = "+" .. t end }
function getText(k) return k end
DanTraitsRegistry = { hemophilia = "hemophilia", anemia = "anemia" }
ISEatFoodAction = { complete = function() return true end, eat = function() end, isValid = function() return true end, isValidStart = function() return true end }
ISTakePillAction = { complete = function() return true end }
-- body parts in game order, with made-up modifiers
local NAMES = { "Hand_L", "ForeArm_L", "UpperLeg_L", "Neck" }
local MODS = { [0] = 0.1, [1] = 0.2, [2] = 0.2, [3] = 0.7 }
BodyPartType = { getDamageModifyer = function(i) return MODS[i] end }
for _, n in ipairs(NAMES) do BodyPartType[n] = n end

function require() end
for _, f in ipairs({ "DanTraits", "DanTraits_Blood", "DanTraits_Hemophilia", "DanTraits_Anemia" }) do
  assert(loadfile("../DanTraits/42/media/lua/shared/" .. f .. ".lua"))()
end
assert(handlers.OnPlayerGetDamage and handlers.EveryOneMinute and handlers.OnPlayerUpdate, "hooks in place")

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

local function makePlayer(traits)
  local set = {}
  for _, t in ipairs(traits or {}) do set[t] = true end
  local md = {}
  local parts = {}
  for i, n in ipairs(NAMES) do parts[i] = makePart(n) end
  local st = { thirst = 0, hunger = 0, panic = 0, fatigue = 0, endurance = 1 }
  local p = { _md = md, _parts = parts, _st = st, _asleep = false, _sprint = true, _cantSprint = false,
    getModData = function() return md end, isDead = function() return false end,
    hasTrait = function(_, t) return set[t] == true end }
  function p:isAsleep() return self._asleep end
  function p:setSprinting(b) self._sprint = b end
  function p:setMoodleCantSprint(b) self._cantSprint = b end
  function p:getStats() return { get = function(_, k) return st[k.name] end, set = function(_, k, v) st[k.name] = v end } end
  local function overall() local h = 100; for i, part in ipairs(parts) do h = h - (100 - part._health) * MODS[i - 1] end; return h end
  p.overall = overall
  function p:getBodyDamage() return {
    getBodyParts = function() return { size = function() return #parts end, get = function(_, i) return parts[i + 1] end } end,
    getBodyPart = function(_, t) for _, part in ipairs(parts) do if part._name == t then return part end end end,
    getOverallBodyHealth = function() return overall() end,
    -- vanilla: x / count / modifier off every part
    ReduceGeneralHealth = function(_, x) for i, part in ipairs(parts) do part:ReduceHealth(x / #parts / MODS[i - 1]) end end,
  } end
  return p
end
local function part(p, name) for _, x in ipairs(p._parts) do if x._name == name then return x end end end

local current
function getSpecificPlayer() return current end
local minute, damage, frame = handlers.EveryOneMinute, handlers.OnPlayerGetDamage, handlers.OnPlayerUpdate
local function D(p) return p._md.DanTraits end
local function near(a, b, tol, msg) assert(math.abs(a - b) <= tol, msg .. ": " .. tostring(a) .. " vs " .. tostring(b)) end
local function mins(n) for _ = 1, n do minute() end end

-- 1. the refund: vanilla's ReduceGeneralHealth then the report; every part ends where it was
local p = makePlayer(); current = p
p:getBodyDamage():ReduceGeneralHealth(0.6); damage(p, "BLEEDING", 0.6)
for _, x in ipairs(p._parts) do near(x._health, 100, 1e-9, "refund: " .. x._name) end
near(D(p).bloodRefunded, 0.6, 1e-9, "refunded total")
p:getBodyDamage():ReduceGeneralHealth(5); damage(p, "FALLDOWN", 5)
near(p.overall(), 95, 1e-9, "a fall is not refunded")
damage(makePlayer(), "BLEEDING", 1); near(D(p).bloodRefunded, 0.6, 1e-9, "someone else's bleed is not ours")

-- 2. a full character: nothing moves
p = makePlayer(); current = p
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
p = makePlayer(); current = p; halo = {}
local leg = part(p, "UpperLeg_L"); leg._bleeding, leg._time = true, 10   -- 1.2% a minute
local seen = {}
for _ = 1, 60 do minute(); seen[D(p).bloodTier] = seen[D(p).bloodTier] or D(p).bloodVol end
assert(seen[1] and seen[2] and seen[3], "went through pale, light-headed and shock")
near(seen[1], 0.85, 0.013, "pale at 15% lost")
near(seen[2], 0.70, 0.013, "light-headed at 30%")
assert(halo[1] == "UI_DanTraits_BloodPale" and halo[2] == "UI_DanTraits_BloodDizzy" and halo[3] == "UI_DanTraits_BloodShock", "notices in order")

-- 5. shock takes health, more the deeper; past half, fast
p = makePlayer(); current = p
D(p) ; p._md.DanTraits = { bloodVol = 0.58, bloodCells = 0.58 }
local h = p.overall(); minute()
near(h - p.overall(), 0.5 + 2.5 * ((0.42 - 0.40) / 0.10), 0.02, "shock at 42% lost")
assert(D(p).bloodTier == 3 and p._st.panic >= 40, "shock: tier 3, panic floor 40")
D(p).bloodVol = 0.49; h = p.overall(); minute(); near(h - p.overall(), 10, 0.02, "past half: 10 a minute")
assert(D(p).bloodTier == 4, "bleeding out")

-- 6. frame effects: endurance recovers slower, capped in shock, no sprinting when light-headed
p = makePlayer(); current = p
p._md.DanTraits = { bloodVol = 0.65, bloodCells = 1 }; minute()   -- 35% lost: tier 2
assert(D(p).bloodTier == 2 and p._st.panic >= 20, "light-headed: panic floor 20")
p._st.endurance = 0.5; frame(p); p._st.endurance = 0.6; frame(p)
near(p._st.endurance, 0.55, 1e-9, "tier 2: half the endurance recovery")
assert(p._sprint == false and p._cantSprint == true, "no sprinting")
D(p).bloodVol = 0.58; minute(); p._st.endurance = 1; frame(p)
near(p._st.endurance, 0.3, 1e-9, "shock: endurance ceiling 0.3")
p._st.endurance = 0.2; p._asleep = true; p._st.panic = 0; minute(); p._asleep = false
assert(p._st.panic == 0, "no panic floor asleep")

-- 7. volume refills with water, and costs thirst; not when parched
p = makePlayer(); current = p
p._md.DanTraits = { bloodVol = 0.8, bloodCells = 1 }
mins(60); near(D(p).bloodVol, 0.8 + 0.35 / 24, 1e-6, "an hour well watered")
assert(p._st.thirst > 0.02, "thirstier")
p._st.thirst = 0.8; local v = D(p).bloodVol; minute(); assert(D(p).bloodVol == v, "parched: no refill")
p._st.thirst = 0.5; v = D(p).bloodVol; minute(); near(D(p).bloodVol - v, 0.35 / 1440 * 0.5, 1e-9, "half thirsty: half rate")

-- 8. red cells: slow, faster asleep, slower starving; weakness while short
p = makePlayer(); current = p
p._md.DanTraits = { bloodVol = 1, bloodCells = 0.7 }
minute(); near(D(p).bloodCells, 0.7 + 0.05 / 1440, 1e-9, "a minute fed and awake")
near(D(p).bloodWeak, 0.5, 1e-3, "70% cells: half weak")
local f = p._st.fatigue; minute(); assert(p._st.fatigue > f, "weak: tires sooner")
p._asleep = true; local c = D(p).bloodCells; minute(); near(D(p).bloodCells - c, 0.05 / 1440 * 1.5, 1e-9, "asleep: x1.5"); p._asleep = false
p._st.hunger = 0.8; c = D(p).bloodCells; minute(); near(D(p).bloodCells - c, 0.05 / 1440 * 0.25, 1e-9, "starving: a quarter")
p._st.hunger = 0; p._st.endurance = 0.5; frame(p); p._st.endurance = 0.6; frame(p)
near(p._st.endurance, 0.5 + 0.1 * (1 - 0.5 * D(p).bloodWeak), 1e-9, "weak: slower endurance recovery")
D(p).bloodCells = 0.95; minute(); assert(D(p).bloodWeak == 0, "95%: not weak")

-- 9. Hemophilia: open bleeds x1.5, a bandage only slows to two fifths; no extra health loss on top
p = makePlayer({ "hemophilia" }); current = p
arm = part(p, "ForeArm_L"); arm._bleeding, arm._time = true, 10
h = p.overall(); minute()
near(D(p).bloodLossMin, 0.012, 1e-12, "hemophilia open: x1.5")
near(p.overall(), h, 1e-9, "no flat health loss with the blood system on")
arm._bandaged, arm._bleeding = true, false; minute(); near(D(p).bloodLossMin, 0.0032, 1e-12, "hemophilia bandaged: 0.8% x 0.4")

-- 10. Anaemic: rebuilds at half speed, less short of iron, and spends iron doing it
p = makePlayer({ "anemia" }); current = p
p._md.DanTraits = { bloodVol = 1, bloodCells = 0.7, anIron = 0.6 }
c = D(p).bloodCells; local iron = D(p).anIron; minute()
near(D(p).bloodCells - c, 0.05 / 1440 * 0.5, 1e-9, "anaemic, iron fine: half speed")
near(iron - D(p).anIron, 1 / (5 * 24 * 60) + 0.05 / 1440 * 0.5 * 2, 1e-9, "iron: the daily drain plus what the cells took")

-- 11. the sandbox switch
SandboxVars = { DanTraits = { BloodEnabled = false } }
p = makePlayer(); current = p
arm = part(p, "ForeArm_L"); arm._bleeding, arm._time = true, 10
p:getBodyDamage():ReduceGeneralHealth(1); damage(p, "BLEEDING", 1); minute()
near(p.overall(), 99, 1e-9, "off: vanilla keeps its bleed damage")
assert(D(p) == nil or D(p).bloodVol == nil, "off: no blood kept")
SandboxVars = nil

-- 12. commands and test wounds
p = makePlayer(); current = p
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

print("test_blood: all passed")

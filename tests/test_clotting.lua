-- Offline test for DanTraits_Clotting.lua and its action: the powder only
-- goes on a bleeding part with no dressing; a scratch or cut stops, a deep
-- wound's bleeding time halves and it bleeds at a quarter while the clot
-- holds (through Blood's part rate, so a bandage over it soaks slower too);
-- a shard or bullet, or Hemophilia, weakens it and stops nothing; it stings
-- less with First Aid; clots wear off, end with the bleed, and break when
-- WoundCare tears the wound open. ISVitalityClotAction: valid only while it
-- can go on, complete() applies it, uses the tin and gives First Aid xp.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("Blood", "Hemophilia", "Clotting")
H.expectEvery("minute", "Clotting")

local function part(o)
  o = o or {}
  local p = { _type = o.type or "ForeArm_L", _time = o.time or 0, _bleeding = (o.time or 0) > 0, _bandaged = o.bandaged or false,
    _deepT = o.deep and 10 or 0, _glass = o.glass or false, _bullet = o.bullet or false, _pain = 0, _life = 5 }
  function p:getType() return self._type end
  function p:getBleedingTime() return self._time end
  function p:setBleedingTime(t) self._time = t end
  function p:bleeding() return self._bleeding end
  function p:setBleeding(b) self._bleeding = b end
  function p:bandaged() return self._bandaged end
  function p:getBandageLife() return self._life end
  function p:getDeepWoundTime() return self._deepT end
  function p:deepWounded() return self._deepT > 0 end
  function p:haveGlass() return self._glass end
  function p:haveBullet() return self._bullet end
  function p:getAdditionalPain() return self._pain end
  function p:setAdditionalPain(v) self._pain = v end
  function p:IsBleedingStemmed() return false end
  function p:stitched() return false end
  function p:scratched() return self._deepT == 0 end
  function p:isCut() return false end
  return p
end

local newPlayer = H.factory()
local near, halo = H.near, H.halo
local function D(p) return p._md.DanTraits end
local rate = DanTraits_BloodPartRate

-- 1. where it can go: bleeding, no dressing
assert(not DanTraits_ClotCanApply(part()), "not bleeding: no")
local ok, why = DanTraits_ClotCanApply(part({ time = 5 }))
assert(ok and why == nil, "bleeding, bare: yes")
ok, why = DanTraits_ClotCanApply(part({ time = 5, bandaged = true }))
assert(not ok and why == "bandaged", "under a dressing: no, and why")
assert(select(2, DanTraits_ClotCanApply(part())) == "notBleeding", "the reason when it isn't bleeding")

-- 2. a scratch: stops there and then, stings, nothing left to hold
local s = part({ time = 4 })
local p = newPlayer({ parts = { s } }); H.current = p
H.clearHalo()
assert(DanTraits_ApplyClot(p, s, 0), "applied")
assert(s._time == 0 and not s._bleeding, "a scratch stops bleeding")
assert(D(p).clot == nil or D(p).clot.ForeArm_L == nil, "nothing to hold on a stopped scratch")
assert(s._pain == 20, "stings: 20 at First Aid 0, got " .. s._pain)
assert(halo[1] == "+UI_DanTraits_ClotStopped:ForeArm_L", "the good notice, got " .. tostring(halo[1]))
assert(not DanTraits_ApplyClot(p, s, 0), "not bleeding any more: it does not go on again")

-- 3. a deep wound: bleeding time halved, a quarter of the blood while the clot holds
local w = part({ type = "UpperLeg_L", time = 10, deep = true })
p = newPlayer({ parts = { w } }); H.current = p
local before = rate(w, p)
H.clearHalo()
DanTraits_ApplyClot(p, w, 10)
assert(w._time == 5 and w._bleeding, "deep: bleeding time halved, still bleeding")
assert(D(p).clot.UpperLeg_L == 720, "the clot holds 12 hours")
assert(w._pain == 15, "First Aid 10 stings less: 20 - 5, got " .. w._pain)
assert(halo[1] == "+UI_DanTraits_ClotSlowed:UpperLeg_L", "slowed notice, got " .. tostring(halo[1]))
near(DanTraits_ClotFactor(p, w), 0.25, 1e-12, "a quarter")
near(rate(w, p), before * 0.5 * 0.25, 1e-12, "half the time, a quarter the rate")
near(rate(w), before * 0.5, 1e-12, "no player given: no clot (the old call)")
-- the unbandaged rate the hooks see is clotted too
local r, _, bandaged, open = rate(w, p)
assert(not bandaged and math.abs(open - r) < 1e-12, "open rate = rate, both clotted")
-- a bandage over it stacks
w._bandaged = true
near(rate(w, p), before * 0.5 * 0.25 * 0.1, 1e-12, "bandage over powder: a tenth of a quarter")
w._life = 0
near(rate(w, p), before * 0.5 * 0.25 * 0.5, 1e-12, "soaked bandage over powder: half of a quarter")
w._bandaged, w._life = false, 5
-- the blood system's minute reads it
H.minute()
near(D(p).bloodLossMin, before * 0.5 * 0.25, 1e-12, "a minute's loss with the clot")

-- 4. the clot wears off after 12 hours, ends with the bleed, breaks on a tear
H.mins(718)   -- the minute above was the first
assert(D(p).clot.UpperLeg_L == 1, "one minute left")
H.minute()
assert(D(p).clot.UpperLeg_L == nil, "worn off")
near(DanTraits_ClotFactor(p, w), 1, 0, "no clot: full rate")
DanTraits_ApplyClot(p, w, 0)
w._time = 0; H.minute()
assert(D(p).clot.UpperLeg_L == nil, "the bleed stopped: the clot is done")
w._time = 6; DanTraits_ApplyClot(p, w, 0)
assert(D(p).clot.UpperLeg_L, "packed again")
DanTraits_ClotBreak(p, w)
assert(D(p).clot.UpperLeg_L == nil, "torn open: the clot broke")

-- 5. a shard or bullet still in: the time stays, x0.6 only
local g = part({ time = 9, deep = true, glass = true })
p = newPlayer({ parts = { g } }); H.current = p
DanTraits_ApplyClot(p, g, 0)
assert(g._time == 9, "a shard: the bleeding time stays")
near(DanTraits_ClotFactor(p, g), 0.6, 1e-12, "a shard: x0.6")
local b = part({ type = "Torso_Upper", time = 4, bullet = true })
p = newPlayer({ parts = { b } }); H.current = p
DanTraits_ApplyClot(p, b, 0)
assert(b._time == 4 and b._bleeding, "a bullet: even a shallow wound doesn't stop")
near(DanTraits_ClotFactor(p, b), 0.6, 1e-12, "a bullet: x0.6")

-- 6. Hemophilia: nothing stops, the bleed only halves
local h = part({ time = 3 })
p = newPlayer({ traits = { "hemophilia" }, parts = { h } }); H.current = p
DanTraits_ApplyClot(p, h, 0)
assert(h._time == 3 and h._bleeding, "hemophiliac's scratch: not stopped")
near(DanTraits_ClotFactor(p, h), 0.5, 1e-12, "hemophilia: x0.5")
local hemoRate = rate(h, p)
near(hemoRate, 0.008 * 3 / 10 * 1 * 0.5, 1e-12, "the base rate, halved")
-- Hemophilia's own hook still adds its x1.5 on top
near(DanTraits_RunHooks("bloodBleed", hemoRate, p, h, false, hemoRate), hemoRate * 1.5, 1e-12, "Hemophilia's x1.5 still applies")

-- 7. the console
p = newPlayer({ parts = {} }); H.current = p
assert(DanTraits_ExtraCommands.clot(p, { "nowhere" }):find("^clot <part>"), "usage")
assert(DanTraits_ExtraCommands.clot(p, { "clear" }) == "clots cleared", "clear")

-- 8. the action -----------------------------------------------------------------
ISBaseTimedAction = {}
function ISBaseTimedAction:derive(name)
  local c = { Type = name }
  c.__index = c
  setmetatable(c, self)
  self.__index = self
  return c
end
function ISBaseTimedAction:new(character) return setmetatable({ character = character }, self) end
function ISBaseTimedAction:perform() self._performed = true end
function ISBaseTimedAction:stop() self._stopped = true end
ISHealthPanel = { DidPatientMove = function() return false end }
local xp = {}
function addXp(who, perk, n) xp[#xp + 1] = { who = who, perk = perk, n = n } end
BodyPartType.ToIndex = function() return 0 end
H.load("shared/TimedActions/ISVitalityClotAction.lua")

local function tin(uses)
  local it = { _uses = uses }
  -- as the game: a count of uses, and separately how full it is (0 to 1)
  function it:getCurrentUses() return math.floor(self._uses) end
  function it:getCurrentUsesFloat() return self._uses > 0 and math.min(1, self._uses / 40) or 0 end
  function it:IsDrainable() return true end
  function it:UseAndSync() self._uses = self._uses - 1 end
  return it
end
local function actor(level, has)
  local a = newPlayer()
  a.getPerkLevel = function() return level end
  a.isTimedActionInstant = function() return false end
  a.getX, a.getY = function() return 0 end, function() return 0 end
  a.getInventory = function() return { contains = function() return has end } end
  return a
end

local cut = part({ time = 5 })
cut.getIndex = function() return 0 end
local doc = actor(5, true)
local t = tin(5)
local act = ISVitalityClotAction:new(doc, doc, t, cut)
assert(act.maxTime == 80, "100 - 4 a level: 80 at First Aid 5, got " .. tostring(act.maxTime))
assert(act:isValid(), "valid: bleeding, bare, a tin with some left")
cut._bandaged = true; assert(not act:isValid(), "dressed: not valid"); cut._bandaged = false
t._uses = 0; assert(not act:isValid(), "empty tin: not valid"); t._uses = 5
assert(not ISVitalityClotAction:new(actor(0, false), doc, t, cut):isValid(), "no tin on them: not valid")
assert(act:complete() == true, "complete")
assert(cut._time == 0 and t._uses == 4, "the cut stopped, one use gone")
assert(#xp == 1 and xp[1].who == doc and xp[1].perk == "Doctor" and xp[1].n == 5, "5 First Aid xp")
assert(cut._pain == 17.5, "First Aid 5: 20 - 2.5, got " .. cut._pain)
-- nothing to do (stopped in the meantime): no use, no xp
act:complete()
assert(t._uses == 4 and #xp == 1, "not bleeding at complete: nothing used")

H.pass()

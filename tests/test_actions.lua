-- Offline test for the three timed actions (shared/TimedActions): ISDiabetesAction (inject uses n
-- doses and calls DanTraits_DiaInject; test uses a strip and renames the meter; pill calls
-- DanTraits_DiaOnPill), ISUseInhalerAction (calls DanTraits_UseInhaler) and ISVitalityPillAction
-- (fires the "pill" hook with the item type). isValid is false when the item is missing or empty.
-- ISBaseTimedAction is a stub that records stop and perform; the game's items are small fakes.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("DanTraits")

-- the base class: derive gives a class table whose new() builds instances of it
ISBaseTimedAction = {}
function ISBaseTimedAction:derive(name)
  local c = { Type = name }
  c.__index = c
  setmetatable(c, self)
  self.__index = self
  return c
end
function ISBaseTimedAction:new(character)
  local o = setmetatable({}, self)
  o.character = character
  return o
end
function ISBaseTimedAction:getJobDelta() return 0.5 end
function ISBaseTimedAction:perform() self._performed = (self._performed or 0) + 1 end
function ISBaseTimedAction:stop() self._stopped = (self._stopped or 0) + 1 end
function ISBaseTimedAction:setActionAnim(a) self._anim = a end
function ISBaseTimedAction:setOverrideHandModels(a, b) self._hands = b end
CharacterActionAnims = { TakePills = "TakePills", Bandage = "Bandage" }

-- what the trait files would provide
local seen = {}
DanTraits_IsInsulin = function(item) return item._type == "Insulin" end
DanTraits_IsMeter = function(item) return item._type == "GlucoseMeter" end
DanTraits_IsMetformin = function(item) return item._type == "Metformin" end
DanTraits_IsInhaler = function(item) return item._type == "Inhaler" end
DanTraits_DiaInject = function(player, n) seen.inject = { player = player, n = n } end
DanTraits_DiaOnPill = function(player) seen.pill = player end
DanTraits_UseInhaler = function(player) seen.inhaler = player end
DanTraits_DiaRead = function() return 6.2, false end
DanTraits_Story = function() end

H.load("shared/TimedActions/ISDiabetesAction.lua", "shared/TimedActions/ISUseInhalerAction.lua",
       "shared/TimedActions/ISVitalityPillAction.lua")

-- a game item: uses left, and a record of what was done to it
local function item(kind, uses)
  local it = { _type = kind, _uses = uses, _used = 0, _jobDelta = -1, _name = nil }
  function it:getType() return self._type end
  -- as the game: a count of uses, and separately how full it is (0 to 1)
  function it:getCurrentUses() return math.floor(self._uses) end
  function it:getCurrentUsesFloat() return self._uses > 0 and math.min(1, self._uses / 40) or 0 end
  function it:Use() self._uses = self._uses - 1; self._used = self._used + 1 end
  function it:setJobDelta(d) self._jobDelta = d end
  function it:setJobType(t) self._job = t end
  function it:setName(n) self._name = n end
  function it:setCustomName(b) self._custom = b end
  return it
end

-- a character whose inventory holds exactly the items given
local function character(...)
  local held = {}
  for _, it in ipairs({ ... }) do held[it] = true end
  local c = H.player({ traits = {} })
  c.getInventory = function() return { contains = function(_, it) return held[it] == true end } end
  c.isTimedActionInstant = function() return c._instant == true end
  return c
end

-- 1. inject: valid with the pen held and doses left; perform uses min(doses, left) and calls DiaInject
local pen = item("Insulin", 5)
local me = character(pen)
local inject = ISDiabetesAction:new(me, pen, "inject", 3)
assert(inject.maxTime == 90 and inject.kind == "inject" and inject.doses == 3, "inject shape")
assert(inject:isValid(), "inject valid")
inject:start(); assert(pen._job == "ContextMenu_DanTraits_Inject" and pen._jobDelta == 0, "start marks the job")
inject:update(); assert(inject._anim == "Bandage" and pen._jobDelta == 0.5, "update animates")
inject:perform()
assert(pen._used == 3, "three doses used, got " .. pen._used)
assert(seen.inject and seen.inject.n == 3 and seen.inject.player == me, "DiaInject(player, 3)")
assert(inject._performed == 1 and pen._jobDelta == 0, "base perform ran, job cleared")
inject:stop(); assert(inject._stopped == 1, "base stop ran")

-- fewer doses left than asked: only what is left is used
seen.inject = nil
local low = item("Insulin", 2)
local me2 = character(low)
local a = ISDiabetesAction:new(me2, low, "inject", 5); a:perform()
assert(low._used == 2 and seen.inject.n == 2, "uses only the doses left")
-- an empty pen: no doses, no call
seen.inject = nil
local empty = item("Insulin", 0)
local me3 = character(empty)
local b = ISDiabetesAction:new(me3, empty, "inject", 2)
assert(not b:isValid(), "empty pen is not valid")
b:perform(); assert(seen.inject == nil and empty._used == 0, "nothing injected from an empty pen")

-- 2. test: a strip is used, the reading is announced and the meter renamed
local meter, strips = item("GlucoseMeter", 1), item("Strips", 3)
local me4 = character(meter, strips)
local test = ISDiabetesAction:new(me4, meter, "test", nil, strips)
assert(test.maxTime == 70 and test:isValid(), "test valid with strips")
H.clearHalo()
test:perform()
assert(strips._used == 1 and meter._used == 0, "one strip used, the meter is not")
assert(H.halo[#H.halo] == "+UI_DanTraits_DiaReading:6.2", "reading announced, got " .. tostring(H.halo[#H.halo]))
assert(meter._name == "Glucose Meter (6.2)" and meter._custom == true, "meter renamed with the reading")
-- no strips, or empty strips: invalid
local me5 = character(meter)
assert(not ISDiabetesAction:new(me5, meter, "test", nil, nil):isValid(), "no strips: invalid")
local dry = item("Strips", 0)
local me6 = character(meter, dry)
assert(not ISDiabetesAction:new(me6, meter, "test", nil, dry):isValid(), "used-up strips: invalid")
-- a strip the character does not hold
assert(not ISDiabetesAction:new(character(meter), meter, "test", nil, strips):isValid(), "strips not carried: invalid")

-- 3. pill: one use and DiaOnPill
local pill = item("Metformin", 2)
local me7 = character(pill)
local take = ISDiabetesAction:new(me7, pill, "pill")
assert(take.maxTime == 60 and take:isValid(), "pill valid")
take:update(); assert(take._anim == "TakePills", "pill animation")
take:perform()
assert(pill._used == 1 and seen.pill == me7, "one pill used, DiaOnPill called")
-- the wrong item, or an item not carried: invalid
assert(not ISDiabetesAction:new(character(), pill, "pill"):isValid(), "not carried: invalid")
assert(not ISDiabetesAction:new(me7, item("Insulin", 4), "pill"):isValid(), "not carried: invalid (other item)")
local wrongKind = item("Aspirin", 4)
assert(not ISDiabetesAction:new(character(wrongKind), wrongKind, "pill"):isValid(), "not metformin: invalid")
assert(not ISDiabetesAction:new(me7, pill, "nonsense"):isValid(), "unknown kind: invalid")
-- instant mode
local quick = character(pill); quick._instant = true
assert(ISDiabetesAction:new(quick, pill, "pill").maxTime == 1, "instant timed actions take one tick")

-- 4. inhaler
local puffer = item("Inhaler", 4)
local me8 = character(puffer)
local use = ISUseInhalerAction:new(me8, puffer)
assert(use.maxTime == 60 and use:isValid(), "inhaler valid")
use:start(); assert(puffer._job == "ContextMenu_DanTraits_UseInhaler", "inhaler job label")
use:perform()
assert(puffer._used == 1 and seen.inhaler == me8, "one puff used, UseInhaler called")
assert(not ISUseInhalerAction:new(character(), puffer):isValid(), "not carried: invalid")
local flat = item("Inhaler", 0)
assert(not ISUseInhalerAction:new(character(flat), flat):isValid(), "empty inhaler: invalid")
local notInhaler = item("Bandage", 3)
assert(not ISUseInhalerAction:new(character(notInhaler), notInhaler):isValid(), "not an inhaler: invalid")
quick = character(puffer); quick._instant = true
assert(ISUseInhalerAction:new(quick, puffer).maxTime == 1, "instant inhaler")

-- 5. vitality pill: uses one and fires the "pill" hook with the item type
local got = {}
DanTraits_AddHook("pill", function(_, player, kind) got[#got + 1] = { player = player, kind = kind } end)
local iron = item("IronPills", 3)
local me9 = character(iron)
local ironAct = ISVitalityPillAction:new(me9, iron, "ContextMenu_DanTraits_TakeIronPill")
assert(ironAct.maxTime == 60 and ironAct:isValid(), "iron pill valid")
ironAct:start(); assert(iron._job == "ContextMenu_DanTraits_TakeIronPill", "label passed through")
ironAct:perform()
assert(iron._used == 1, "one pill used")
assert(#got == 1 and got[1].player == me9 and got[1].kind == "IronPills", "pill hook carries the item type")
local none = item("IronPills", 0)
assert(not ISVitalityPillAction:new(character(none), none):isValid(), "empty: invalid")
assert(not ISVitalityPillAction:new(character(), iron):isValid(), "not carried: invalid")
local defaulted = ISVitalityPillAction:new(me9, iron); defaulted:start()
assert(iron._job == "ContextMenu_DanTraits_TakeIronPill", "default label")

H.pass()

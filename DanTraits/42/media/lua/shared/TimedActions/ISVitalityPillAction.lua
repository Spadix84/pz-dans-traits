-- One pill from one of this mod's bottles, then the shared "pill" hook with
-- the item's type, so the trait that cares (iron pills: Anaemic) does the
-- rest. Same shape as taking metformin.
require "TimedActions/ISBaseTimedAction"

ISVitalityPillAction = ISBaseTimedAction:derive("ISVitalityPillAction")

local function uses(item)
    local n = 0
    pcall(function() n = item:getCurrentUsesFloat() or 0 end)
    return n
end

function ISVitalityPillAction:isValid()
    return self.character:getInventory():contains(self.item) and uses(self.item) > 0
end

function ISVitalityPillAction:update()
    self.item:setJobDelta(self:getJobDelta())
    self:setActionAnim(CharacterActionAnims.TakePills)
end

function ISVitalityPillAction:start()
    self.item:setJobType(getText("ContextMenu_DanTraits_TakeIronPill"))
    self.item:setJobDelta(0.0)
    self:setOverrideHandModels(nil, self.item)
end

function ISVitalityPillAction:stop()
    ISBaseTimedAction.stop(self)
    self.item:setJobDelta(0.0)
end

function ISVitalityPillAction:perform()
    self.item:setJobDelta(0.0)
    self.item:Use()
    local kind = ""
    pcall(function() kind = tostring(self.item:getType()) end)
    if DanTraits_RunHooks then pcall(function() DanTraits_RunHooks("pill", nil, self.character, kind) end) end
    ISBaseTimedAction.perform(self)
end

function ISVitalityPillAction:new(character, item)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.maxTime = 60
    if character:isTimedActionInstant() then o.maxTime = 1 end
    return o
end

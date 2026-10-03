require "TimedActions/ISBaseTimedAction"

ISUseInhalerAction = ISBaseTimedAction:derive("ISUseInhalerAction")

function ISUseInhalerAction:isValid()
    if not (DanTraits_IsInhaler and DanTraits_IsInhaler(self.item)) then return false end
    return self.character:getInventory():contains(self.item) and DanTraits_ItemUses(self.item) > 0
end

function ISUseInhalerAction:update()
    self.item:setJobDelta(self:getJobDelta())
    self:setActionAnim(CharacterActionAnims.TakePills)
end

function ISUseInhalerAction:start()
    self.item:setJobType(getText("ContextMenu_DanTraits_UseInhaler"))
    self.item:setJobDelta(0.0)
    self:setOverrideHandModels(nil, self.item)
end

function ISUseInhalerAction:stop()
    ISBaseTimedAction.stop(self)
    self.item:setJobDelta(0.0)
end

function ISUseInhalerAction:perform()
    self.item:setJobDelta(0.0)
    self.item:Use()
    if DanTraits_UseInhaler then DanTraits_UseInhaler(self.character) end
    if DanTraits_MedTake then DanTraits_MedTake(self.character, "inhaler", 1) end   -- anyone's puff counts toward too many
    ISBaseTimedAction.perform(self)
end

function ISUseInhalerAction:new(character, item)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.stopOnWalk = false
    o.stopOnRun = true
    o.stopOnAim = false
    o.maxTime = character:isTimedActionInstant() and 1 or 60
    return o
end

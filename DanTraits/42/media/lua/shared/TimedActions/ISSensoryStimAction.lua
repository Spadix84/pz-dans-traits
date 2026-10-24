-- Sensory Issues: a stim. A fidget toy turned over in the hands (a yo-yo, a
-- puzzle cube, dice, a key ring) or something soft held close (a plush, a
-- doll); at the end the sensory load drops (DanTraits_SensoryStim).
require "TimedActions/ISBaseTimedAction"

ISSensoryStimAction = ISBaseTimedAction:derive("ISSensoryStimAction")

function ISSensoryStimAction:isValid()
    if not (DanTraits_SensoryStimKind and DanTraits_SensoryStimKind(self.item)) then return false end
    return self.character:getInventory():contains(self.item)
end

function ISSensoryStimAction:update()
    self.item:setJobDelta(self:getJobDelta())
    self:setActionAnim(CharacterActionAnims.Craft)
end

function ISSensoryStimAction:start()
    self.item:setJobType(self.label)
    self.item:setJobDelta(0.0)
    self:setOverrideHandModels(nil, self.item)
end

function ISSensoryStimAction:stop()
    ISBaseTimedAction.stop(self)
    self.item:setJobDelta(0.0)
end

function ISSensoryStimAction:perform()
    self.item:setJobDelta(0.0)
    if DanTraits_SensoryStim then DanTraits_SensoryStim(self.character) end
    ISBaseTimedAction.perform(self)
end

function ISSensoryStimAction:new(character, item)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    local hold = DanTraits_SensoryStimKind and DanTraits_SensoryStimKind(item) == "hold"
    o.label = getText(hold and "ContextMenu_DanTraits_SensoryHold" or "ContextMenu_DanTraits_SensoryFidget")
    o.stopOnWalk = false
    o.stopOnRun = true
    o.stopOnAim = true
    o.maxTime = character:isTimedActionInstant() and 1 or 500
    return o
end

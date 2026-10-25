-- Strain's Breaking Point (DanTraits_Strain.lua): the character sits down
-- where they are and cannot do anything else for a while. Queued only at a
-- safe moment; walking away or a zombie coming close ends it unfinished, and
-- it comes again at the next safe moment. Finished, strain drops back
-- (DanTraits_StrainBreakdownDone).
require "TimedActions/ISBaseTimedAction"

ISStrainBreakdownAction = ISBaseTimedAction:derive("ISStrainBreakdownAction")

local DANGER_EVERY = 30   -- frames between looks for a zombie closing in

function ISStrainBreakdownAction:isValid()
    return true
end

function ISStrainBreakdownAction:update()
    self.danTraitsLook = (self.danTraitsLook or 0) + 1
    if self.danTraitsLook < DANGER_EVERY then return end
    self.danTraitsLook = 0
    if DanTraits_StrainDanger and DanTraits_StrainDanger(self.character) then self:forceStop() end
end

function ISStrainBreakdownAction:start()
    pcall(function() self.character:reportEvent("EventSitOnGround") end)
    if DanTraits_StrainBreakdownStart then DanTraits_StrainBreakdownStart(self.character) end
end

function ISStrainBreakdownAction:stop()
    if DanTraits_StrainBreakdownStop then DanTraits_StrainBreakdownStop(self.character) end
    ISBaseTimedAction.stop(self)
end

function ISStrainBreakdownAction:perform()
    if DanTraits_StrainBreakdownDone then DanTraits_StrainBreakdownDone(self.character) end
    ISBaseTimedAction.perform(self)
end

function ISStrainBreakdownAction:new(character)
    local o = ISBaseTimedAction.new(self, character)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
    o.maxTime = character:isTimedActionInstant() and 1 or 1800
    return o
end

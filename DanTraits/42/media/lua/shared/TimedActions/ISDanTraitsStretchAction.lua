-- Project Zomboid Vitality Project: stretching (plans/fitness-overhaul.md, section 2).
--
-- Started from the fitness window's Stretching entry for the minutes it
-- shows, standing or sat on the ground. Like the game's fitness action it
-- runs on the calendar: it ends when that many in-game minutes have passed,
-- or on a step, on a vehicle, on climbing. It plays the game's tired stretch
-- (an "ext" animation, which also has a sat-on-the-ground version) every
-- STRETCH_EVERY_MS of real time. The bar over the head shows the share of
-- the minutes done (setJobDelta: the action's own time is not the clock it
-- runs on). Everything stretching does is in DanTraits_Fitness.lua, which
-- sees this action at the head of the queue.
require "TimedActions/ISBaseTimedAction"

ISDanTraitsStretchAction = ISBaseTimedAction:derive("ISDanTraitsStretchAction")

local STRETCH_EVERY_MS = 6000

local function nowMs()
    local ms = 0
    pcall(function() ms = getGameTime():getCalender():getTimeInMillis() end)
    return tonumber(ms) or 0
end

function ISDanTraitsStretchAction:isValid()
    return self.character:getVehicle() == nil
end

function ISDanTraitsStretchAction:stretch()
    self.lastStretch = getTimestampMs()
    pcall(function()
        self.character:setVariable("Ext", "TiredStretch")
        self.character:reportEvent("EventDoExt")
    end)
end

function ISDanTraitsStretchAction:update()
    if self.character:isClimbing() or self.character:isAiming() then
        self:forceStop()
        return
    end
    if self.character:pressedMovement(true) then
        self:forceStop()
        return
    end
    if nowMs() > self.endMS then
        self:forceStop()   -- as the game's fitness action ends
        return
    end
    local span = self.endMS - self.startMS
    if span > 0 then pcall(function() self:setJobDelta(math.max(0, math.min(1, (nowMs() - self.startMS) / span))) end) end
    if getTimestampMs() - (self.lastStretch or 0) >= STRETCH_EVERY_MS then self:stretch() end
    pcall(function() self.character:setMetabolicTarget(Metabolics.LightDomestic) end)
end

function ISDanTraitsStretchAction:start()
    -- the minutes count from the start (queued behind getting up, they would not)
    self.startMS = nowMs()
    self.endMS = self.startMS + self.minutes * 60000
    self:stretch()
end

function ISDanTraitsStretchAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISDanTraitsStretchAction:perform()
    ISBaseTimedAction.perform(self)
end

function ISDanTraitsStretchAction:complete()
    return true
end

function ISDanTraitsStretchAction:getDuration()
    return 5000000
end

function ISDanTraitsStretchAction:new(character, minutes)
    local o = ISBaseTimedAction.new(self, character)
    o.minutes = tonumber(minutes) or 10
    o.startMS = nowMs()
    o.endMS = o.startMS + o.minutes * 60000
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    return o
end

-- Project Zomboid Vitality Project: a hot water bottle held on sore muscles
-- (DanTraits_HotWaterBottle.lua). Started from the bottle's menu with a muscle
-- group; standing or sat on the ground. Like stretching it runs on the
-- calendar: it ends when DanTraits_HWB_APPLY_MIN in-game minutes have passed,
-- on a step, on a vehicle, on climbing or aiming, or when the bottle is no
-- longer Hot or Warm (or no longer carried). The bar over the head shows the
-- share of the minutes done. What the heat does is in
-- DanTraits_HotWaterBottle.lua, which sees this action at the head of the queue.
require "TimedActions/ISBaseTimedAction"

ISDanTraitsHeatAction = ISBaseTimedAction:derive("ISDanTraitsHeatAction")

local function nowMs()
    local ms = 0
    pcall(function() ms = getGameTime():getCalender():getTimeInMillis() end)
    return tonumber(ms) or 0
end

local function stillWarm(item)
    local stage = DanTraits_HwbStage and DanTraits_HwbStage(item)
    return stage == "hot" or stage == "warm"
end

function ISDanTraitsHeatAction:isValid()
    if self.character:getVehicle() ~= nil then return false end
    if not self.character:getInventory():containsRecursive(self.item) then return false end
    return stillWarm(self.item)
end

function ISDanTraitsHeatAction:update()
    if self.character:isClimbing() or self.character:isAiming() or self.character:pressedMovement(true) then
        self:forceStop()
        return
    end
    if nowMs() > self.endMS then
        self:forceStop()
        return
    end
    local span = self.endMS - self.startMS
    if span > 0 then
        local delta = math.max(0, math.min(1, (nowMs() - self.startMS) / span))
        pcall(function()
            self:setJobDelta(delta)
            self.item:setJobDelta(delta)
        end)
    end
    pcall(function() self.character:setMetabolicTarget(Metabolics.SeatedResting) end)
end

function ISDanTraitsHeatAction:start()
    self.startMS = nowMs()
    self.endMS = self.startMS + self.minutes * 60000
    pcall(function()
        self.item:setJobType(getText("ContextMenu_DanTraits_HwbApply"))
        self.item:setJobDelta(0.0)
        self:setOverrideHandModels(nil, self.item)
    end)
end

function ISDanTraitsHeatAction:stop()
    pcall(function() self.item:setJobDelta(0.0) end)
    ISBaseTimedAction.stop(self)
end

function ISDanTraitsHeatAction:perform()
    pcall(function() self.item:setJobDelta(0.0) end)
    ISBaseTimedAction.perform(self)
end

function ISDanTraitsHeatAction:complete()
    return true
end

function ISDanTraitsHeatAction:getDuration()
    return 5000000
end

function ISDanTraitsHeatAction:new(character, item, group)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.group = group
    o.minutes = DanTraits_HWB_APPLY_MIN or 30
    o.startMS = nowMs()
    o.endMS = o.startMS + o.minutes * 60000
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
    o.maxTime = o:getDuration()
    return o
end

-- Feeding the firebox, lighting it and putting it out. The items come from the
-- character's inventory (the menu queues the transfers first).
require "TimedActions/ISBaseTimedAction"
require "Smoker_Core"

local function stillThere(obj)
    return obj ~= nil and obj:getSquare() ~= nil and obj:getObjectIndex() ~= -1
end

local function faceIt(self)
    self.character:faceThisObject(self.smoker)
    return self.character:shouldBeTurning()
end

local function stopSound(self)
    if self.sound then self.character:stopOrTriggerSound(self.sound) end
end

-- Add fuel ---------------------------------------------------------------------------
SmokerAddFuelAction = ISBaseTimedAction:derive("SmokerAddFuelAction")

function SmokerAddFuelAction:isValid()
    if not stillThere(self.smoker) or Smoker.room(self.smoker) <= 0 then return false end
    return self.character:getInventory():containsID(self.item:getID())
end

SmokerAddFuelAction.waitToStart = faceIt

function SmokerAddFuelAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    self.character:reportEvent("EventLootItem")
    self.sound = self.character:playSound("CampfireAddFuel")
end

function SmokerAddFuelAction:stop()
    stopSound(self)
    ISBaseTimedAction.stop(self)
end

function SmokerAddFuelAction:perform()
    stopSound(self)
    ISBaseTimedAction.perform(self)
end

function SmokerAddFuelAction:complete()
    local hours = Smoker.fuelValue(self.item)
    if not hours then return false end
    local inv = self.character:getInventory()
    self.character:removeFromHands(self.item)
    inv:Remove(self.item)
    sendRemoveItemFromContainer(inv, self.item)
    local added = Smoker.addFuel(self.smoker, hours)
    Smoker.fire("fuelAdded", self.character, self.smoker, self.item, added)
    return true
end

function SmokerAddFuelAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 40
end

function SmokerAddFuelAction:new(character, smoker, item)
    local o = ISBaseTimedAction.new(self, character)
    o.smoker, o.item = smoker, item
    o.maxTime = o:getDuration()
    return o
end

-- Light it ---------------------------------------------------------------------------
SmokerLightAction = ISBaseTimedAction:derive("SmokerLightAction")

function SmokerLightAction:isValid()
    if not stillThere(self.smoker) or Smoker.lightProblem(self.smoker) then return false end
    return self.character:getInventory():containsID(self.starter:getID())
end

SmokerLightAction.waitToStart = faceIt

function SmokerLightAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    self.character:reportEvent("EventLootItem")
    self.sound = self.character:playSound("CampfireLight")
end

SmokerLightAction.stop = SmokerAddFuelAction.stop
SmokerLightAction.perform = SmokerAddFuelAction.perform

function SmokerLightAction:complete()
    if self.starter:IsDrainable() then
        self.starter:UseAndSync()
    else
        local inv = self.character:getInventory()
        inv:Remove(self.starter)
        sendRemoveItemFromContainer(inv, self.starter)
    end
    return Smoker.light(self.smoker, nil, self.character)
end

function SmokerLightAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 80
end

function SmokerLightAction:new(character, smoker, starter)
    local o = ISBaseTimedAction.new(self, character)
    o.smoker, o.starter = smoker, starter
    o.maxTime = o:getDuration()
    return o
end

-- Put it out -------------------------------------------------------------------------
SmokerPutOutAction = ISBaseTimedAction:derive("SmokerPutOutAction")

function SmokerPutOutAction:isValid()
    return stillThere(self.smoker) and Smoker.isLit(self.smoker)
end

SmokerPutOutAction.waitToStart = faceIt

function SmokerPutOutAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    self.character:reportEvent("EventLootItem")
end

function SmokerPutOutAction:complete()
    Smoker.extinguish(self.smoker, "player", self.character)
    return true
end

function SmokerPutOutAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 50
end

function SmokerPutOutAction:new(character, smoker)
    local o = ISBaseTimedAction.new(self, character)
    o.smoker = smoker
    o.maxTime = o:getDuration()
    return o
end

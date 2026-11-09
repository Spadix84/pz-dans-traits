-- Putting a window air conditioner in a window and taking it out, with a screwdriver.
-- The character stands by the window on the side the unit will face (the menu walks
-- them there); the unit comes out of their inventory and goes back into it.
require "TimedActions/ISBaseTimedAction"
require "DansClimate_WindowAC"

local AC = DansClimate.WindowAC

local function stillHas(character, item)
    return item ~= nil and character:getInventory():containsRecursive(item)
end

local function startWork(self)
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
    self:setOverrideHandModels(self.screwdriver, nil)
    self.sound = self.character:playSound("Dismantle")
end

local function stopSound(self)
    if self.sound and self.sound ~= 0 then self.character:stopOrTriggerSound(self.sound) end
end

local function instant(character, ticks)
    if character:isTimedActionInstant() then return 1 end
    return ticks
end

-- Install ----------------------------------------------------------------------------
DansClimateInstallACAction = ISBaseTimedAction:derive("DansClimateInstallACAction")

function DansClimateInstallACAction:isValid()
    return AC.installProblem(self.window) == nil
        and stillHas(self.character, self.item) and stillHas(self.character, self.screwdriver)
end

function DansClimateInstallACAction:waitToStart()
    self.character:faceThisObjectAlt(self.window)
    return self.character:shouldBeTurning()
end

function DansClimateInstallACAction:update()
    self.character:faceThisObjectAlt(self.window)
    self.character:setMetabolicTarget(Metabolics.UsingTools)
end

function DansClimateInstallACAction:start() startWork(self) end

function DansClimateInstallACAction:stop()
    stopSound(self)
    ISBaseTimedAction.stop(self)
end

function DansClimateInstallACAction:perform()
    stopSound(self)
    ISBaseTimedAction.perform(self)
end

function DansClimateInstallACAction:complete()
    if AC.installProblem(self.window) then return false end
    local inv = self.character:getInventory()
    if not inv:containsRecursive(self.item) then return false end
    -- the facing was fixed when the action was queued, from the side they stood on
    AC.install(self.window, self.facing, self.item, self.character)
    local container = self.item:getContainer()
    container:DoRemoveItem(self.item)
    sendRemoveItemFromContainer(container, self.item)
    return true
end

function DansClimateInstallACAction:getDuration()
    return instant(self.character, 300)
end

function DansClimateInstallACAction:new(character, window, item, screwdriver, facing)
    local o = ISBaseTimedAction.new(self, character)
    o.window = window
    o.item = item
    o.screwdriver = screwdriver
    o.facing = facing
    o.maxTime = o:getDuration()
    return o
end

-- Remove -----------------------------------------------------------------------------
DansClimateRemoveACAction = ISBaseTimedAction:derive("DansClimateRemoveACAction")

function DansClimateRemoveACAction:isValid()
    return self.unit:getObjectIndex() ~= -1 and AC.isUnit(self.unit)
        and stillHas(self.character, self.screwdriver)
end

function DansClimateRemoveACAction:waitToStart()
    self.character:faceThisObjectAlt(self.unit)
    return self.character:shouldBeTurning()
end

function DansClimateRemoveACAction:update()
    self.character:faceThisObjectAlt(self.unit)
    self.character:setMetabolicTarget(Metabolics.UsingTools)
end

function DansClimateRemoveACAction:start() startWork(self) end

function DansClimateRemoveACAction:stop()
    stopSound(self)
    ISBaseTimedAction.stop(self)
end

function DansClimateRemoveACAction:perform()
    stopSound(self)
    ISBaseTimedAction.perform(self)
end

function DansClimateRemoveACAction:complete()
    if self.unit:getObjectIndex() == -1 or not AC.isUnit(self.unit) then return false end
    local item = AC.remove(self.unit)
    if item then
        local inv = self.character:getInventory()
        inv:AddItem(item)
        sendAddItemToContainer(inv, item)
    end
    return true
end

function DansClimateRemoveACAction:getDuration()
    return instant(self.character, 200)
end

function DansClimateRemoveACAction:new(character, unit, screwdriver)
    local o = ISBaseTimedAction.new(self, character)
    o.unit = unit
    o.screwdriver = screwdriver
    o.maxTime = o:getDuration()
    return o
end

-- On / off: a turn of the dial. Switching on needs power; switching off never does.
DansClimateToggleACAction = ISBaseTimedAction:derive("DansClimateToggleACAction")

function DansClimateToggleACAction:isValid()
    if self.unit:getObjectIndex() == -1 or not AC.isUnit(self.unit) then return false end
    return not self.on or AC.isPowered(self.unit)
end

function DansClimateToggleACAction:waitToStart()
    self.character:faceThisObjectAlt(self.unit)
    return self.character:shouldBeTurning()
end

function DansClimateToggleACAction:update()
    self.character:faceThisObjectAlt(self.unit)
end

function DansClimateToggleACAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
end

function DansClimateToggleACAction:complete()
    if not self:isValid() then return false end
    AC.setOn(self.unit, self.on)
    return true
end

function DansClimateToggleACAction:getDuration()
    return instant(self.character, 20)
end

function DansClimateToggleACAction:new(character, unit, on)
    local o = ISBaseTimedAction.new(self, character)
    o.unit = unit
    o.on = on
    o.maxTime = o:getDuration()
    return o
end

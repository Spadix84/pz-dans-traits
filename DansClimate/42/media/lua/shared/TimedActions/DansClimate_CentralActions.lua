-- A furnace's or a central air conditioner's switch, and taking a unit or a vent out
-- again with a screwdriver. Putting them in is the game's own build action (the build
-- menu, scripts/DansClimate_entities.txt). The menu walks the character up first.
require "TimedActions/ISBaseTimedAction"
require "DansClimate_Central"

local Central = DansClimate.Central

local function instant(character, ticks)
    if character:isTimedActionInstant() then return 1 end
    return ticks
end

local function stillThere(obj)
    return obj:getObjectIndex() ~= -1 and Central.kind(obj) ~= nil
end

local function stillHas(character, item)
    return item ~= nil and character:getInventory():containsRecursive(item)
end

-- On / off. Either way needs no power: the thermostat decides when it works.
DansClimateToggleCentralAction = ISBaseTimedAction:derive("DansClimateToggleCentralAction")

function DansClimateToggleCentralAction:isValid()
    return stillThere(self.unit) and Central.isUnit(self.unit)
end

function DansClimateToggleCentralAction:waitToStart()
    self.character:faceThisObject(self.unit)
    return self.character:shouldBeTurning()
end

function DansClimateToggleCentralAction:update()
    self.character:faceThisObject(self.unit)
end

function DansClimateToggleCentralAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
end

function DansClimateToggleCentralAction:complete()
    if not self:isValid() then return false end
    Central.setOn(self.unit, self.on)
    return true
end

function DansClimateToggleCentralAction:getDuration()
    return instant(self.character, 20)
end

function DansClimateToggleCentralAction:new(character, unit, on)
    local o = ISBaseTimedAction.new(self, character)
    o.unit = unit
    o.on = on
    o.maxTime = o:getDuration()
    return o
end

-- Take a unit or a vent out. A unit comes back as its item: into the character's hands
-- if there is room to carry it, else onto the floor where it stood.
DansClimateRemoveCentralAction = ISBaseTimedAction:derive("DansClimateRemoveCentralAction")

function DansClimateRemoveCentralAction:isValid()
    return stillThere(self.unit) and stillHas(self.character, self.screwdriver)
end

function DansClimateRemoveCentralAction:waitToStart()
    self.character:faceThisObject(self.unit)
    return self.character:shouldBeTurning()
end

function DansClimateRemoveCentralAction:update()
    self.character:faceThisObject(self.unit)
    self.character:setMetabolicTarget(Metabolics.UsingTools)
end

function DansClimateRemoveCentralAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", Central.isVent(self.unit) and "Low" or "Mid")
    self:setOverrideHandModels(self.screwdriver, nil)
    self.sound = self.character:playSound("Dismantle")
end

local function stopSound(self)
    if self.sound and self.sound ~= 0 then self.character:stopOrTriggerSound(self.sound) end
end

function DansClimateRemoveCentralAction:stop()
    stopSound(self)
    ISBaseTimedAction.stop(self)
end

function DansClimateRemoveCentralAction:perform()
    stopSound(self)
    ISBaseTimedAction.perform(self)
end

function DansClimateRemoveCentralAction:complete()
    if not stillThere(self.unit) then return false end
    local sq = self.unit:getSquare()
    local item = Central.remove(self.unit)
    if not item then return true end
    local inv = self.character:getInventory()
    if inv:hasRoomFor(self.character, item) then
        inv:AddItem(item)
        sendAddItemToContainer(inv, item)
    else
        sq:AddWorldInventoryItem(item, 0.5, 0.5, 0)
    end
    return true
end

function DansClimateRemoveCentralAction:getDuration()
    return instant(self.character, Central.isVent(self.unit) and 150 or 400)
end

function DansClimateRemoveCentralAction:new(character, unit, screwdriver)
    local o = ISBaseTimedAction.new(self, character)
    o.unit = unit
    o.screwdriver = screwdriver
    o.maxTime = o:getDuration()
    return o
end

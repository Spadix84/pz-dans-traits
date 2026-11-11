-- A space heater's controls: its switch, and its low/high setting and dial. The menu
-- walks the character up to the heater first. (Picking it up and putting it down are
-- the game's own furniture actions.)
require "TimedActions/ISBaseTimedAction"
require "DansClimate_Heater"

local Heater = DansClimate.Heater

local function instant(character, ticks)
    if character:isTimedActionInstant() then return 1 end
    return ticks
end

local function stillThere(unit)
    return unit:getObjectIndex() ~= -1 and Heater.isUnit(unit)
end

local function reach(self)
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
end

-- On / off. Switching on needs power; switching off never does.
DansClimateToggleHeaterAction = ISBaseTimedAction:derive("DansClimateToggleHeaterAction")

function DansClimateToggleHeaterAction:isValid()
    if not stillThere(self.unit) then return false end
    return not self.on or Heater.isPowered(self.unit)
end

function DansClimateToggleHeaterAction:waitToStart()
    self.character:faceThisObject(self.unit)
    return self.character:shouldBeTurning()
end

function DansClimateToggleHeaterAction:update()
    self.character:faceThisObject(self.unit)
end

function DansClimateToggleHeaterAction:start() reach(self) end

function DansClimateToggleHeaterAction:complete()
    if not self:isValid() then return false end
    Heater.setOn(self.unit, self.on)
    return true
end

function DansClimateToggleHeaterAction:getDuration()
    return instant(self.character, 20)
end

function DansClimateToggleHeaterAction:new(character, unit, on)
    local o = ISBaseTimedAction.new(self, character)
    o.unit = unit
    o.on = on
    o.maxTime = o:getDuration()
    return o
end

-- The low/high switch and the dial: either may be nil to leave it as it is.
DansClimateSetHeaterAction = ISBaseTimedAction:derive("DansClimateSetHeaterAction")

function DansClimateSetHeaterAction:isValid()
    return stillThere(self.unit)
end

function DansClimateSetHeaterAction:waitToStart()
    self.character:faceThisObject(self.unit)
    return self.character:shouldBeTurning()
end

function DansClimateSetHeaterAction:update()
    self.character:faceThisObject(self.unit)
end

function DansClimateSetHeaterAction:start() reach(self) end

function DansClimateSetHeaterAction:complete()
    if not self:isValid() then return false end
    if self.level then Heater.setLevel(self.unit, self.level) end
    if self.setpoint then Heater.setSetpoint(self.unit, self.setpoint) end
    return true
end

function DansClimateSetHeaterAction:getDuration()
    return instant(self.character, 20)
end

function DansClimateSetHeaterAction:new(character, unit, level, setpoint)
    local o = ISBaseTimedAction.new(self, character)
    o.unit = unit
    o.level = level
    o.setpoint = setpoint
    o.maxTime = o:getDuration()
    return o
end

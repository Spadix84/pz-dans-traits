-- Right-click menu for a space heater on the clicked square:
--   Space Heater (room 12 °C) > Turn On / Turn Off, Low, High, Heat to > 14..28
-- The temperature is the room's from the model; a heater outdoors or in a room the
-- model doesn't cover shows none. Picking it up, placing it and turning it are the
-- game's own furniture tools.
require "DansClimate_Climate"
require "DansClimate_Heater"
require "TimedActions/DansClimate_HeaterActions"

local C = DansClimate.Climate
local Heater = DansClimate.Heater

local function gather(worldobjects)
    local units, seen = {}, {}
    for _, obj in ipairs(worldobjects) do
        local sq = obj:getSquare()
        if sq and not seen[sq] then
            seen[sq] = true
            local objects = sq:getObjects()
            for i = 0, objects:size() - 1 do
                local o = objects:get(i)
                if Heater.isUnit(o) then units[#units + 1] = o end
            end
        end
    end
    return units
end

local function tooltip(text)
    local tip = ISWorldObjectContextMenu.addToolTip()
    tip.description = text
    return tip
end

local function current(label, isCurrent)
    if isCurrent then return getText("ContextMenu_DansClimate_Current", label) end
    return label
end

local function onToggle(_, playerObj, unit, on)
    if not luautils.walkAdj(playerObj, unit:getSquare()) then return end
    ISTimedActionQueue.add(DansClimateToggleHeaterAction:new(playerObj, unit, on))
end

local function onSet(_, playerObj, unit, level, setpoint)
    if not luautils.walkAdj(playerObj, unit:getSquare()) then return end
    ISTimedActionQueue.add(DansClimateSetHeaterAction:new(playerObj, unit, level, setpoint))
end

-- what the heater is doing, for the tooltip
function Heater.status(unit)
    local set = C.format(Heater.setpoint(unit))
    local level = getText("ContextMenu_DansClimate_Level_" .. Heater.level(unit))
    if not Heater.isOn(unit) then return getText("Tooltip_DansClimate_HeaterOff", set, level) end
    if Heater.heating(unit) then return getText("Tooltip_DansClimate_HeaterHeating", set, level) end
    return getText("Tooltip_DansClimate_HeaterIdle", set, level)
end

local function unitOptions(context, worldobjects, playerObj, unit)
    local temp = C.temperatureAt(unit:getSquare())
    local label = temp and getText("ContextMenu_DansClimate_HeaterRoom", C.format(temp))
        or getText("ContextMenu_DansClimate_Heater")
    local option = context:addOption(label, worldobjects, nil)
    option.toolTip = tooltip(Heater.status(unit))
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(option, sub)

    if Heater.isOn(unit) then
        sub:addGetUpOption(getText("ContextMenu_DansClimate_TurnOff"), worldobjects, onToggle, playerObj, unit, false)
    else
        local on = sub:addGetUpOption(getText("ContextMenu_DansClimate_TurnOn"), worldobjects, onToggle, playerObj, unit, true)
        if not Heater.isPowered(unit) then
            on.notAvailable = true
            on.toolTip = tooltip(getText("Tooltip_DansClimate_NoPower"))
        end
    end

    local level = Heater.level(unit)
    for _, l in ipairs(Heater.LEVELS) do
        sub:addGetUpOption(current(getText("ContextMenu_DansClimate_Level_" .. l), l == level), worldobjects,
            onSet, playerObj, unit, l, nil)
    end

    local set = Heater.setpoint(unit)
    local dial = sub:addOption(getText("ContextMenu_DansClimate_HeatTo", C.format(set)), worldobjects, nil)
    local dialMenu = ISContextMenu:getNew(sub)
    sub:addSubMenu(dial, dialMenu)
    for _, v in ipairs(Heater.SETPOINTS) do
        dialMenu:addGetUpOption(current(C.format(v), v == set), worldobjects, onSet, playerObj, unit, nil, v)
    end
    return option
end

local function onFillMenu(player, context, worldobjects, test)
    local playerObj = getSpecificPlayer(player)
    if not playerObj or playerObj:getVehicle() then return end
    local units = gather(worldobjects)
    if #units == 0 then return end
    if test then return ISWorldObjectContextMenu.setTest() end
    for _, unit in ipairs(units) do unitOptions(context, worldobjects, playerObj, unit) end
end

Events.OnFillWorldObjectContextMenu.Add(onFillMenu)

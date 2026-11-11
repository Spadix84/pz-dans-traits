-- Right-click menu for a furnace, a central air conditioner or a vent on the clicked
-- square:
--   Furnace (room 12 °C) > Turn On / Turn Off, Remove Furnace
--   Central Air Conditioner (room 27 °C) > Turn On / Turn Off, Remove Central Air Conditioner
--   Vent > Remove Vent
-- The tooltip says what the unit is doing, or what a vent is connected to. The
-- temperature is the room's from the model: the furnace's own room, the room a central
-- air conditioner is hooked up through. What they heat and cool to is the building's
-- thermostat (DansClimate_ThermostatMenu.lua), which works again once a building has
-- one of these.
require "DansClimate_Climate"
require "DansClimate_Central"
require "DansClimate_WindowAC"
require "TimedActions/DansClimate_CentralActions"

local C = DansClimate.Climate
local Central = DansClimate.Central
local AC = DansClimate.WindowAC

-- translation key parts, by kind
local NAMES = { furnace = "Furnace", condenser = "CentralAC", vent = "Vent" }

local function gather(worldobjects)
    local found, seen = {}, {}
    for _, obj in ipairs(worldobjects) do
        local sq = obj:getSquare()
        if sq and not seen[sq] then
            seen[sq] = true
            local objects = sq:getObjects()
            for i = 0, objects:size() - 1 do
                local o = objects:get(i)
                if Central.kind(o) then found[#found + 1] = o end
            end
        end
    end
    return found
end

local function tooltip(text)
    local tip = ISWorldObjectContextMenu.addToolTip()
    tip.description = text
    return tip
end

local function onToggle(_, playerObj, unit, on)
    if not luautils.walkAdj(playerObj, unit:getSquare()) then return end
    ISTimedActionQueue.add(DansClimateToggleCentralAction:new(playerObj, unit, on))
end

local function onRemove(_, playerObj, unit)
    local screwdriver = AC.findScrewdriver(playerObj:getInventory())
    if not screwdriver then return end
    if not luautils.walkAdj(playerObj, unit:getSquare()) then return end
    ISWorldObjectContextMenu.transferIfNeeded(playerObj, screwdriver)
    ISTimedActionQueue.add(DansClimateRemoveCentralAction:new(playerObj, unit, screwdriver))
end

-- what the object is doing, for the tooltip
function Central.status(obj)
    local kind = Central.kind(obj)
    if kind == "vent" then return getText("Tooltip_DansClimate_Vent_" .. Central.ventState(obj)) end
    local state, arg = Central.state(obj)
    return getText("Tooltip_DansClimate_" .. NAMES[kind] .. "_" .. state, arg)
end

local function addRemove(sub, worldobjects, playerObj, obj, name)
    local option = sub:addGetUpOption(getText("ContextMenu_DansClimate_Remove" .. name), worldobjects, onRemove, playerObj, obj)
    if not AC.findScrewdriver(playerObj:getInventory()) then
        option.notAvailable = true
        option.toolTip = tooltip(getText("Tooltip_DansClimate_NeedScrewdriver"))
    end
    return option
end

local function objectOptions(context, worldobjects, playerObj, obj)
    local kind = Central.kind(obj)
    local name = NAMES[kind]
    local served = Central.servedSquare(obj)
    local temp = kind ~= "vent" and served and C.temperatureAt(served)
    local label = temp and getText("ContextMenu_DansClimate_" .. name .. "Room", C.format(temp))
        or getText("ContextMenu_DansClimate_" .. name)
    local option = context:addOption(label, worldobjects, nil)
    option.toolTip = tooltip(Central.status(obj))
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(option, sub)
    if kind ~= "vent" then
        local on = Central.isOn(obj)
        sub:addGetUpOption(getText(on and "ContextMenu_DansClimate_TurnOff" or "ContextMenu_DansClimate_TurnOn"),
            worldobjects, onToggle, playerObj, obj, not on)
    end
    addRemove(sub, worldobjects, playerObj, obj, name)
    return option
end

local function onFillMenu(player, context, worldobjects, test)
    local playerObj = getSpecificPlayer(player)
    if not playerObj or playerObj:getVehicle() then return end
    local found = gather(worldobjects)
    if #found == 0 then return end
    if test then return ISWorldObjectContextMenu.setTest() end
    for _, obj in ipairs(found) do objectOptions(context, worldobjects, playerObj, obj) end
end

Events.OnFillWorldObjectContextMenu.Add(onFillMenu)

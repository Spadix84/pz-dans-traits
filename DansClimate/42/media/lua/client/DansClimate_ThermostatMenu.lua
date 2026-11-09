-- The thermostat: a right-click option anywhere inside a map building, for the
-- building you're standing in. Map buildings have no thermostat object to click.
--   Thermostat (room 23 °C) > Off / Heat / Cool / Auto, Heat to > 16..26, Cool to > 20..30
-- In debug mode there's also "Room climate (debug)": the model's readout for the room
-- as a tooltip (and printed to the console when clicked), and the DanTraits command
-- channel gets a "climate" command that returns it.
require "DansClimate_Climate"

local C = DansClimate.Climate

local function tooltip(text)
    local tip = ISWorldObjectContextMenu.addToolTip()
    tip.description = text
    return tip
end

local function current(label, isCurrent)
    if isCurrent then return getText("ContextMenu_DansClimate_Current", label) end
    return label
end

local function setMode(_, bx, by, mode)
    local _, heat, cool = C.getThermostat(bx, by)
    C.setThermostat(bx, by, mode, heat, cool)
end

local function setHeat(_, bx, by, value)
    local mode, _, cool = C.getThermostat(bx, by)
    C.setThermostat(bx, by, mode, value, math.max(cool, value))
end

local function setCool(_, bx, by, value)
    local mode, heat = C.getThermostat(bx, by)
    C.setThermostat(bx, by, mode, math.min(heat, value), value)
end

local function status(mode, heat, cool, powered)
    if not powered then return getText("Tooltip_DansClimate_HvacNoPower") end
    return getText("Tooltip_DansClimate_Thermostat_" .. mode, C.format(heat), C.format(cool))
end

function C.addThermostatOptions(context, worldobjects, sq)
    local bx, by = C.buildingOf(sq)
    if not bx or not sq:getRoom() then return nil end
    local temp = C.temperatureAt(sq)
    local mode, heat, cool = C.getThermostat(bx, by)
    local label = temp and getText("ContextMenu_DansClimate_Thermostat", C.format(temp))
        or getText("ContextMenu_DansClimate_ThermostatNoReading")
    local option = context:addOption(label, worldobjects, nil)
    option.toolTip = tooltip(status(mode, heat, cool, C.powered(sq)))
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(option, sub)

    for _, m in ipairs(C.MODES) do
        sub:addOption(current(getText("ContextMenu_DansClimate_Mode_" .. m), m == mode), worldobjects, setMode, bx, by, m)
    end

    local heatOption = sub:addOption(getText("ContextMenu_DansClimate_HeatTo", C.format(heat)), worldobjects, nil)
    local heatMenu = ISContextMenu:getNew(sub)
    sub:addSubMenu(heatOption, heatMenu)
    for _, v in ipairs(C.HEAT_SETPOINTS) do
        heatMenu:addOption(current(C.format(v), v == heat), worldobjects, setHeat, bx, by, v)
    end

    local coolOption = sub:addOption(getText("ContextMenu_DansClimate_CoolTo", C.format(cool)), worldobjects, nil)
    local coolMenu = ISContextMenu:getNew(sub)
    sub:addSubMenu(coolOption, coolMenu)
    for _, v in ipairs(C.COOL_SETPOINTS) do
        coolMenu:addOption(current(C.format(v), v == cool), worldobjects, setCool, bx, by, v)
    end
    return option
end

-- the readout with each line on its own tooltip line
local function readoutTooltip(text)
    return (string.gsub(text, "\n", " <LINE> "))
end

local function printReadout(_, sq)
    print("[DansClimate] " .. tostring(C.readout(sq)))
end

function C.addReadoutOption(context, worldobjects, sq)
    local text = C.readout(sq)
    if not text then return nil end
    local option = context:addOption(getText("ContextMenu_DansClimate_Readout"), worldobjects, printReadout, sq)
    option.toolTip = tooltip(readoutTooltip(text))
    return option
end

local function onFillMenu(player, context, worldobjects, test)
    if test or not C.available() then return end
    local playerObj = getSpecificPlayer(player)
    if not playerObj or playerObj:getVehicle() then return end
    local sq = playerObj:getCurrentSquare()
    if not sq or not sq:getRoom() then return end
    C.addThermostatOptions(context, worldobjects, sq)
    if isDebugEnabled() then C.addReadoutOption(context, worldobjects, sq) end
end

Events.OnFillWorldObjectContextMenu.Add(onFillMenu)

-- "climate" on the DanTraits command channel (debug mode, with DanTraits on)
Events.OnGameStart.Add(function()
    DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
    DanTraits_ExtraCommands.climate = function(playerObj)
        local text = C.readout(playerObj:getCurrentSquare())
        if not text then return "climate: no room here, or the model isn't running" end
        return "climate: " .. string.gsub(text, "\n", " | ")
    end
end)

-- Right-click menu for window air conditioners, and keeping a window with one in it shut.
--
-- On a window, carrying a unit: Install Window Air Conditioner. The front faces the side
-- you stand on, so install it from inside the room it should cool.
-- On a unit: Turn On / Turn Off, and Remove Window Air Conditioner.
-- A window with a unit in it can't be opened or climbed through: the vanilla actions
-- (from any route: the click, the interact key, a controller, the menu) refuse.
require "DansClimate_WindowAC"
require "TimedActions/DansClimate_WindowACActions"
require "TimedActions/ISOpenCloseWindow"
require "TimedActions/ISClimbThroughWindow"

local AC = DansClimate.WindowAC

-- The windows and units the click could mean: the clicked squares' own, plus those on
-- the squares to the south and east, whose north and west edges are this square's far
-- edges (a window on the far side of a wall belongs to the next square).
local function gather(worldobjects)
    local windows, units, seen = {}, {}, {}
    local function scan(sq)
        if not sq or seen[sq] then return end
        seen[sq] = true
        local objects = sq:getObjects()
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            if instanceof(obj, "IsoWindow") then
                windows[#windows + 1] = obj
            elseif AC.isUnit(obj) then
                units[#units + 1] = obj
            end
        end
    end
    for _, obj in ipairs(worldobjects) do
        local sq = obj:getSquare()
        if sq then
            scan(sq)
            scan(getCell():getGridSquare(sq:getX(), sq:getY() + 1, sq:getZ()))
            scan(getCell():getGridSquare(sq:getX() + 1, sq:getY(), sq:getZ()))
        end
    end
    return windows, units
end

local function tooltip(text)
    local tip = ISWorldObjectContextMenu.addToolTip()
    tip.description = text
    return tip
end

local function unavailable(option, key)
    option.notAvailable = true
    option.toolTip = tooltip(getText(key))
end

-- Walk to the square on a side of the window, or next to it if that square is taken.
local function walkTo(playerObj, side, window)
    if side and side:isFree(false) then
        ISTimedActionQueue.add(ISWalkToTimedAction:new(playerObj, side))
        return true
    end
    return luautils.walkAdjWindowOrDoor(playerObj, window:getSquare(), window)
end

local function onInstall(_, playerObj, window)
    local inv = playerObj:getInventory()
    local item, screwdriver = AC.findUnitItem(inv), AC.findScrewdriver(inv)
    if not item or not screwdriver then return end
    -- the side they're on now is the room side; walk up to the window on it
    local facing = AC.facingFor(window, playerObj)
    if not walkTo(playerObj, window:getAddSheetSquare(playerObj), window) then return end
    ISWorldObjectContextMenu.transferIfNeeded(playerObj, item)
    ISWorldObjectContextMenu.transferIfNeeded(playerObj, screwdriver)
    ISTimedActionQueue.add(DansClimateInstallACAction:new(playerObj, window, item, screwdriver, facing))
end

local function onRemove(_, playerObj, unit)
    local screwdriver = AC.findScrewdriver(playerObj:getInventory())
    local window = AC.windowOf(unit)
    if not screwdriver then return end
    if window then
        if not walkTo(playerObj, AC.roomSquare(unit), window) then return end
    elseif not luautils.walkAdj(playerObj, unit:getSquare()) then
        return
    end
    ISWorldObjectContextMenu.transferIfNeeded(playerObj, screwdriver)
    ISTimedActionQueue.add(DansClimateRemoveACAction:new(playerObj, unit, screwdriver))
end

local function onToggle(_, playerObj, unit, on)
    local window = AC.windowOf(unit)
    if window then
        if not walkTo(playerObj, AC.roomSquare(unit), window) then return end
    elseif not luautils.walkAdj(playerObj, unit:getSquare()) then
        return
    end
    ISTimedActionQueue.add(DansClimateToggleACAction:new(playerObj, unit, on))
end

local function installOption(context, worldobjects, playerObj, window)
    local inv = playerObj:getInventory()
    local item = AC.findUnitItem(inv)
    if not item then return end   -- only offered to someone carrying one
    local option = context:addGetUpOption(getText("ContextMenu_DansClimate_InstallAC"), worldobjects,
        onInstall, playerObj, window)
    local problem = AC.installProblem(window)
    if problem then
        unavailable(option, problem)
    elseif not AC.findScrewdriver(inv) then
        unavailable(option, "Tooltip_DansClimate_NeedScrewdriver")
    else
        option.toolTip = tooltip(getText("Tooltip_DansClimate_InstallFacing"))
    end
end

local function unitOptions(context, worldobjects, playerObj, unit)
    if AC.isOn(unit) then
        context:addGetUpOption(getText("ContextMenu_DansClimate_TurnOff"), worldobjects, onToggle, playerObj, unit, false)
    else
        local option = context:addGetUpOption(getText("ContextMenu_DansClimate_TurnOn"), worldobjects,
            onToggle, playerObj, unit, true)
        if not AC.isPowered(unit) then unavailable(option, "Tooltip_DansClimate_NoPower") end
    end
    local option = context:addGetUpOption(getText("ContextMenu_DansClimate_RemoveAC"), worldobjects,
        onRemove, playerObj, unit)
    if not AC.findScrewdriver(playerObj:getInventory()) then
        unavailable(option, "Tooltip_DansClimate_NeedScrewdriver")
    end
end

local function onFillMenu(player, context, worldobjects, test)
    local playerObj = getSpecificPlayer(player)
    if not playerObj or playerObj:getVehicle() then return end
    local windows, units = gather(worldobjects)
    if test then
        if #units > 0 or (#windows > 0 and AC.findUnitItem(playerObj:getInventory())) then
            return ISWorldObjectContextMenu.setTest()
        end
        return
    end
    for _, unit in ipairs(units) do unitOptions(context, worldobjects, playerObj, unit) end
    for _, window in ipairs(windows) do
        if not AC.inWindow(window) then installOption(context, worldobjects, playerObj, window) end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillMenu)

-- A window with a unit in it stays shut ---------------------------------------------
local function blocked(character, window)
    if not instanceof(window, "IsoWindow") or not AC.inWindow(window) then return false end
    character:setHaloNote(getText("IGUI_DansClimate_ACInWindow"), 255, 160, 160, 300)
    return true
end

local function guard(class, field)
    if not class or class.DansClimateGuarded then return end
    class.DansClimateGuarded = true
    local isValid = class.isValid
    class.isValid = function(self)
        if blocked(self.character, self[field]) then return false end
        return isValid(self)
    end
end

-- ISOpenCloseWindow keeps the window in .object, ISClimbThroughWindow in .item
guard(ISOpenCloseWindow, "object")
guard(ISClimbThroughWindow, "item")
Events.OnGameStart.Add(function()
    guard(ISOpenCloseWindow, "object")
    guard(ISClimbThroughWindow, "item")
end)

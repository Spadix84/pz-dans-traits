-- Project Zomboid Vitality Project: load the washing machine in one click.
--
-- Right-click a washing machine (or a combo washer/dryer set to wash, or the
-- washer of a stacked pair) and "Put dirty clothes in the washer (N)" moves
-- every bloody or dirty garment you carry, bags included, into it: the
-- game's own Dirty / Bloody reading (isDirty, isBloody), so the hand-washed
-- ones sitting at their floor go in too. What you are wearing stays on. The
-- option is greyed with the reason when nothing you carry needs it or the
-- machine is running. The walk and the moves are the game's own transfer
-- actions, so weight, room and interruptions behave as they always do.
--
-- Right-click a dryer (a combo set to dry, or the dryer of a stacked pair)
-- with a box of dryer sheets on you and "Add a dryer sheet (N left)" puts one
-- in for the next run (ISLaundryAction "sheet"). Greyed while it runs or
-- once a sheet is in.
require "DanTraits_Laundry"
require "DanTraits_ClientUtil"

DanTraits_Washer = DanTraits_Washer or {}
local M = DanTraits_Washer

local is = DanTraits_Is

-- the washer among the clicked objects and the container that does the washing
function M.washerOf(worldobjects)
    for _, obj in ipairs(worldobjects or {}) do
        local container = nil
        if is(obj, "IsoClothingWasher") then
            pcall(function() container = obj:getContainer() end)
        elseif is(obj, "IsoCombinationWasherDryer") then
            pcall(function() if obj:isModeWasher() then container = obj:getContainer() end end)
        elseif is(obj, "IsoStackedWasherDryer") then
            pcall(function() container = obj:getContainerByType("clothingwasher") end)
            if not container then pcall(function() container = obj:getContainer() end) end
        end
        if container then return obj, container end
    end
    return nil, nil
end

local function needsWash(item)
    local dirty = false
    pcall(function() dirty = item:isDirty() == true or item:isBloody() == true end)
    return dirty
end

-- every bloody or dirty garment the player carries (bags included), not the ones worn
function M.dirtyClothes(playerObj)
    local out = {}
    local function consider(item)
        if not is(item, "Clothing") or not needsWash(item) then return end
        local worn = false
        pcall(function() worn = playerObj:isEquipped(item) == true end)
        if not worn then out[#out + 1] = item end
    end
    local ok = pcall(function()
        local all = playerObj:getInventory():getAllEvalRecurse(function() return true end, ArrayList.new())
        for i = 0, all:size() - 1 do consider(all:get(i)) end
    end)
    if not ok then
        pcall(function()
            local items = playerObj:getInventory():getItems()
            for i = 0, items:size() - 1 do consider(items:get(i)) end
        end)
    end
    return out
end

local function running(obj)
    local on = false
    pcall(function() on = obj:isActivated() == true end)
    return on
end

local greyOut = DanTraits_GreyOut   -- DanTraits_ClientUtil.lua

-- walk up, then one transfer per garment (the game's own action: room, weight, interruptions)
function M.load(playerObj, washer, container, items)
    local near = true
    pcall(function() near = luautils.walkAdj(playerObj, washer:getSquare()) end)
    if not near then return 0 end
    local moved = 0
    for _, item in ipairs(items) do
        local ok = pcall(function()
            ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, item, item:getContainer(), container))
        end)
        if ok then moved = moved + 1 end
    end
    return moved
end

-- the dryer among the clicked objects (a combo only while set to dry)
function M.dryerOf(worldobjects)
    for _, obj in ipairs(worldobjects or {}) do
        if is(obj, "IsoClothingDryer") or is(obj, "IsoStackedWasherDryer") then return obj end
        if is(obj, "IsoCombinationWasherDryer") then
            local dry = false
            pcall(function() dry = not obj:isModeWasher() end)
            if dry then return obj end
        end
    end
    return nil
end

-- a box of dryer sheets with any left, bags included
function M.sheetBox(playerObj)
    for _, item in ipairs(DanTraits_Laundry.carried(playerObj)) do
        local t = nil
        pcall(function() t = item:getFullType() end)
        if t == "DanTraits.DryerSheets" and DanTraits_ItemUses(item) > 0 then return item end
    end
    return nil
end

function M.addSheet(playerObj, dryer, box)
    local near = true
    pcall(function() near = luautils.walkAdj(playerObj, dryer:getSquare()) end)
    if not near then return end
    ISTimedActionQueue.add(ISLaundryAction:new(playerObj, box, "sheet", dryer))
end

function M.onDryerMenu(playerObj, context, worldobjects)
    local L = DanTraits_Laundry
    if not L or not L.on() then return end
    local dryer = M.dryerOf(worldobjects)
    if not dryer then return end
    local box = M.sheetBox(playerObj)
    if not box then return end
    local option = context:addOption(getText("ContextMenu_DanTraits_DryerSheetLeft", DanTraits_ItemUses(box)), playerObj, M.addSheet, dryer, box)
    if not option then return end
    if L.runningDryer(dryer) then greyOut(option, "ContextMenu_DanTraits_DryerRunning")
    elseif L.hasSheet(dryer) then greyOut(option, "ContextMenu_DanTraits_DryerSheetIn") end
end

function M.onMenu(playerNum, context, worldobjects, test)
    if test or not context then return end
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then return end
    M.onDryerMenu(playerObj, context, worldobjects)
    local washer, container = M.washerOf(worldobjects)
    if not washer then return end
    local items = M.dirtyClothes(playerObj)
    local option = context:addOption(getText("ContextMenu_DanTraits_WasherLoad", #items), playerObj, M.load, washer, container, items)
    if not option then return end
    if running(washer) then greyOut(option, "ContextMenu_DanTraits_WasherRunning")
    elseif #items == 0 then greyOut(option, "ContextMenu_DanTraits_WasherNone") end
end

Events.OnFillWorldObjectContextMenu.Add(M.onMenu)

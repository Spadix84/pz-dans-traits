-- Dan's Vanilla Fixes: load the washing machine in one click.
--
-- Right-click a washing machine (or a combo washer/dryer set to wash, or the
-- washer of a stacked pair) and "Put dirty clothes in the washer (N)" moves
-- every bloody or dirty garment you carry, bags included, into it: the
-- game's own Dirty / Bloody reading (isDirty, isBloody), so the hand-washed
-- ones sitting at their floor go in too. What you are wearing stays on. The
-- option is greyed with the reason when nothing you carry needs it or the
-- machine is running. The walk and the moves are the game's own transfer
-- actions, so weight, room and interruptions behave as they always do.
DVF_Washer = DVF_Washer or {}
local M = DVF_Washer

local function is(obj, class)
    local ok, res = pcall(function() return instanceof(obj, class) end)
    return ok and res == true
end

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

local function greyOut(option, key)
    option.notAvailable = true
    pcall(function()
        local tip = ISToolTip:new()
        tip:initialise()
        tip:setVisible(false)
        tip.description = getText(key)
        option.toolTip = tip
    end)
end

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

function M.onMenu(playerNum, context, worldobjects, test)
    if test then return end
    local washer, container = M.washerOf(worldobjects)
    if not washer or not context then return end
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then return end
    local items = M.dirtyClothes(playerObj)
    local option = context:addOption(getText("ContextMenu_DVF_WasherLoad", #items), playerObj, M.load, washer, container, items)
    if not option then return end
    if running(washer) then greyOut(option, "ContextMenu_DVF_WasherRunning")
    elseif #items == 0 then greyOut(option, "ContextMenu_DVF_WasherNone") end
end

Events.OnFillWorldObjectContextMenu.Add(M.onMenu)

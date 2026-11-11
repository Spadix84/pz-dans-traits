-- Right-click a crock with a meal in it: serve a bowl, or move it all to a pot.
-- Pouring it out is the game's own "Pour on Ground".
require "TimedActions/SlowCookerActions"

local function emptyOf(inv, types)
    return inv:getFirstEvalRecurse(function(item)
        if not types[item:getFullType()] then return false end
        local fluid = item:getFluidContainer()
        return fluid == nil or fluid:isEmpty()
    end)
end

local function queue(playerObj, action, dish, vessel)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, vessel)
    ISTimedActionQueue.add(action:new(playerObj, dish, vessel))
end

local function option(context, playerObj, text, dish, vessel, action, missing)
    local opt = context:addOption(getText(text), playerObj, queue, action, dish, vessel)
    if not vessel then
        opt.notAvailable = true
        local tip = ISInventoryPaneContextMenu.addToolTip()
        tip.description = getText(missing)
        opt.toolTip = tip
    end
end

local function onMenu(player, context, items)
    items = ISInventoryPane.getActualItems(items)
    if #items ~= 1 or items[1]:getFullType() ~= SlowCooker.DISH then return end
    local dish, playerObj = items[1], getSpecificPlayer(player)
    local inv = playerObj:getInventory()
    option(context, playerObj, "ContextMenu_SlowCooker_Serve", dish, emptyOf(inv, SlowCooker.BOWLS),
        SlowCookerServeAction, "Tooltip_SlowCooker_NeedBowl")
    option(context, playerObj, "ContextMenu_SlowCooker_ToPot", dish, emptyOf(inv, SlowCooker.POTS),
        SlowCookerToPotAction, "Tooltip_SlowCooker_NeedPot")
end

Events.OnFillInventoryObjectContextMenu.Add(onMenu)

-- In multiplayer the client also needs the crock-only rule, for the loot window.
MapObjects.OnLoadWithSprite(SlowCooker.spriteNames(), function(obj)
    if SlowCooker.isCooker(obj) then SlowCooker.limitContainer(obj) end
end, 5)

-- Right-click the smoker: a "Brick Smoker" submenu with its status, fuel, the fire,
-- and one-click loading and unloading. Fuel and fire starters can come from your
-- inventory or anything in reach (counters, crates, the floor), like vanilla crafting.
require "Definitions/ContainerButtonIcons"
require "TimedActions/SmokerActions"

ContainerButtonIcons.smoker = getTexture("media/ui/Container_Smoker.png")

-- In multiplayer the client also needs the meat-only rule, for the loot window.
MapObjects.OnLoadWithSprite(Smoker.spriteNames(), function(obj)
    if Smoker.isSmoker(obj) then Smoker.limitContainer(obj) end
end, 5)

local GOOD = " <RGB:0.45,0.8,0.4> "
local WARN = " <RGB:0.9,0.7,0.3> "
local BAD = " <RGB:0.9,0.4,0.35> "
local PLAIN = " <RGB:0.9,0.9,0.9> "
local MAX_LISTED = 10

-- Finding things ---------------------------------------------------------------------
local function reachable(playerObj)
    local out = { playerObj:getInventory() }
    local ok, list = pcall(ISInventoryPaneContextMenu.getContainers, playerObj)
    if ok and list then
        for i = 0, list:size() - 1 do
            local c, seen = list:get(i), false
            for _, have in ipairs(out) do
                if have == c then seen = true end
            end
            if not seen then table.insert(out, c) end
        end
    end
    return out
end

-- Every item in reach that passes test, carried first; the smoker's own chamber left out.
local function findAll(playerObj, smoker, test)
    local own, found, seen = smoker:getContainer(), {}, {}
    for _, c in ipairs(reachable(playerObj)) do
        if c ~= own then
            local carried = c == playerObj:getInventory() or c:isInCharacterInventory(playerObj)
            local items = carried and c:getAllEvalRecurse(test) or c:getAllEval(test)
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                if not seen[item:getID()] then
                    seen[item:getID()] = true
                    table.insert(found, item)
                end
            end
        end
    end
    return found
end

local function isStarter(item)
    local tagged = false
    pcall(function() tagged = item:hasTag(ItemTag.START_FIRE) end)
    local t = item:getType()
    if not (tagged or t == "Lighter" or t == "Matches") then return false end
    local uses = 1
    pcall(function() uses = item:getCurrentUses() end)
    return uses > 0
end

local function smokerIn(worldobjects)
    for _, obj in ipairs(worldobjects) do
        if Smoker.isSmoker(obj) then return obj end
        local square = obj:getSquare()
        if square then
            local objects = square:getObjects()
            for i = 0, objects:size() - 1 do
                if Smoker.isSmoker(objects:get(i)) then return objects:get(i) end
            end
        end
    end
    return nil
end

-- Walking and queueing -------------------------------------------------------------------
local function queueLength(playerObj)
    local q = ISTimedActionQueue.getTimedActionQueue(playerObj)
    return q and q.queue and #q.queue or 0
end

local function walksQueued(playerObj, from)
    local q = ISTimedActionQueue.getTimedActionQueue(playerObj)
    local list = q and q.queue or {}
    for i = from + 1, #list do
        if list[i].Type == "ISWalkToTimedAction" then return true end
    end
    return false
end

-- Fetch these into the inventory (walking to their containers if need be), then
-- go to the smoker. False if it can't be reached.
local function fetchThenGo(playerObj, smoker, items)
    local before = queueLength(playerObj)
    for _, item in ipairs(items) do
        ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
    end
    if walksQueued(playerObj, before) then
        local adjacent = AdjacentFreeTileFinder.Find(smoker:getSquare(), playerObj)
        if not adjacent then return false end
        ISTimedActionQueue.add(ISWalkToTimedAction:new(playerObj, adjacent))
        return true
    end
    return luautils.walkAdj(playerObj, smoker:getSquare(), true)
end

local function addFuel(playerObj, smoker, items)
    if fetchThenGo(playerObj, smoker, items) then
        for _, item in ipairs(items) do
            ISTimedActionQueue.add(SmokerAddFuelAction:new(playerObj, smoker, item))
        end
    end
end

local function light(playerObj, smoker, starter)
    if fetchThenGo(playerObj, smoker, { starter }) then
        ISTimedActionQueue.add(SmokerLightAction:new(playerObj, smoker, starter))
    end
end

local function putOut(playerObj, smoker)
    if luautils.walkAdj(playerObj, smoker:getSquare(), true) then
        ISTimedActionQueue.add(SmokerPutOutAction:new(playerObj, smoker))
    end
end

local function moveInto(playerObj, smoker, items, dest)
    if luautils.walkAdj(playerObj, smoker:getSquare(), true) then
        for _, item in ipairs(items) do
            ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, item, item:getContainer(), dest))
        end
    end
end

-- As many of these as the chamber has room for.
local function thatFit(playerObj, container, items)
    local room
    pcall(function() room = container:getEffectiveCapacity(playerObj) - container:getCapacityWeight() end)
    if not room then return items end
    local out, used = {}, 0
    for _, item in ipairs(items) do
        local w = item:getUnequippedWeight()
        if used + w <= room + 0.001 then
            table.insert(out, item)
            used = used + w
        end
    end
    return out
end

-- Text -----------------------------------------------------------------------------------
local function duration(hours)
    local mins = math.floor(hours * 60 + 0.5)
    local h, m = math.floor(mins / 60), mins % 60
    if h == 0 then return getText("IGUI_Smoker_Minutes", m) end
    if m == 0 then return getText("IGUI_Smoker_HoursOnly", h) end
    return getText("IGUI_Smoker_Hours", h, m)
end

local function fireLine(smoker)
    local fuel = Smoker.fuelHours(smoker)
    if Smoker.isLit(smoker) then return GOOD .. getText("IGUI_Smoker_StatusLit", duration(fuel)) end
    if fuel > 0 then return WARN .. getText("IGUI_Smoker_StatusOut", duration(fuel)) end
    return BAD .. getText("IGUI_Smoker_StatusEmpty")
end

local function itemLine(item)
    local stage = Smoker.stage(item)
    local name = item:getDisplayName()
    if Smoker.isFinished(stage) then return GOOD .. getText("IGUI_Smoker_ItemDone", name) end
    local hours, need = Smoker.progress(item)
    local pct = math.min(99, math.floor(hours / need * 100))
    if stage == "smoked" then
        return GOOD .. getText("IGUI_Smoker_ItemDrying", name, pct, duration(need - hours))
    end
    return PLAIN .. getText("IGUI_Smoker_ItemSmoking", name, pct, duration(need - hours))
end

local function statusText(smoker)
    local lines = { fireLine(smoker) }
    if not Smoker.isOutdoors(smoker) then table.insert(lines, BAD .. getText("IGUI_Smoker_NotOutdoors")) end
    local items = smoker:getContainer():getItems()
    local listed = 0
    if items:size() == 0 then
        table.insert(lines, PLAIN .. getText("IGUI_Smoker_Empty"))
    end
    for i = 0, items:size() - 1 do
        if listed < MAX_LISTED then
            table.insert(lines, itemLine(items:get(i)))
            listed = listed + 1
        end
    end
    if items:size() > MAX_LISTED then
        table.insert(lines, PLAIN .. getText("IGUI_Smoker_AndMore", items:size() - MAX_LISTED))
    end
    table.insert(lines, " <LINE> " .. PLAIN .. getText("IGUI_Smoker_HowItWorks",
        Smoker.SMOKED_HOURS, Smoker.DRIED_HOURS))
    return table.concat(lines, " <LINE> ")
end

local function tip(option, text)
    local t = ISInventoryPaneContextMenu.addToolTip()
    t.description = text
    option.toolTip = t
    return option
end

local function unavailable(option, text)
    option.notAvailable = true
    return tip(option, text)
end

-- The menu ---------------------------------------------------------------------------
local function fuelOptions(menu, playerObj, smoker)
    local room = Smoker.room(smoker)
    local option = menu:addOption(getText("ContextMenu_Smoker_AddFuel"))
    if room <= 0 then return unavailable(option, getText("IGUI_Smoker_Full")) end
    local fuel = findAll(playerObj, smoker, function(item) return Smoker.fuelValue(item) ~= nil end)
    if #fuel == 0 then return unavailable(option, getText("IGUI_Smoker_NoWood")) end

    local byType, order, hoursOf = {}, {}, {}
    for _, item in ipairs(fuel) do
        local t = item:getFullType()
        hoursOf[t] = Smoker.fuelValue(item)
        if not byType[t] then
            byType[t] = {}
            table.insert(order, t)
        end
        table.insert(byType[t], item)
    end
    table.sort(order, function(a, b) return hoursOf[a] > hoursOf[b] end)

    local sub = ISContextMenu:getNew(menu)
    menu:addSubMenu(option, sub)

    -- "Fill it": biggest pieces first, until the firebox is full.
    local fill, total = {}, 0
    for _, t in ipairs(order) do
        for _, item in ipairs(byType[t]) do
            if total + hoursOf[t] <= room + 0.001 then
                table.insert(fill, item)
                total = total + hoursOf[t]
            end
        end
    end
    if #fill > 1 then
        sub:addOption(getText("ContextMenu_Smoker_FillUp", #fill, duration(total)), playerObj, addFuel, smoker, fill)
    end
    for _, t in ipairs(order) do
        local items = byType[t]
        local text = getText("ContextMenu_Smoker_FuelItem", items[1]:getDisplayName(), #items, duration(hoursOf[t]))
        local o = sub:addOption(text, playerObj, addFuel, smoker, { items[1] })
        if hoursOf[t] > room + 0.001 then
            unavailable(o, getText("IGUI_Smoker_NoRoomFor", duration(room)))
        end
    end
    tip(option, getText("IGUI_Smoker_FuelTip", duration(Smoker.fuelHours(smoker)), duration(Smoker.MAX_FUEL_HOURS)))
end

local function fireOption(menu, playerObj, smoker)
    if Smoker.isLit(smoker) then
        menu:addOption(getText("ContextMenu_Smoker_PutOut"), playerObj, putOut, smoker)
        return
    end
    local starters = findAll(playerObj, smoker, isStarter)
    local option = menu:addOption(getText("ContextMenu_Smoker_Light"), playerObj, light, smoker, starters[1])
    local problem = Smoker.lightProblem(smoker)
    if problem then
        unavailable(option, getText(problem))
    elseif #starters == 0 then
        unavailable(option, getText("IGUI_Smoker_NoStarter"))
    end
end

local function loadOptions(menu, playerObj, smoker)
    local container = smoker:getContainer()
    local inv = playerObj:getInventory()
    local meat = {}
    local carried = inv:getAllEvalRecurse(function(item) return Smoker.canSmoke(item) and Smoker.stage(item) == "raw" end)
    for i = 0, carried:size() - 1 do table.insert(meat, carried:get(i)) end
    local fits = thatFit(playerObj, container, meat)
    local option = menu:addOption(getText("ContextMenu_Smoker_PutIn", #fits), playerObj, moveInto, smoker, fits, container)
    if #meat == 0 then
        unavailable(option, getText("IGUI_Smoker_NoMeat"))
    elseif #fits == 0 then
        unavailable(option, getText("IGUI_Smoker_ChamberFull"))
    elseif #fits < #meat then
        tip(option, getText("IGUI_Smoker_SomeFit", #fits, #meat))
    end

    local done = {}
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local stage = Smoker.stage(items:get(i))
        if stage == "smoked" or Smoker.isFinished(stage) then table.insert(done, items:get(i)) end
    end
    if #done > 0 then
        local o = menu:addOption(getText("ContextMenu_Smoker_TakeOut", #done), playerObj, moveInto, smoker, done, inv)
        if Smoker.isLit(smoker) then tip(o, getText("IGUI_Smoker_TakeOutTip", Smoker.DRIED_HOURS)) end
    end
end

Events.OnFillWorldObjectContextMenu.Add(function(player, context, worldobjects, test)
    local smoker = smokerIn(worldobjects)
    if not smoker then return end
    if test then return true end
    Smoker.limitContainer(smoker)
    local playerObj = getSpecificPlayer(player)
    local status = statusText(smoker)

    local root = context:addOption(getText("ContextMenu_Smoker"))
    tip(root, status)
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)

    tip(menu:addOption(getText("ContextMenu_Smoker_Status")), status)
    fuelOptions(menu, playerObj, smoker)
    fireOption(menu, playerObj, smoker)
    loadOptions(menu, playerObj, smoker)
end)

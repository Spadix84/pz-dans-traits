-- Base Unloader: the ways in. Right-click a container in the world, a vehicle,
-- or items in a loot window for "Unload to base"; right-click your own items
-- for "Put away what I'm carrying"; while a plan is saved, Resume and Forget
-- are on every one of those menus (one submenu builder serves them all, and
-- builds nothing when it would be empty). The world menu always has Base
-- zones and Base inventory; an item's menu says how many of it the base
-- holds. Any world container can also be renamed from here, which the loot
-- window then shows, and its categories set (or the container put off limits)
-- from the world, its loot-window icon or any item inside it; those edits are
-- the core's, shared with the window (BU_Window).

require "BaseUnloader_Scan"
require "BaseUnloader_Run"
require "BaseUnloader_UI"
require "BaseUnloader_Zones"
require "BaseUnloader_Stock"

local S = BU_Scan
BU_Menu = {}
local M = BU_Menu

local function openFor(player, source)
    if not source then return end
    BU_Window.open(player, source)
end

M.onUnloadObject = function(obj, player)
    local src = S.objectSource(obj, obj:getContainer(), nil)
    openFor(player, src)
end

M.onUnloadVehicle = function(vehicle, player)
    openFor(player, S.vehicleSource(vehicle))
end

M.onUnloadContainer = function(container, player)
    local parent
    pcall(function() parent = container:getParent() end)
    if parent and instanceof(parent, "BaseVehicle") then
        local part
        pcall(function() part = container:getVehiclePart() end)
        openFor(player, S.vehicleSource(parent, part))
    elseif parent then
        openFor(player, S.objectSource(parent, container, nil))
    end
end

M.onPutAway = function(player)
    openFor(player, S.selfSource(player))
end

M.onResume = function(player)
    BU_Run.resume(player)
end

M.onForget = function(player)
    BU_Run.forget(player)
end

M.onStop = function(player)
    BU_Run.stop(player)
end

M.onRenameObject = function(obj, playerNum)
    local container = obj:getContainer()
    local player = getSpecificPlayer(playerNum)
    local src = S.objectSource(obj, container, nil)
    if not src then return end
    local modal = ISTextBox:new(0, 0, 280, 180, getText("IGUI_BU_NameThis"), src.row.name, nil, M.onRenamed, playerNum, playerNum, src.row)
    modal:initialise()
    modal:addToUIManager()
end

M.onRenamed = function(_, button, playerNum, row)
    S.renamed(button, playerNum, row)
end

-- Categories and off limits from a menu (the container's row is built on the
-- spot): the edits are the core's, the same ones the window's own right-click
-- makes (BU_Window); afterwards the window open for this player, if any, redraws.
local function edit(fn)
    return function(row, playerNum, arg)
        fn(BaseUnloader.store(), row, arg)
        BU_Window.refresh(playerNum)
    end
end

M.onToggleTag = edit(function(store, row, cat) BaseUnloader.toggleTag(store, row.key, cat) end)
M.onTagFromContents = edit(function(store, row) BaseUnloader.tagByContents(store, row.key, row.cats) end)
M.onApplyLastTags = edit(function(store, row) BaseUnloader.applyLastTags(store, row.key) end)
M.onClearTags = edit(function(store, row) BaseUnloader.clearTags(store, row.key) end)
M.onSetOffLimits = edit(function(store, row, on) BaseUnloader.setOffLimits(store, row.key, on) end)

-- the Categories submenu and off limits for a world container, on any menu
function M.addContainerOptions(menu, row, playerNum)
    local store = BaseUnloader.store()
    local tags = store.tags
    local last = BaseUnloader.lastTagsFor(store, row.key)
    if last then
        menu:addOption(getText("IGUI_BU_ApplyLastTags", S.categoryNames(last)), row, M.onApplyLastTags, playerNum)
    end
    if (row.count or 0) > 0 then
        menu:addOption(getText("IGUI_BU_TagFromContents"), row, M.onTagFromContents, playerNum)
    end
    local option = menu:addOption(getText("IGUI_BU_Categories"), nil, nil)
    local sub = ISContextMenu:getNew(menu)
    menu:addSubMenu(option, sub)
    for _, cat in ipairs(S.categories(nil, { row })) do
        local on = BaseUnloader.hasTag(tags, row.key, cat)
        sub:addOption((on and "[x] " or "[  ] ") .. S.categoryLabel(cat), row, M.onToggleTag, playerNum, cat)
    end
    if #BaseUnloader.tagsOf(tags, row.key) > 0 then
        menu:addOption(getText("IGUI_BU_ClearTags"), row, M.onClearTags, playerNum)
    end
    if store.offLimits[row.key] then
        menu:addOption(getText("IGUI_BU_OffLimitsOff"), row, M.onSetOffLimits, playerNum, false)
    else
        menu:addOption(getText("IGUI_BU_OffLimitsOn"), row, M.onSetOffLimits, playerNum, true)
    end
end

-- the source for a loot-window container that belongs to a world object (a
-- cupboard, a crate, a fridge), nil for floors, bodies, bags and vehicles
local function worldSource(container)
    local src
    pcall(function()
        if container:getContainingItem() then return end
        local parent = container:getParent()
        if not parent or instanceof(parent, "BaseVehicle") or not parent.getSquare then return end
        local kind = container:getType()
        if kind == "floor" or kind == "inventorymale" or kind == "inventoryfemale" then return end
        src = S.objectSource(parent, container, nil)
    end)
    return src
end

-- the Resume / Stop / Forget options, when there is a plan
local function addPlanOptions(context, player)
    if BU_Run.isRunning(player) then
        context:addOption(getText("ContextMenu_BU_Stop"), player, M.onStop)
    elseif BU_Run.hasPlan(player) then
        context:addOption(getText("ContextMenu_BU_Resume"), player, M.onResume)
        context:addOption(getText("ContextMenu_BU_Forget"), player, M.onForget)
    end
end

M.onZones = function(player)
    BU_ZoneWindow.open(player)
end

M.onStock = function(player, search)
    BU_StockWindow.open(player, search)
end

-- the base zones and the base inventory, at the foot of the world menu
local function addBaseOptions(context, player)
    context:addOption(getText("ContextMenu_BU_Zones"), player, M.onZones)
    context:addOption(getText("ContextMenu_BU_Stock"), player, M.onStock)
end

-- The "Base Unloader" submenu, the same on every way in but for what comes
-- first: first(sub) adds that way's own options (Unload, Rename, Put away...),
-- then the categories and off limits of the world container `src` names, the
-- plan's Resume / Stop / Forget, and on the world menu (`base`) the zones and
-- the inventory. Not added at all when it would be empty: a floor or a body
-- with no plan saved gets no submenu.
local function addUnloaderMenu(context, player, playerNum, first, src, base)
    if not (first or src or base or BU_Run.isRunning(player) or BU_Run.hasPlan(player)) then return nil end
    local sub = ISContextMenu:getNew(context)
    local option = context:addOption(getText("ContextMenu_BU_Title"), nil, nil)
    context:addSubMenu(option, sub)
    if first then first(sub) end
    if src then M.addContainerOptions(sub, src.row, playerNum) end
    addPlanOptions(sub, player)
    if base then addBaseOptions(sub, player) end
    return sub
end

-- "At base: 12 (House 8, Shed 4)" for items all of one type, from the last
-- count of every base zone; click to open the base inventory searched for it
function M.addStockLine(context, player, item)
    local store = BaseUnloader.store()
    if #store.zones == 0 then return end
    local fullType, name
    pcall(function() fullType, name = item:getFullType(), item:getDisplayName() end)
    if not fullType then return end
    local total, byZone = BaseUnloader.stockCount(store.stock, fullType)
    local text
    if total == 0 then
        text = getText("ContextMenu_BU_AtBaseNone")
    else
        local parts = {}
        for i, z in ipairs(byZone) do
            if i > 3 then parts[#parts + 1] = "..."; break end
            parts[#parts + 1] = z.zone .. " " .. z.q
        end
        text = getText("ContextMenu_BU_AtBase", total, table.concat(parts, ", "))
    end
    context:addOption(text, player, M.onStock, name)
end

-- right-click in the world: the first container object under the cursor
function M.onWorldMenu(playerNum, context, worldobjects, test)
    if test then return end
    local player = getSpecificPlayer(playerNum)
    if not player or player:getVehicle() then return end
    local found
    for _, obj in ipairs(worldobjects) do
        local ok, has = pcall(function() return obj:getContainer() ~= nil and obj:getContainer():getType() ~= "floor" end)
        if ok and has and not found then found = obj end
    end
    local first, src = nil, nil
    if found then
        first = function(sub)
            sub:addOption(getText("ContextMenu_BU_Unload"), found, M.onUnloadObject, player)
            sub:addOption(getText("ContextMenu_BU_RenameContainer"), found, M.onRenameObject, playerNum)
        end
        src = S.objectSource(found, found:getContainer(), nil)
    end
    addUnloaderMenu(context, player, playerNum, first, src, true)
end

-- right-click items in an inventory window: the container they sit in
function M.onInventoryMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player or player:getVehicle() then return end
    local actual = ISInventoryPane.getActualItems(items)
    local first = actual[1]
    if not first then return end
    local container
    pcall(function() container = first:getContainer() end)
    if not container then return end
    -- how many of this at base, on the item's own menu: only when every item picked is the one type
    local oneType = true
    pcall(function()
        for _, it in ipairs(actual) do
            if it:getFullType() ~= first:getFullType() then oneType = false end
        end
    end)
    if oneType then M.addStockLine(context, player, first) end
    local mine = false
    pcall(function() mine = container:isInCharacterInventory(player) end)
    local own, src = nil, nil
    if mine then
        own = function(sub) sub:addOption(getText("ContextMenu_BU_PutAway"), player, M.onPutAway) end
    else
        local parent
        pcall(function() parent = container:getParent() end)
        if parent and (instanceof(parent, "BaseVehicle") or parent.getSquare) and container:getType() ~= "floor" then
            own = function(sub) sub:addOption(getText("ContextMenu_BU_Unload"), container, M.onUnloadContainer, player) end
        end
        src = worldSource(container)   -- the categories of the container the item sits in
    end
    addUnloaderMenu(context, player, playerNum, own, src, false)
end

Events.OnFillWorldObjectContextMenu.Add(M.onWorldMenu)
Events.OnFillInventoryObjectContextMenu.Add(M.onInventoryMenu)

-- right-click on a container icon in the loot window: vanilla builds the
-- player's context menu (Rename Bag and the admin tools); the Base Unloader
-- entries go on after it for a world container
local backpackRightMouseDown = ISInventoryPage.onBackpackRightMouseDown
ISInventoryPage.onBackpackRightMouseDown = function(button, x, y)
    local result = backpackRightMouseDown(button, x, y)
    pcall(function()
        local page = button.parent.parent
        local container = button.inventory
        local playerNum = page.player
        local player = getSpecificPlayer(playerNum)
        if not player or player:getVehicle() then return end
        local src = worldSource(container)
        if not src then return end
        addUnloaderMenu(getPlayerContextMenu(playerNum), player, playerNum, function(sub)
            sub:addOption(getText("ContextMenu_BU_Unload"), container, M.onUnloadContainer, player)
        end, src, false)
    end)
    return result
end

-- the vehicle menu is filled by a function, not an event: add to it after vanilla
local fillOutside = ISVehicleMenu.FillMenuOutsideVehicle
ISVehicleMenu.FillMenuOutsideVehicle = function(playerNum, context, vehicle, test)
    local result = fillOutside(playerNum, context, vehicle, test)
    if test then return result end
    local player = getSpecificPlayer(playerNum)
    if player and not player:getVehicle() and vehicle and S.vehiclePart(vehicle) then
        addUnloaderMenu(context, player, playerNum, function(sub)
            sub:addOption(getText("ContextMenu_BU_UnloadTrunk"), vehicle, M.onUnloadVehicle, player)
        end, nil, false)
    end
    return result
end

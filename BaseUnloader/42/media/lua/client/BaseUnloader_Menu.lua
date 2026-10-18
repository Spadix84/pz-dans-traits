-- Base Unloader: the ways in. Right-click a container in the world, a vehicle,
-- or items in a loot window for "Unload to base"; right-click your own items
-- for "Put away what I'm carrying"; while a plan is saved, Resume and Forget
-- are on every one of those menus. Any world container can also be renamed
-- from here, which the loot window then shows.

require "BaseUnloader_Scan"
require "BaseUnloader_Run"
require "BaseUnloader_UI"

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
    if button.internal ~= "OK" then return end
    local text = button.parent.entry:getText() or ""
    if text == row.kindLabel then text = "" end
    S.rename(row.container, row.key, text)
    pcall(function()
        local pdata = getPlayerData(playerNum)
        pdata.playerInventory:refreshBackpacks()
        pdata.lootInventory:refreshBackpacks()
    end)
end

-- categories from a menu: the container's row is built on the spot
M.onToggleTag = function(row, playerNum, cat)
    local tags = BaseUnloader.store().tags
    BaseUnloader.setTag(tags, row.key, cat, not BaseUnloader.hasTag(tags, row.key, cat))
    BU_Window.refresh(playerNum)
end

M.onTagFromContents = function(row, playerNum)
    BaseUnloader.tagFromContents(BaseUnloader.store().tags, row.key, row.cats)
    BU_Window.refresh(playerNum)
end

M.onClearTags = function(row, playerNum)
    BaseUnloader.store().tags[row.key] = nil
    BU_Window.refresh(playerNum)
end

-- the Categories submenu for a world container, on any menu
function M.addCategoryOptions(menu, row, playerNum)
    local tags = BaseUnloader.store().tags
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
    if found then
        local sub = ISContextMenu:getNew(context)
        local option = context:addOption(getText("ContextMenu_BU_Title"), nil, nil)
        context:addSubMenu(option, sub)
        sub:addOption(getText("ContextMenu_BU_Unload"), found, M.onUnloadObject, player)
        sub:addOption(getText("ContextMenu_BU_RenameContainer"), found, M.onRenameObject, playerNum)
        local src = S.objectSource(found, found:getContainer(), nil)
        if src then M.addCategoryOptions(sub, src.row, playerNum) end
        addPlanOptions(sub, player)
    elseif BU_Run.hasPlan(player) or BU_Run.isRunning(player) then
        local sub = ISContextMenu:getNew(context)
        local option = context:addOption(getText("ContextMenu_BU_Title"), nil, nil)
        context:addSubMenu(option, sub)
        addPlanOptions(sub, player)
    end
end

-- right-click items in an inventory window: the container they sit in
function M.onInventoryMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player or player:getVehicle() then return end
    local first = ISInventoryPane.getActualItems(items)[1]
    if not first then return end
    local container
    pcall(function() container = first:getContainer() end)
    if not container then return end
    local sub = ISContextMenu:getNew(context)
    local option = context:addOption(getText("ContextMenu_BU_Title"), nil, nil)
    context:addSubMenu(option, sub)
    local mine = false
    pcall(function() mine = container:isInCharacterInventory(player) end)
    if mine then
        sub:addOption(getText("ContextMenu_BU_PutAway"), player, M.onPutAway)
    else
        local parent
        pcall(function() parent = container:getParent() end)
        if parent and (instanceof(parent, "BaseVehicle") or parent.getSquare) and container:getType() ~= "floor" then
            sub:addOption(getText("ContextMenu_BU_Unload"), container, M.onUnloadContainer, player)
        end
    end
    addPlanOptions(sub, player)
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
        if container:getContainingItem() then return end
        local parent = container:getParent()
        if not parent or instanceof(parent, "BaseVehicle") or not parent.getSquare then return end
        local kind = container:getType()
        if kind == "floor" or kind == "inventorymale" or kind == "inventoryfemale" then return end
        local src = S.objectSource(parent, container, nil)
        if not src then return end
        local context = getPlayerContextMenu(playerNum)
        local sub = ISContextMenu:getNew(context)
        local option = context:addOption(getText("ContextMenu_BU_Title"), nil, nil)
        context:addSubMenu(option, sub)
        sub:addOption(getText("ContextMenu_BU_Unload"), container, M.onUnloadContainer, player)
        M.addCategoryOptions(sub, src.row, playerNum)
        addPlanOptions(sub, player)
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
        local sub = ISContextMenu:getNew(context)
        local option = context:addOption(getText("ContextMenu_BU_Title"), nil, nil)
        context:addSubMenu(option, sub)
        sub:addOption(getText("ContextMenu_BU_UnloadTrunk"), vehicle, M.onUnloadVehicle, player)
        addPlanOptions(sub, player)
    end
    return result
end

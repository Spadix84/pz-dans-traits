-- Dan's Vanilla Fixes: placed items stay put when you sweep up the floor
-- (the rule is in shared/DansVanillaFixes_Placed.lua).
--
--   Loot All            the floor's Loot All leaves placed items (and the
--                       button hides when they are all that is left)
--   Take Same Type      the floor's button leaves them too
--   Grab All / Half     the world right-click Grab submenu leaves them,
--                       unless every item of that kind is placed: then you
--                       picked them out on purpose and they come
--   list                a placed item's name is faded in the floor list
--   tooltip             "Placed: Loot All leaves it"
--   right-click         Keep in place / Let Loot All take it, for anything
--                       on the floor (an item dropped by accident, or one
--                       placed that you now want to sweep up)
--
-- Taking one by hand still works the vanilla way: drag it, double-click it,
-- Grab it on its own.
require "ISUI/ISInventoryPane"
require "ISUI/ISInventoryPaneContextMenu"
require "ISUI/ISWorldObjectContextMenu"
require "ISUI/LootWindow/Handlers/FloorTakeAll"
require "ISUI/LootWindow/Handlers/FloorTakeSameType"
require "DanShared_Tooltip"
require "DansVanillaFixes_ItemRarity"
require "DansVanillaFixes_Placed"

local P = DVF_Placed

P.FADE = 0.45   -- a placed item's name alpha, against the pane's own

-- Loot All ------------------------------------------------------------------------

-- ISInventoryPane:lootAll collects every item that is not Unwanted and hands
-- the list to transferItemsByWeight; while it runs, that list loses the
-- placed items. A heavy item alone on the floor is equipped instead, so that
-- is held back for a placed one too.
P.looting = 0

local wrapped = {}   -- the wrappers, so a class is never wrapped twice

local function wrapMethod(cls, name, make)
    local fn = type(cls) == "table" and rawget(cls, name)
    if type(fn) ~= "function" or wrapped[fn] then return end
    local w = make(fn)
    wrapped[w] = true
    cls[name] = w
end

function P.wrapPane(cls)
    wrapMethod(cls, "lootAll", function(vanilla)
        return function(self, ...)
            if not P.enabled() then return vanilla(self, ...) end
            P.looting = P.looting + 1
            local ok, err = pcall(vanilla, self, ...)
            P.looting = P.looting - 1
            if not ok then error(err) end
        end
    end)
    wrapMethod(cls, "transferItemsByWeight", function(vanilla)
        return function(self, items, container, ...)
            if P.looting > 0 and type(items) == "table" then items = P.withoutPlaced(items) end
            return vanilla(self, items, container, ...)
        end
    end)
end

wrapMethod(ISInventoryPaneContextMenu, "equipHeavyItem", function(vanilla)
    return function(playerObj, item, ...)
        if P.looting > 0 and P.isPlaced(item) then return end
        return vanilla(playerObj, item, ...)
    end
end)

-- the floor's Loot All button shows only while something would be taken
wrapMethod(ISLootWindowFloorControlHandler_TakeAll, "shouldBeVisible", function(vanilla)
    return function(self, ...)
        if not vanilla(self, ...) then return false end
        if not P.enabled() then return true end
        local items = self.container:getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if not item:isUnwanted(self.playerObj) and not P.isPlaced(item) then return true end
        end
        return false
    end
end)

-- Take Same Type (the floor's): the list it takes and the rows it lights up
wrapMethod(ISLootWindowFloorControlHandler_TakeSameType, "getItemsToTransfer", function(vanilla)
    return function(self, ...)
        local list, map = vanilla(self, ...)
        if not P.enabled() or type(list) ~= "table" then return list, map end
        local kept = P.withoutPlaced(list)
        if kept ~= list and type(map) == "table" then
            for _, item in ipairs(list) do
                if P.isPlaced(item) then map[item] = nil end
            end
        end
        return kept, map
    end
end)

-- Grab All / Grab Half -------------------------------------------------------------

-- WItems are the world items of one kind; the placed ones stay unless all are
function P.loose(WItems)
    if not P.enabled() or type(WItems) ~= "table" then return WItems end
    local out = {}
    for _, w in ipairs(WItems) do
        if not P.isPlaced(w:getItem()) then out[#out + 1] = w end
    end
    if #out == 0 then return WItems end
    return out
end

for _, name in ipairs({ "onGrabAllWItems", "onGrabHalfWItems" }) do
    wrapMethod(ISWorldObjectContextMenu, name, function(vanilla)
        return function(worldobjects, WItems, player, ...)
            return vanilla(worldobjects, P.loose(WItems), player, ...)
        end
    end)
end

-- the list: a placed item's name fades --------------------------------------------

-- drawn through renderdetails like the rarity colours (DVF_Rarity.nameRow
-- says which text is a name); a stack fades only when every copy is placed
function P.rowPlaced(items)
    local seen = false
    for _, item in ipairs(items) do
        if not P.isPlaced(item) then return false end
        seen = true
    end
    return seen
end

function P.wrapRender(cls)
    wrapMethod(cls, "renderdetails", function(vanilla)
        return function(self, doDragged, ...)
            if doDragged or not P.enabled() or not (self.inventory and self.inventory:getType() == "floor") then
                return vanilla(self, doDragged, ...)
            end
            local own = rawget(self, "drawText")
            local draw = self.drawText
            self.drawText = function(pane, text, x, y, r, g, b, a, font)
                local items = DVF_Rarity.nameRow(pane, text, x)
                if items and P.rowPlaced(items) then a = (a or 1) * P.FADE end
                return draw(pane, text, x, y, r, g, b, a, font)
            end
            local ok, res = pcall(vanilla, self, doDragged, ...)
            self.drawText = own
            if not ok then error(res) end
            return res
        end
    end)
end

-- CleanUI swaps the global ISInventoryPane between two classes of its own,
-- so every class a pane can come from is wrapped
function P.wrapPanes()
    for _, cls in ipairs({ ISInventoryPane, CleanUI_Clean_ISInventoryPane, CleanUI_Vanilla_ISInventoryPane }) do
        P.wrapPane(cls)
        P.wrapRender(cls)
    end
end

P.wrapPanes()

-- right-click ----------------------------------------------------------------------

local function onSet(items, on)
    for _, item in ipairs(items) do P.setPlaced(item, on) end
    ISInventoryPage.renderDirty = true
end

function P.onContextMenu(playerNum, context, items)
    if isClient() or not P.enabled() then return end
    local onFloor, allPlaced = {}, true
    for _, item in ipairs(ISInventoryPane.getActualItems(items)) do
        if item:getWorldItem() then
            onFloor[#onFloor + 1] = item
            if not P.isPlaced(item) then allPlaced = false end
        end
    end
    if #onFloor == 0 then return end
    if allPlaced then
        context:addOption(getText("ContextMenu_DVF_PlacedFree"), onFloor, onSet, false)
    else
        context:addOption(getText("ContextMenu_DVF_PlacedKeep"), onFloor, onSet, true)
    end
end

Events.OnFillInventoryObjectContextMenu.Add(P.onContextMenu)

-- tooltip --------------------------------------------------------------------------

DanShared_Tooltip.add("placed", 40, function(player, item)
    if P.enabled() and P.isPlaced(item) then
        return { { getText("IGUI_DVF_Placed"), 0.6, 0.75, 0.85 } }
    end
end)

local done = false
Events.OnGameStart.Add(function()
    if done then return end
    done = true
    pcall(P.wrapPanes)   -- CleanUI's classes exist by now
end)

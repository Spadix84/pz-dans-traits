-- Dan's Vanilla Fixes: items put down with Place Item stay where they are.
-- The rule lives here; Loot All, Grab All, Take Same Type, the faded name,
-- the tooltip line and the right-click toggle are in
-- client/DansVanillaFixes_PlacedClient.lua.
--
-- Telling a placed item from a dropped one needs no state of our own: the
-- game's Place Item action (ISDropWorldItemAction, used only by the place
-- cursor) sets the world item's ignoreRemoveSandbox flag, so the sandbox's
-- world-item cleanup leaves it alone, and the flag is saved with the item.
-- Items placed before this mod was on are therefore recognised too. A plain
-- drop (the inventory's Drop, dragging to the floor) never sets it.
--
-- The one other path that sets the flag is dropping an item out of a car
-- door (ISDropVehicleItemAction). Those are loose drops, so that action
-- marks the item DVF_Loose in its mod data first, and Place Item clears the
-- mark again. Picking an item up removes its world item, and with it the
-- flag, so nothing needs clearing then.
--
-- Right-click Keep in place / Let Loot All take it sets the flag by hand
-- (singleplayer; Dan's Vanilla Fixes is singleplayer only for now).
require "TimedActions/ISDropWorldItemAction"
require "TimedActions/ISDropVehicleItemAction"

DVF_Placed = DVF_Placed or {}
local P = DVF_Placed

function P.enabled()
    local o = SandboxVars and SandboxVars.DansVanillaFixes
    local v = o and o.PlacedItemsStay
    if v == nil then return true end
    return v == true
end

local function looseMark(item)
    if not item:hasModData() then return false end
    return item:getModData().DVF_Loose == true
end

-- the item is on the floor, put there with Place Item (or kept by hand)
function P.isPlaced(item)
    if not item then return false end
    local w = item:getWorldItem()
    if not w or not w:isIgnoreRemoveSandbox() then return false end
    return not looseMark(item)
end

-- a list (Lua array) without the placed items; the same list when it has none
function P.withoutPlaced(items)
    local out, dropped = {}, false
    for _, item in ipairs(items) do
        if P.isPlaced(item) then dropped = true else out[#out + 1] = item end
    end
    return dropped and out or items
end

-- by hand, from the right-click menu
function P.setPlaced(item, on)
    local w = item and item:getWorldItem()
    if not w then return end
    w:setIgnoreRemoveSandbox(on == true)
    if on and looseMark(item) then item:getModData().DVF_Loose = nil end
end

-- the drop actions --------------------------------------------------------------

if not ISDropWorldItemAction.dvfPlacedWrapped then
    ISDropWorldItemAction.dvfPlacedWrapped = true
    local vanilla = ISDropWorldItemAction.complete
    function ISDropWorldItemAction:complete()
        local item = self.item
        if item and looseMark(item) then item:getModData().DVF_Loose = nil end
        return vanilla(self)
    end
end

if not ISDropVehicleItemAction.dvfPlacedWrapped then
    ISDropVehicleItemAction.dvfPlacedWrapped = true
    local vanilla = ISDropVehicleItemAction.complete
    function ISDropVehicleItemAction:complete()
        -- before vanilla, so the mark goes out with the item it sends
        if self.item then self.item:getModData().DVF_Loose = true end
        return vanilla(self)
    end
end

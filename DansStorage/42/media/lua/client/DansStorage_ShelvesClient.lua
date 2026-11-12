-- Storage shelves in the loot window: the metal shelves' button icon for their container
-- types, and every shelf container listed gets its accept-item function before anything
-- can be dragged into it (on a multiplayer client this is the only place it is set).
--
-- After each item moves, the game's container overlays clear a shelf's overlay (they
-- don't know its tiles), so the shelves it moved between get theirs back straight after.
require "Definitions/ContainerButtonIcons"
require "TimedActions/ISInventoryTransferAction"
require "DansStorage_Shelves"

local Shelves = DansStorage.Shelves

if ContainerButtonIcons then
    for _, kind in ipairs(Shelves.KINDS) do
        if ContainerButtonIcons[kind.container] == nil then
            ContainerButtonIcons[kind.container] = ContainerButtonIcons.metal_shelves or ContainerButtonIcons.shelves
        end
    end
end

local function onRefresh(page, state)
    if state ~= "end" or not page or not page.backpacks then return end
    for _, button in ipairs(page.backpacks) do
        local container = button.inventory
        if container and Shelves.kindByContainer(container:getType()) then
            Shelves.ensure(container:getParent())
        end
    end
end

Events.OnRefreshInventoryWindowContainers.Add(onRefresh)

-- Wrapped once (a Lua reload finds the mark and leaves it).
local Transfer = ISInventoryTransferAction
if Transfer and type(Transfer.transferItem) == "function" and not Transfer.DansStorageWrapped then
    local original = Transfer.transferItem
    Transfer.transferItem = function(self, ...)
        local result = original(self, ...)
        -- ours never stops an item moving: an error here is printed and dropped
        local ok, err = pcall(Shelves.afterTransfer, self.srcContainer, self.destContainer)
        if not ok then print("DansStorage: shelf overlay: " .. tostring(err)) end
        return result
    end
    Transfer.DansStorageWrapped = true
end

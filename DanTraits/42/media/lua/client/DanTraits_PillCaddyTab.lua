-- The pill caddy gets its own tab in the inventory window while it is in the
-- main inventory, belt included. Vanilla only gives tabs to bags you wear or
-- hold (and key rings), and an item on the belt is neither.
-- OnRefreshInventoryWindowContainers is vanilla's hook for this: at
-- "buttonsAdded" every vanilla tab is in place (ISInventoryPage:refreshBackpacks).
require "DanTraits_PillCaddy"

local function onRefreshContainers(page, state)
    if state ~= "buttonsAdded" or not page.onCharacter then return end
    local playerObj = getSpecificPlayer(page.player)
    if not playerObj then return end
    local shown = {}
    for _, button in ipairs(page.backpacks or {}) do
        if button.inventory then shown[button.inventory] = true end
    end
    local items = playerObj:getInventory():getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if DanTraits_IsPillCaddy(item) then
            local inv = item:getInventory()
            if inv and not shown[inv] then
                page:addContainerButton(inv, item:getTex(), item:getName(), item:getName())
                shown[inv] = true
            end
        end
    end
end

if Events and Events.OnRefreshInventoryWindowContainers then
    Events.OnRefreshInventoryWindowContainers.Add(onRefreshContainers)
end

DanTraits_PillCaddyRefresh = onRefreshContainers   -- for the offline test

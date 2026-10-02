-- Project Zomboid Vitality Project: the Pill Caddy's tab in the inventory
-- window. Vanilla gives a tab only to bags you wear or hold (and key rings),
-- and a caddy on the belt is neither, so this adds one for every caddy loose
-- in the main inventory (on the belt or not) once vanilla's buttons are in.
-- A caddy held in the hands already has its tab; one inside a bag has none.

local function hasButton(page, container)
    for _, button in ipairs(page.backpacks) do
        if button.inventory == container then return true end
    end
    return false
end

local function onRefreshContainers(page, state)
    if state ~= "buttonsAdded" or not page.onCharacter then return end
    local player = getSpecificPlayer(page.player)
    if not player then return end
    local items = player:getInventory():getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if DanTraits_IsPillCaddy(item) and not hasButton(page, item:getInventory()) then
            page:addContainerButton(item:getInventory(), item:getTex(), item:getName(), item:getName())
        end
    end
end

Events.OnRefreshInventoryWindowContainers.Add(onRefreshContainers)

-- Project Zomboid Vitality Project: the Pill Caddy's tab in the inventory
-- window. Vanilla gives a tab only to bags you wear or hold (and key rings),
-- and a caddy on the belt is neither, so this adds one for every caddy loose
-- in the main inventory (on the belt or not) once vanilla's buttons are in.
-- A caddy held in the hands already has its tab; one inside a bag has none.
--
-- On the belt, the game makes the character the caddy's parent
-- (IsoGameCharacter.setAttachedItem sets the attached container's parent to
-- the character; no vanilla container is attachable, so nothing in the game
-- minds). A container whose parent is a character reports the character's
-- whole carried weight (ItemContainer.getCapacityWeight) and skips the
-- Organized bonus (getEffectiveCapacity), so the tab read "12.3 / 1". A
-- worn bag's own container has no parent; the caddy's is cleared here
-- before its button is made, and again whenever the window refreshes.

local function hasButton(page, container)
    for _, button in ipairs(page.backpacks) do
        if button.inventory == container then return true end
    end
    return false
end

-- the caddy's own container must not have the character as its parent
local function unparent(container, player)
    pcall(function()
        if container:getParent() == player then container:setParent(nil) end
    end)
end

local function onRefreshContainers(page, state)
    if state ~= "buttonsAdded" or not page.onCharacter then return end
    local player = getSpecificPlayer(page.player)
    if not player then return end
    local items = player:getInventory():getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if DanTraits_IsPillCaddy(item) then
            local container = item:getInventory()
            unparent(container, player)
            if not hasButton(page, container) then
                page:addContainerButton(container, item:getTex(), item:getName(), item:getName())
            end
        end
    end
end

Events.OnRefreshInventoryWindowContainers.Add(onRefreshContainers)

-- Project Zomboid Vitality Project: Jinxed.
require "DanTraits"

local hasTrait = DanTraits_HasTrait

-- Jinxed --------------------------------------------------------------------
-- Fires as containers are populated, which can happen before a player exists,
-- hence the guard.
local JINX_CHANCE = 35    -- percent, per container filled

local function onFillContainer(roomName, containerType, container)
    if not container or not instanceof(container, "ItemContainer") then return end   -- the game sometimes passes a loot-table entry
    local player = getSpecificPlayer(0)
    if not player or not hasTrait(player, "jinxed") then return end
    if ZombRand(100) >= JINX_CHANCE then return end

    local items = container:getItems()
    if not items or items:size() == 0 then return end

    local item = items:get(ZombRand(items:size()))
    -- never an item the mod placed on purpose (A Really Bad Day's sewing kit)
    local keep = false
    pcall(function() keep = item:getModData().DanTraitsKeep == true end)
    if item and not keep then pcall(function() container:Remove(item) end) end
end

Events.OnFillContainer.Add(onFillContainer)

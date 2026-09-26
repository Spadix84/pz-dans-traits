-- Project Zomboid Vitality Project: Jinxed.
require "DanTraits"

local hasTrait = DanTraits_HasTrait

-- Jinxed --------------------------------------------------------------------
-- Fires as containers are populated, which can happen before a player exists,
-- hence the guard.
local JINX_CHANCE = 35    -- percent, per container filled

local function onFillContainer(roomName, containerType, container)
    if not container then return end
    local player = getSpecificPlayer(0)
    if not player or not hasTrait(player, "jinxed") then return end
    if ZombRand(100) >= JINX_CHANCE then return end

    local items = container:getItems()
    if not items or items:size() == 0 then return end

    local item = items:get(ZombRand(items:size()))
    if item then pcall(function() container:Remove(item) end) end
end

Events.OnFillContainer.Add(onFillContainer)

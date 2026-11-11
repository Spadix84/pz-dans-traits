-- Finds cookers as they load or get placed, and runs them once a game minute.
-- server/ runs in singleplayer and on a multiplayer host, where food cooks.
require "SlowCooker_Core"
require "SlowCooker_Power"

local function onObject(obj)
    if SlowCooker.isCooker(obj) then
        SlowCooker.register(obj)
    end
end

-- A cooker found as loot comes with its crock. (Placing or moving one doesn't
-- make a crock: the crock is a separate item, so it can't be duplicated.)
local function onFill(roomName, containerType, container)
    if not container or not instanceof(container, "ItemContainer") then return end   -- the game sometimes passes a loot-table entry
    if container:contains("Base.Mov_SlowCooker") and not container:contains(SlowCooker.CROCK) then
        container:AddItem(SlowCooker.CROCK)
    end
end

MapObjects.OnLoadWithSprite(SlowCooker.spriteNames(), onObject, 5)
Events.OnObjectAdded.Add(onObject)
Events.EveryOneMinute.Add(SlowCooker.tick)
Events.OnFillContainer.Add(onFill)

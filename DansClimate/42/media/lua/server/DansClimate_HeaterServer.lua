-- Space heaters as the world loads and changes. A heater joins the list when its chunk
-- loads (MapObjects) or it is put down, and gets its glow and its warmth back then: the
-- game saves neither. Every ten game minutes each one is looked at again: it switches
-- itself off when its power goes (the grid shuts down, the generator runs dry), and its
-- elements cut in and out with the room. A heater that was picked up or unloaded drops
-- off the list and takes its warmth with it. Every minute the glow is looked at alone:
-- the furniture tools turn a heater by changing its sprite in place, with no event, and
-- the glow has to turn with it.
if isClient() then return end
require "DansClimate_Heater"

local Heater = DansClimate.Heater
Heater.loaded = Heater.loaded or setmetatable({}, { __mode = "k" })

local function track(obj)
    if not Heater.isUnit(obj) then return end
    Heater.loaded[obj] = true
    Heater.restore(obj)
    Heater.syncOverlay(obj)
    Heater.syncHeat(obj)
    DansClimate.Climate.track(obj:getSquare())
end

local function untrack(obj)
    if not Heater.loaded[obj] then return end
    Heater.loaded[obj] = nil
    Heater.forget(obj)
    -- it is still on its square for a moment: the room looks again next minute
    DansClimate.Climate.refresh(obj:getSquare())
end

-- A unit whose chunk has just unloaded is still an object for a moment (the chunk
-- waits in the save queue), but its square has no chunk, so no power and no room:
-- judged then, it read as "power gone" and was switched off, and that is what was
-- saved. It is off the list instead, as it was left.
local function unloaded(unit)
    local sq = unit:getSquare()
    return sq == nil or (sq.getChunk ~= nil and sq:getChunk() == nil)
end

function Heater.check()
    for unit in pairs(Heater.loaded) do
        if unit:getObjectIndex() == -1 or not Heater.isUnit(unit) or unloaded(unit) then
            Heater.loaded[unit] = nil
            Heater.forget(unit)
        elseif Heater.isOn(unit) and not Heater.isPowered(unit) then
            Heater.setOn(unit, false)
        else
            Heater.syncOverlay(unit)
            Heater.syncHeat(unit)
        end
    end
end

function Heater.glow()
    for unit in pairs(Heater.loaded) do
        if unit:getObjectIndex() ~= -1 and not unloaded(unit) then Heater.syncOverlay(unit) end
    end
end

MapObjects.OnLoadWithSprite(Heater.spriteNames(), track, 5)
Events.OnObjectAdded.Add(track)
Events.OnObjectAboutToBeRemoved.Add(untrack)
Events.EveryTenMinutes.Add(Heater.check)
Events.EveryOneMinute.Add(Heater.glow)

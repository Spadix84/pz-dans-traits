-- Furnaces, central air conditioners and vents as the world loads and changes. One
-- joins the list when its chunk loads (MapObjects) or it is built, and the Java side is
-- told: it remembers a central air conditioner (which stands outdoors, where no room
-- scan finds it), gives it its hum, and looks at the building again. Every ten game
-- minutes each unit gets the look that matches what it is doing, and every few game
-- minutes a working central air conditioner hums for the zombies.
--
-- Unlike a space heater, a unit doesn't switch itself off when its power goes: it is
-- the thermostat's to run, and picks up again when the generator does.
if isClient() then return end
require "DansClimate_Climate"
require "DansClimate_Central"

local Central = DansClimate.Central
Central.loaded = Central.loaded or setmetatable({}, { __mode = "k" })

local function track(obj)
    if not Central.kind(obj) then return end
    Central.loaded[obj] = true
    local sq = obj:getSquare()
    DansClimate.Climate.track(sq)
    DansClimate.Climate.refresh(sq)
    Central.syncOverlay(obj)
end

local function untrack(obj)
    if not Central.loaded[obj] then return end
    Central.loaded[obj] = nil
    -- it is still on its square for a moment: the building looks again next minute
    DansClimate.Climate.refresh(obj:getSquare())
end

local function gone(obj)
    return obj:getObjectIndex() == -1 or not Central.kind(obj)
end

function Central.check()
    for obj in pairs(Central.loaded) do
        if gone(obj) then
            Central.loaded[obj] = nil
        else
            Central.syncOverlay(obj)
        end
    end
end

local minutes = 0

-- every game minute: each HUM_MINUTES, the working central air conditioners hum
function Central.humAll()
    minutes = minutes + 1
    if minutes < Central.HUM_MINUTES then return end
    minutes = 0
    for obj in pairs(Central.loaded) do
        if not gone(obj) then Central.hum(obj) end
    end
end

MapObjects.OnLoadWithSprite(Central.spriteNames(), track, 5)
Events.OnObjectAdded.Add(track)
Events.OnObjectAboutToBeRemoved.Add(untrack)
Events.EveryTenMinutes.Add(Central.check)
Events.EveryOneMinute.Add(Central.humAll)

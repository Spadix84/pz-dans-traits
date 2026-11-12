-- Window air conditioners as the world loads and runs. A unit joins the list when its
-- chunk loads (MapObjects) or it is installed, and the Java side is told, which gives
-- it the hum the player hears. Every ten game minutes each one is checked: it switches
-- itself off when its power goes (the grid shuts down, the generator runs dry or is
-- switched off). And every few game minutes a running unit hums for the zombies: a
-- world sound they turn towards (AC.hum; the sandbox sets how far it carries).
if isClient() then return end
require "DansClimate_Climate"
require "DansClimate_WindowAC"

local AC = DansClimate.WindowAC
AC.loaded = AC.loaded or setmetatable({}, { __mode = "k" })

local function track(obj)
    if not AC.isUnit(obj) then return end
    AC.loaded[obj] = true
    DansClimate.Climate.track(obj:getSquare())
end

-- A unit whose chunk has just unloaded is still an object for a moment (the chunk
-- waits in the save queue), but its square has no chunk, so no power and no room:
-- judged then, it read as "power gone" and was switched off, and that is what was
-- saved. It is off the list instead, as it was left.
local function unloaded(unit)
    local sq = unit:getSquare()
    return sq == nil or (sq.getChunk ~= nil and sq:getChunk() == nil)
end

local function gone(unit)
    return unit:getObjectIndex() == -1 or not AC.isUnit(unit) or unloaded(unit)
end

function AC.checkPower()
    for unit in pairs(AC.loaded) do
        if gone(unit) then
            AC.loaded[unit] = nil
        -- no power, or no window any more (smashed out, the wall taken down): a unit
        -- left running there cooled nothing and still hummed, drew fuel and called zombies
        elseif AC.isOn(unit) and (not AC.isPowered(unit) or not AC.windowOf(unit)) then
            AC.setOn(unit, false)
        end
    end
end

local minutes = 0

-- every game minute: each HUM_MINUTES, the running units hum
function AC.humAll()
    minutes = minutes + 1
    if minutes < AC.HUM_MINUTES then return end
    minutes = 0
    for unit in pairs(AC.loaded) do
        if not gone(unit) then AC.hum(unit) end
    end
end

MapObjects.OnLoadWithSprite(AC.spriteNames(), track, 5)
Events.OnObjectAdded.Add(track)
Events.EveryTenMinutes.Add(AC.checkPower)
Events.EveryOneMinute.Add(AC.humAll)

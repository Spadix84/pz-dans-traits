-- Units switch themselves off when their power goes: the grid shuts down, the
-- generator runs dry or is switched off. Every loaded unit is checked each ten game
-- minutes; units load with their chunk (MapObjects) or are installed while it's loaded.
if isClient() then return end
require "DansClimate_WindowAC"

local AC = DansClimate.WindowAC
AC.loaded = AC.loaded or setmetatable({}, { __mode = "k" })

local function track(obj)
    if AC.isUnit(obj) then AC.loaded[obj] = true end
end

function AC.checkPower()
    for unit in pairs(AC.loaded) do
        if unit:getObjectIndex() == -1 or not AC.isUnit(unit) then
            AC.loaded[unit] = nil
        elseif AC.isOn(unit) and not AC.isPowered(unit) then
            AC.setOn(unit, false)
        end
    end
end

MapObjects.OnLoadWithSprite(AC.spriteNames(), track, 5)
Events.OnObjectAdded.Add(track)
Events.EveryTenMinutes.Add(AC.checkPower)

-- Project Zomboid Vitality Project: clotheslines on the map get their
-- container as they load (shared/DanTraits_LaundryDry.lua has the rest). The
-- posts near the player are given one every ten minutes anyway; this only
-- makes it ready before anyone walks up. Built ones are posts too.
if isClient() then return end
require "DanTraits_LaundryDry"

local PRIORITY = 5

local function give(obj)
    local L = DanTraits_Laundry
    if L and L.linesOn and L.linesOn() then L.ensureLine(obj) end
end

if MapObjects and MapObjects.OnNewWithSprite then
    for name in pairs(DanTraits_Laundry.LINE_SPRITES) do
        MapObjects.OnNewWithSprite(name, give, PRIORITY)
        MapObjects.OnLoadWithSprite(name, give, PRIORITY)
    end
end

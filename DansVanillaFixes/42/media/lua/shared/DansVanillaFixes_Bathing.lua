-- Dan's Vanilla Fixes: Take A Bath And Shower (TakeABathAndShowerNew) compatibility.
--
-- Does nothing unless Take A Bath And Shower is loaded. No dependency either way.
--
-- That mod washes the clothes you bathe or shower in, a little each tick,
-- all the way to spotless (TABAS_BathingUtils.cleaningWornItems). The
-- hand-wash floors of DansVanillaFixes_Washing.lua apply there too: a patch
-- of blood or dirt never goes under the soap floor with soap or shampoo to
-- hand (a bar in the inventory, or the shower's own soap list), nor under
-- the no-soap floor without; a patch already under its floor is left where
-- it was. Only a washing machine gets a garment fully clean, bath or no bath.
-- Its own objects (the tub's water, the towel) and the body are untouched.
require "DansVanillaFixes_Washing"

local installed = false

-- soap or shampoo to hand: the game's soap list, or the shower's
local function soapToHand(character)
    local any = false
    pcall(function()
        local list = character:getInventory():getSoapList(nil, false)
        if list and ISWashClothing and ISWashClothing.GetSoapRemaining and ISWashClothing.GetSoapRemaining(list) > 0 then any = true end
    end)
    if not any and TABAS_TakeShower and TABAS_TakeShower.getSoaps then
        pcall(function()
            local _, total = TABAS_TakeShower.getSoaps(character)
            if (tonumber(total) or 0) > 0 then any = true end
        end)
    end
    return any
end

local function install()
    if installed then return end
    local U = TABAS_BathingUtils
    if type(U) ~= "table" or type(U.cleaningWornItems) ~= "function" then return end
    installed = true
    local original = U.cleaningWornItems
    U.cleaningWornItems = function(character, wornItems, pct, factor, ...)
        local W = DVF_Washing
        local snaps = {}
        pcall(function()
            local worn = wornItems or character:getWornItems()
            for i = 0, worn:size() - 1 do
                local item = worn:get(i):getItem()
                if item and W.handles(item) then snaps[#snaps + 1] = { item = item, snap = W.snapshot(item) } end
            end
        end)
        local a, b, c, d = original(character, wornItems, pct, factor, ...)
        if #snaps > 0 then
            local floor = W.floor(soapToHand(character))
            for _, e in ipairs(snaps) do pcall(function() W.restore(e.item, e.snap, floor) end) end
        end
        return a, b, c, d
    end
    print("[DansVanillaFixes] Take A Bath And Shower found: the hand-wash floors apply to clothes washed in the bath")
end
DVF_BathingInstall = install   -- tests

Events.OnGameStart.Add(install)

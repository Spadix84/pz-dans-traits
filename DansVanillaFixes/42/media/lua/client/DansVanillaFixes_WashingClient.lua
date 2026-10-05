-- Dan's Vanilla Fixes: the wash menu side of hand washing
-- (shared/DansVanillaFixes_Washing.lua has the floors).
--
-- The game builds the Wash and Wash All options in Java and hands the
-- garments to ISWorldObjectContextMenu.onWashClothing. Garments that a hand
-- wash here could not get any cleaner are taken out before anything is
-- queued, so Wash All does not walk over and spend water and time on them;
-- if that leaves nothing, the character says why and stays put. The action
-- checks again when it finishes, since the soap can run out part way through.

require "ISUI/ISWorldObjectContextMenu"
require "DansVanillaFixes_Washing"

local W = DVF_Washing

local vanillaOnWash = ISWorldObjectContextMenu.onWashClothing
ISWorldObjectContextMenu.onWashClothing = function(playerObj, sink, soapList, washList, singleClothing)
    local soap = false
    pcall(function() soap = soapList ~= nil and ISWashClothing.GetSoapRemaining(soapList) > 0 end)
    local floor = W.floor(soap)
    local keep = {}
    for _, item in ipairs(washList or { singleClothing }) do
        if W.canGain(item, floor) then keep[#keep + 1] = item end
    end
    if #keep == 0 then
        W.message(playerObj, soap)
        return
    end
    return vanillaOnWash(playerObj, sink, soapList, keep, nil)
end

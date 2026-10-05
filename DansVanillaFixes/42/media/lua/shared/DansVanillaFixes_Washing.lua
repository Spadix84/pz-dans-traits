-- Dan's Vanilla Fixes: washing clothes by hand.
--
-- Vanilla's hand wash (ISWashClothing) takes every patch of blood and dirt to
-- zero at any water source, soap or not; soap only makes it quicker. Here a
-- hand wash only gets a garment so clean:
--
--   no soap     each patch of blood and dirt down to 40% (WashFloorNoSoap)
--   soap        down to 20% (WashFloorSoap)
--   a washer    all the way: washing machines and combo washer/dryers run
--               their own cycle in Java and are not touched here
--
-- A patch already under the floor stays as it is: washing never makes
-- anything dirtier. A garment with nothing left to gain is not washed at all
-- (no water, no soap, no soaking) and says why.
--
-- The game keeps blood and dirt per body part on the item's visual and works
-- out the garment's overall Dirty and Bloody figures as the average of the
-- parts (BloodClothingType.calcTotalDirtLevel/calcTotalBloodLevel), so the
-- floors go on the parts and the totals are counted again afterwards.
--
-- Only clothing and bags. Bandages and rags (which turn into clean ones) and
-- blood on weapons wash as in vanilla. The menu side (skipping what cannot
-- get cleaner before it is queued) is in client/DansVanillaFixes_WashingClient.lua.

require "TimedActions/ISWashClothing"

DVF_Washing = DVF_Washing or {}
local W = DVF_Washing

W.DEFAULT_NO_SOAP = 40   -- % per patch a soapless hand wash cannot get under
W.DEFAULT_SOAP = 20      -- % with soap
W.EPS = 0.005            -- a patch this close to the floor counts as at it

-- the floor for a hand wash, as a share (0..1)
function W.floor(soap)
    local opts = SandboxVars and SandboxVars.DansVanillaFixes
    local v = opts and tonumber(opts[soap and "WashFloorSoap" or "WashFloorNoSoap"])
    if v == nil then v = soap and W.DEFAULT_SOAP or W.DEFAULT_NO_SOAP end
    return math.max(0, math.min(100, v)) / 100
end

-- clothing and bags carry blood and dirt per body part; everything else washes as vanilla
function W.handles(item)
    return item ~= nil and (instanceof(item, "Clothing") or instanceof(item, "InventoryContainer"))
end

-- { { part = BloodBodyPartType, blood = 0..1, dirt = 0..1 }, ... }
function W.snapshot(item)
    local out = {}
    local covered = item:getBloodClothingType() and BloodClothingType.getCoveredParts(item:getBloodClothingType())
    if not covered then return out end
    for i = 0, covered:size() - 1 do
        local part = covered:get(i)
        out[#out + 1] = { part = part, blood = item:getBlood(part) or 0, dirt = item:getDirt(part) or 0 }
    end
    return out
end

-- would a wash with this floor take anything off?
function W.canGain(item, floor)
    if not W.handles(item) then return true end
    for _, p in ipairs(W.snapshot(item)) do
        if p.blood > floor + W.EPS or p.dirt > floor + W.EPS then return true end
    end
    return false
end

-- the garment's overall figures, from its parts as the game counts them
local function recount(item, snap)
    if not instanceof(item, "Clothing") then return end
    local ok = pcall(function()
        BloodClothingType.calcTotalBloodLevel(item)
        BloodClothingType.calcTotalDirtLevel(item)
    end)
    if ok or #snap == 0 then return end
    local blood, dirt = 0, 0
    for _, p in ipairs(snap) do
        blood = blood + item:getBlood(p.part)
        dirt = dirt + item:getDirt(p.part)
    end
    item:setBloodLevel(blood / #snap * 100)
    item:setDirtiness(dirt / #snap * 100)
end

-- after vanilla has scrubbed it to nothing: each patch back up to the floor,
-- or to what it was if that was already less
function W.restore(item, snap, floor)
    for _, p in ipairs(snap) do
        item:setBlood(p.part, math.min(p.blood, floor))
        item:setDirt(p.part, math.min(p.dirt, floor))
    end
    recount(item, snap)
end

function W.message(player, soap)
    if not player or not HaloTextHelper then return end
    pcall(function()
        HaloTextHelper.addBadText(player, getText(soap and "IGUI_DVF_WashNeedsMachine" or "IGUI_DVF_WashNeedsSoap"))
    end)
end

-- for play-testing from the console: every carried garment with blood or dirt,
-- as "name dirt%/blood%" (the game's own totals)
function W.report(player)
    local out = {}
    local items = player:getInventory():getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if instanceof(it, "Clothing") and (it:getDirtiness() > 0 or it:getBloodlevel() > 0) then
            out[#out + 1] = string.format("%s %d/%d", it:getName(), math.floor(it:getDirtiness() + 0.5), math.floor(it:getBloodlevel() + 0.5))
        end
    end
    if #out == 0 then return "nothing dirty carried" end
    return table.concat(out, "; ")
end

-- the action: floors after vanilla's scrub, and no wash at all when nothing would come off
local vanillaComplete = ISWashClothing.complete
function ISWashClothing:complete()
    local item = self.item
    if not W.handles(item) then return vanillaComplete(self) end
    local soap = self.noSoap == false
    local floor = W.floor(soap)
    if not W.canGain(item, floor) then
        W.message(self.character, soap)
        return true
    end
    local snap = W.snapshot(item)
    local result = vanillaComplete(self)
    W.restore(item, snap, floor)
    pcall(function()
        syncItemFields(self.character, item)
        syncVisuals(self.character)
    end)
    return result
end

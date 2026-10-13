-- Project Zomboid Vitality Project: laundry, the washing and wringing actions.
-- (DanTraits_Laundry.lua has the state and the numbers; this file only hooks
-- the game's two actions.) Moved here from Dan's Vanilla Fixes on 2026-10-11.
--
-- Vanilla's hand wash (ISWashClothing) takes every patch of blood and dirt to
-- zero at any water source, soap or not; soap only makes it quicker. With
-- laundry on, a hand wash only gets a garment so clean:
--
--   by hand      no soap: each patch down to 40% (LaundryHandFloor)
--                soap or cleaning liquid: 20% (LaundryHandSoapFloor)
--   washboard    carried: 25% / 10% (LaundryBoardFloor / LaundryBoardSoapFloor),
--                1.5x as long
--   a washer     all the way, but never under a set-in stain
--                (DanTraits_Laundry.lua: the machine's own cycle is Java)
--
-- A patch already under the floor stays as it is: washing never makes
-- anything dirtier. A set-in stain is a floor of its own for that part's
-- blood. Odour comes out too (soapless by hand: down to 30; anything else:
-- all of it), musty clothes are fresh again, and the wash may cost the
-- fabric a condition point (LaundryWear). A garment with nothing to gain is
-- not washed at all (no water, no soap, no soaking) and says why.
--
-- Wringing (ISWringClothing) leaves a garment damp: it stops at
-- LaundryWringLeaves (shoes 70) instead of 10, so it saves time but not the
-- drying. It is not offered at or under that line.
--
-- Only clothing and bags. Bandages and rags (which turn into clean ones) and
-- blood on weapons wash as in vanilla. The menu side (skipping what cannot
-- get cleaner before it is queued) is in client/DanTraits_LaundryClient.lua.
require "DanTraits_Laundry"
require "TimedActions/ISWashClothing"
require "TimedActions/ISWringClothing"

local L = DanTraits_Laundry

L.BOARD_TIME = 1.5   -- a washboard wash takes this much longer
L.BOARD_TYPE = "DanTraits.Washboard"

-- does the character carry a washboard (bags included)
function L.hasBoard(character)
    local found = false
    pcall(function()
        local inv = character:getInventory()
        found = inv:getFirstTypeRecurse(L.BOARD_TYPE) ~= nil
    end)
    if not found then
        pcall(function() found = character:getInventory():containsTypeRecurse(L.BOARD_TYPE) == true end)
    end
    return found
end

function L.methodFor(character)
    return L.hasBoard(character) and "board" or "hand"
end

function L.message(player, method, soap, key)
    if not player or not HaloTextHelper then return end
    if not key then
        if method == "board" then key = soap and "IGUI_DanTraits_WashNeedsMachine" or "IGUI_DanTraits_WashNeedsSoap"
        else key = soap and "IGUI_DanTraits_WashNeedsBoard" or "IGUI_DanTraits_WashNeedsSoap" end
    end
    pcall(function() HaloTextHelper.addBadText(player, getText(key)) end)
end

-- bleach ---------------------------------------------------------------------------
-- Vanilla never puts bleach on clothes, and its soap list leaves it out on
-- purpose: ISWashClothing.useSoap would drain any fluid container handed to it.
-- So bleach has its own action (ISLaundryAction "bleach") and these helpers.

L.BLEACH_LITRES = 0.1   -- per garment

local function bleachFluid() return Fluid and Fluid.Bleach end

-- litres of bleach in a container (0 when it holds none or is not one)
function L.bleachLeft(item)
    local litres = 0
    pcall(function()
        local fc = item:getFluidContainer()
        if fc and fc:contains(bleachFluid()) then litres = fc:getAmount() or 0 end
    end)
    return litres
end

-- the carried container with the most bleach in it (bags included), or nil
function L.findBleach(character)
    local best, most = nil, 0
    for _, item in ipairs(L.carried(character)) do
        local litres = L.bleachLeft(item)
        if litres > most then best, most = item, litres end
    end
    if most < L.BLEACH_LITRES - 0.001 then return nil end
    return best
end

function L.useBleach(item)
    pcall(function()
        local fc = item:getFluidContainer()
        local left = fc:getAmount() - L.BLEACH_LITRES
        if left <= 0.001 then fc:Empty() else fc:adjustAmount(left) end
        if sendItemStats then sendItemStats(item) end
    end)
end

-- water a wash of this garment takes (vanilla's own figure)
function L.waterFor(item)
    local water = 4
    pcall(function() water = ISWashClothing.GetRequiredWater(item) end)
    return water
end

local function wrapWashing()
    -- the floors after vanilla's scrub, and no wash at all when nothing would come off
    DanTraits_Wrap(ISWashClothing, "complete", "laundry-floors", function(original, self, ...)
        local item = self.item
        if not L.on() or not L.handles(item) then return original(self, ...) end
        local soap = self.noSoap == false
        local method = L.methodFor(self.character)
        local skilled = L.skilled(self.character)
        if not L.canGain(item, method, soap, skilled) then
            L.message(self.character, method, soap)
            return true
        end
        local snap = L.snapshot(item)
        local bloody = L.wasBloody(item)
        local result = original(self, ...)
        L.afterHandWash(item, snap, method, soap, skilled)
        pcall(function()
            syncItemFields(self.character, item)
            syncVisuals(self.character)
        end)
        DanTraits_RunHooks("laundryWashed", nil, self.character, item, method, bloody)
        return result
    end)

    -- scrubbing on a washboard takes longer
    DanTraits_Wrap(ISWashClothing, "getDuration", "laundry-board", function(original, self, ...)
        local t = original(self, ...)
        if type(t) ~= "number" or t <= 1 or not L.on() then return t end
        if not L.handles(self.item) or not L.hasBoard(self.character) then return t end
        return t * L.BOARD_TIME
    end)

    -- wringing leaves it damp
    DanTraits_Wrap(ISWringClothing, "complete", "laundry-wring", function(original, self, ...)
        local item = self.item
        if not L.on() or not L.isClothing(item) then return original(self, ...) end
        local before = L.wetness(item)
        local result = original(self, ...)
        local floor = math.min(before, L.wringLeaves(item))
        if L.wetness(item) < floor then
            L.setWetness(item, floor)
            pcall(function() syncItemFields(self.character, item) end)
        end
        return result
    end)
    DanTraits_Wrap(ISWringClothing, "isValid", "laundry-wring", function(original, self, ...)
        local ok = original(self, ...)
        if not ok or not L.on() or not L.isClothing(self.item) then return ok end
        return L.wetness(self.item) > L.wringLeaves(self.item) + 1
    end)
    DanTraits_Wrap(ISWringClothing, "getDuration", "laundry-wring", function(original, self, ...)
        local t = original(self, ...)
        if type(t) ~= "number" or t <= 1 or not L.on() or not L.isClothing(self.item) then return t end
        -- only the water that actually comes out
        local w = L.wetness(self.item)
        local out = math.max(0, w - L.wringLeaves(self.item))
        if w <= 0 then return t end
        return math.max(1, math.ceil(t * out / w))
    end)
end
wrapWashing()
Events.OnGameStart.Add(wrapWashing)
DanTraits_LaundryWrapWashing = wrapWashing   -- tests

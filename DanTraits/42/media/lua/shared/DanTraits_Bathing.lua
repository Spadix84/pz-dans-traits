-- Project Zomboid Vitality Project: Take A Bath And Shower (TakeABathAndShowerNew) compatibility.
require "DanTraits"

-- Does nothing unless Take A Bath And Shower is loaded. No dependency either way.
--
-- That mod cleans the body's blood and dirt a little at a time while you
-- bathe or shower (Germaphobe reads the same visual every minute, so the
-- relief comes on its own), soaks you (Multiple Sclerosis cools faster wet),
-- warms or chills the body toward the water (an MS character in a hot bath
-- heats up: by design on both sides), and its bath salts do what the names
-- say (a calming salt is the game's beta-blocker effect, a happy one its
-- antidepressant effect): those are its features and are left alone. An MDD
-- character zeroes the game's antidepressant timer every minute anyway, so a
-- happy salt does nothing for them.
--
-- Three things this file does:
--
-- A bath or a shower washes sun block off. Take A Bath fires
-- OnBathingEnd(character) when either ends (its client files load after this
-- one, so the event is looked up at game start).
--
-- Laundry's hand-wash floors (DanTraits_Laundry.lua; moved here from Dan's
-- Vanilla Fixes 2026-10-11) apply to the clothes you bathe or shower in. That
-- mod washes them a little each tick, all the way to spotless
-- (TABAS_BathingUtils.cleaningWornItems): here a patch of blood or dirt never
-- goes under the soap floor with soap or shampoo to hand (a bar in the
-- inventory, or the shower's own soap list), nor under the no-soap floor
-- without (a washboard's floors with one carried; Homemaker's floors for a
-- Homemaker), nor under a set-in stain;
-- a patch already under its floor is left where it was. Only a washing
-- machine gets a garment fully clean, bath or no bath. A bath does not count
-- as a wash (the washed clock, Fresh Clothes and the laundryWashed hook stay
-- with the sink and the machine; plans/laundry.md). Its own objects (the
-- tub's water, the towel) and the body are untouched.
--
-- It tells the other systems when you are in the water: DanTraits_BathingMode
-- (player) is "BATH" or "SHOWER" while that mod's tabas_IsBathing flag is
-- set (the mode from its OnBathingStart(player, mode)), and
-- DanTraits_BathingWet(player) is true from then until it calls you dry
-- (its tabas_HasBathingWet flag, cleared on OnBathingStateFinished).
-- Sensory Issues drains faster in the water and does not count the bath's
-- soaking as a touch trigger (DanTraits_Sensory.lua).
local installed = false

local bathMode = {}   -- player -> "BATH" / "SHOWER", from OnBathingStart

local function modFlag(player, key)
    local value
    pcall(function() value = player:getModData()[key] end)
    return value
end

function DanTraits_BathingMode(player)
    if not player then return nil end
    if not modFlag(player, "tabas_IsBathing") then
        bathMode[player] = nil
        return nil
    end
    return bathMode[player] or "BATH"
end

function DanTraits_BathingWet(player)
    if not player then return false end
    return modFlag(player, "tabas_IsBathing") == true or modFlag(player, "tabas_HasBathingWet") == true
end

local function onBathingStart(player, mode)
    if not player then return end
    bathMode[player] = (mode == "SHOWER") and "SHOWER" or "BATH"
end
DanTraits_BathingStarted = onBathingStart   -- tests

local function onBathingEnd(player)
    if not player then return end
    bathMode[player] = nil
    local local0 = getSpecificPlayer and getSpecificPlayer(0)
    if local0 and player ~= local0 then return end
    if not DanTraits_SunblockLeft or DanTraits_SunblockLeft(player) <= 0 then return end
    local d = DanTraits_Data(player)
    d.sbBlockMin = 0
    DanTraits_Notify(player, "UI_DanTraits_SunblockWashed")
end
DanTraits_BathingEnded = onBathingEnd   -- tests

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

local clothesInstalled = false
local function installClothes()
    if clothesInstalled then return end
    local U = TABAS_BathingUtils
    if type(U) ~= "table" or type(U.cleaningWornItems) ~= "function" then return end
    clothesInstalled = true
    local original = U.cleaningWornItems
    U.cleaningWornItems = function(character, wornItems, pct, factor, ...)
        local L = DanTraits_Laundry
        if not L or not L.on() then return original(character, wornItems, pct, factor, ...) end
        local snaps = {}
        pcall(function()
            local worn = wornItems or character:getWornItems()
            for i = 0, worn:size() - 1 do
                local item = worn:get(i):getItem()
                if item and L.handles(item) then snaps[#snaps + 1] = { item = item, snap = L.snapshot(item) } end
            end
        end)
        local a, b, c, d = original(character, wornItems, pct, factor, ...)
        if #snaps > 0 then
            local soap, method, skilled = soapToHand(character), L.methodFor(character), L.skilled(character)
            for _, e in ipairs(snaps) do pcall(function() L.applyFloors(e.item, e.snap, method, soap, skilled) end) end
        end
        return a, b, c, d
    end
    print("[DanTraits] Take A Bath And Shower found: laundry's hand-wash floors apply to clothes washed in the bath")
end
DanTraits_BathingInstallClothes = installClothes   -- tests

local function install()
    installClothes()
    if installed then return end
    local ev = Events and Events.OnBathingEnd
    if type(ev) ~= "table" or type(ev.Add) ~= "function" then return end
    installed = true
    ev.Add(onBathingEnd)
    local start = Events.OnBathingStart
    if type(start) == "table" and type(start.Add) == "function" then start.Add(onBathingStart) end
    print("[DanTraits] Take A Bath And Shower found: a bath washes sun block off")
end

Events.OnGameStart.Add(install)

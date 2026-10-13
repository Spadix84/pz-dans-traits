-- Project Zomboid Vitality Project: hooks into Dan's Vanilla Fixes' reading
-- overhaul (DansVanillaFixes_Reading.lua, its DVF_Reading API). Does nothing
-- unless that mod is loaded with reading on; no dependency either way.
--
--   relief  at home (DanTraits_Home.lua) a page does RD_HOME more good by the
--           home's strength, twice that for a Homebody; a concussion
--           (DanTraits_Concussion.lua) halves it at full strength; A Really
--           Bad Day's first day gets RD_BADDAY comfort from any book
--   time    40 and over without reading glasses, a page takes RD_AGE40 longer,
--           RD_AGE50 in the 50s; concussed, RD_CONCUSSION longer at full strength
require "DanTraits"

local RD_HOME = 0.15
local RD_HOME_HOMEBODY = 0.30
local RD_CONCUSSION_RELIEF = 0.5
local RD_CONCUSSION = 0.25
local RD_BADDAY = 0.25
local RD_BADDAY_HOURS = 24
local RD_AGE40 = 0.10
local RD_AGE50 = 0.15

local hasTrait = DanTraits_HasTrait

local function readingGlasses(player)
    local worn = false
    pcall(function()
        local items = player:getWornItems()
        for i = 0, items:size() - 1 do
            local item = items:getItemByIndex(i)
            if item and item:getFullType() == "Base.Glasses_Reading" then worn = true end
        end
    end)
    return worn
end

local function concussion(player)
    if not DanTraits_ConcussionStrength then return 0 end
    local ok, s = pcall(DanTraits_ConcussionStrength, player)
    return ok and tonumber(s) or 0
end

function DanTraits_ReadingRelief(player, info)
    local m = 1
    if DanTraits_HomeStrength and DanTraits_Data then
        local d = DanTraits_Data(player)
        if d and d.hmAtHome then
            local s = DanTraits_HomeStrength(player) or 0
            if s > 0 then m = m * (1 + (hasTrait(player, "homebody") and RD_HOME_HOMEBODY or RD_HOME) * s) end
        end
    end
    local c = concussion(player)
    if c > 0 then m = m * (1 - RD_CONCUSSION_RELIEF * math.min(1, c)) end
    if hasTrait(player, "badday") and (player:getHoursSurvived() or 0) < RD_BADDAY_HOURS then
        m = m * (1 + RD_BADDAY)
    end
    return m
end

function DanTraits_ReadingTime(player, info)
    local m = 1
    local band = DanTraits_AgeBand and DanTraits_AgeBand(player)
    if type(band) == "number" and band >= 40 and not readingGlasses(player) then
        m = m * (1 + (band >= 50 and RD_AGE50 or RD_AGE40))
    end
    local c = concussion(player)
    if c > 0 then m = m * (1 + RD_CONCUSSION * math.min(1, c)) end
    return m
end

local installed = false
local function install()
    if installed then return end
    local R = DVF_Reading
    if type(R) ~= "table" or type(R.addReliefHook) ~= "function" then return end
    installed = true
    R.addReliefHook("vitality", DanTraits_ReadingRelief)
    R.addDurationHook("vitality", DanTraits_ReadingTime)
    print("[DanTraits] Dan's Vanilla Fixes reading found: home, age, concussion and Bad Day hooks on")
end

install()
Events.OnGameBoot.Add(install)
Events.OnGameStart.Add(install)

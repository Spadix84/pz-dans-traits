-- Project Zomboid Vitality Project: the rest of Vitality's say in the
-- reading overhaul (DanTraits_Reading.lua), through its relief and duration
-- hooks. Off with the overhaul (sandbox ReadingEnabled).
--
--   relief  at home (DanTraits_Home.lua) a page does RD_HOME more good by the
--           home's strength, twice that for a Homebody; a concussion
--           (DanTraits_Concussion.lua) halves it at full strength; A Really
--           Bad Day's first day gets RD_BADDAY comfort from any book
--   time    needing glasses (the Reading Glasses trait's own rule,
--           DanTraits_NeedsGlasses in DanTraits_AgeTraits.lua: the trait and
--           none of its glasses worn), a page of small print takes RD_AGE40
--           longer, RD_AGE50 in the 50s, on top of the trait's x1.5 on every
--           read; concussed, RD_CONCUSSION longer at full strength
require "DanTraits"
require "DanTraits_Reading"

local RD_HOME = 0.15
local RD_HOME_HOMEBODY = 0.30
local RD_CONCUSSION_RELIEF = 0.5
local RD_CONCUSSION = 0.25
local RD_BADDAY = 0.25
local RD_BADDAY_HOURS = 24
local RD_AGE40 = 0.10
local RD_AGE50 = 0.15

local hasTrait = DanTraits_HasTrait

-- one rule for who needs glasses and which glasses count: the trait's
-- (a second list here said only Base.Glasses_Reading would do, so a
-- prescription pair was glasses to the trait and no glasses to a novel)
local function needsGlasses(player)
    if not DanTraits_NeedsGlasses then return false end
    local ok, needs = pcall(DanTraits_NeedsGlasses, player)
    return ok and needs == true
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
    if needsGlasses(player) then
        local band = DanTraits_AgeBand and DanTraits_AgeBand(player)
        m = m * (1 + (type(band) == "number" and band >= 50 and RD_AGE50 or RD_AGE40))
    end
    local c = concussion(player)
    if c > 0 then m = m * (1 + RD_CONCUSSION * math.min(1, c)) end
    return m
end

local R = DanTraits_Reading
R.addReliefHook("vitality", DanTraits_ReadingRelief)
R.addDurationHook("vitality", DanTraits_ReadingTime)

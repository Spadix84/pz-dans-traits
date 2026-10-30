-- Project Zomboid Vitality Project: the hot water bottle (vanilla Base.HotWaterBottle)
-- as heat for sore muscles. Not a trait: anyone with a bottle can use it.
--
-- Heating it is vanilla: fill it with water and put it in a stove, a microwave
-- or by a fire. The game counts a fluid container over 1.6 heat as hot, but
-- out of the heat it cools to the room in about a minute of real time, far
-- too fast for a bottle. So this keeps its own warmth: a bottle seen hot with
-- water in it (carried, or anywhere the game is heating items) is full,
-- HWB_FULL hours of warmth, and it runs down an hour an hour indoors,
-- HWB_RATE_BED as fast in bed (asleep), HWB_RATE_FREEZING outdoors below
-- freezing. Hot while more than HWB_HOT_LEFT is left, then Warm to
-- HWB_WARM_LEFT, then Tepid, then cold: indoors hot an hour, warm to three,
-- cold at four; in bed hot 1.5 hours, cold at six; out in the frost hot half
-- an hour, cold at two. Emptying it loses the warmth.
--
-- Held on a muscle group (ISDanTraitsHeatAction, up to HWB_APPLY_MIN minutes),
-- Hot or Warm:
--   * that group's load recovers x2 (Hot) or x1.5 (Warm) (the
--     fitnessGroupRecovery hook, DanTraits_Fitness.lua);
--   * the stiffness on its parts fades faster, so they hurt less (Age paces
--     the fall like any other: this runs before it);
--   * a pulled muscle in it heals faster: about two hours off for a Hot session;
--   * on the core, a Bad Back eases (DanTraits_BadBackEase, AgeTraits);
--   * stiff joints ache less with Arthritis, while held and for an hour after.
-- Carried Hot or Warm while asleep: every group recovers a little faster, and
-- a night in the cold (air at HWB_COLD_AIR or below, or the Cold moodle)
-- scores better (nightQuality).
--
-- Item mod data: dtHwbLeft (hours of warmth left, at the indoor rate),
-- dtHwbAt (the world hour it was last counted down). Player mod data (hwb
-- prefix): hwbGroup, hwbStage (held this minute), hwbBed, hwbSoothedMin,
-- hwbNightMin, hwbAwakeMin.
require "DanTraits"
require "DanTraits_FitnessData"

local clamp01 = DanTraits_Clamp01

local HWB_TYPE          = "Base.HotWaterBottle"
local HWB_HOT_HEAT      = 1.6     -- the game's heat over which a fluid container is hot
local HWB_FULL          = 4       -- hours of warmth, filled hot (indoors)
local HWB_HOT_LEFT      = 3       -- Hot while more than this is left...
local HWB_WARM_LEFT     = 1       -- ...Warm while more than this, then Tepid
local HWB_RATE_BED      = 2 / 3   -- warmth lost an hour asleep (under the covers)
local HWB_RATE_FREEZING = 2       -- ...outdoors below HWB_FREEZING
local HWB_FREEZING      = 0       -- C
local HWB_APPLY_MIN     = 30      -- a session's minutes (ISDanTraitsHeatAction)
-- held on a group, Hot / Warm
local HWB_RECOVER       = { hot = 2, warm = 1.5 }          -- the group's recovery x
local HWB_STIFF         = { hot = 1, warm = 0.6 }          -- stiffness off each of its parts a minute
local HWB_STRAIN        = { hot = 4 / 60, warm = 2 / 60 }  -- hours off a pulled muscle a minute (Hot: two hours a session)
local HWB_BACK          = { hot = 0.004, warm = 0.0024 }   -- Bad Back's load off a minute (as much again as resting)...
local HWB_BACK_OUT      = { hot = 1, warm = 0.5 }          -- ...and a thrown-out back's minutes run this much faster
local HWB_JOINT         = { hot = 0.8, warm = 0.9 }        -- Arthritis's joints x while held...
local HWB_SOOTHED       = 0.9                              -- ...and this for HWB_SOOTHED_MIN after
local HWB_SOOTHED_MIN   = 60
-- carried in bed, Hot / Warm
local HWB_BED_RECOVER   = { hot = 1.25, warm = 1.15 }      -- every group's recovery x asleep
local HWB_COLD_AIR      = 10      -- C: a night this cold or colder...
local HWB_NIGHT         = 0.05    -- ...scores up to this much better with a warm bottle
local HWB_NIGHT_FULL    = 240     -- minutes of it for the full lift
local HWB_NIGHT_KEEP    = 10      -- minutes past Vitality's night gap before an unscored night's count is dropped (Vitality off)

-- the bottle ----------------------------------------------------------------------

local nowHours = DanTraits_WorldHours

local function isBottle(item)
    local t = nil
    pcall(function() t = item:getFullType() end)
    return t == HWB_TYPE
end
DanTraits_HwbIsBottle = isBottle

local function hasFluid(item)
    local full = false
    pcall(function()
        local fc = item:getFluidContainer()
        full = fc ~= nil and not fc:isEmpty()
    end)
    return full
end
DanTraits_HwbHasFluid = hasFluid

local function forget(md) md.dtHwbLeft, md.dtHwbAt = nil, nil end

-- the hours of warmth left, counted down to now at `rate` (1: indoors). Only the
-- minute pass writes the clock back; a look (peek: the tooltip, the Hold
-- action's isValid every tick) reads without moving the stamp, or every glance
-- would reset the frost's or the bed's rate to the indoor one (2026-10-22). A
-- bottle found cold or emptied is forgotten either way: there is no clock left
local function warmthLeft(item, rate, peek)
    local md = item:getModData()
    local left = tonumber(md.dtHwbLeft)
    if not left then return 0 end
    if not hasFluid(item) then forget(md) return 0 end
    local now = nowHours()
    left = left - math.max(0, now - (tonumber(md.dtHwbAt) or now)) * (rate or 1)
    if left <= 0 then forget(md) return 0 end
    if not peek then md.dtHwbLeft, md.dtHwbAt = left, now end
    return left
end

local function stageOf(left)
    if left > HWB_HOT_LEFT then return "hot" end
    if left > HWB_WARM_LEFT then return "warm" end
    if left > 0 then return "tepid" end
    return nil
end

-- hot, warm, tepid or nil (cold), and the hours left at the indoor rate (a look:
-- the clock is not written)
function DanTraits_HwbStage(item)
    if not item or not isBottle(item) then return nil, 0 end
    local left = warmthLeft(item, 1, true)
    return stageOf(left), left
end

-- hours (indoors) until the bottle drops a stage
function DanTraits_HwbStageLeft(item)
    local stage, left = DanTraits_HwbStage(item)
    if stage == "hot" then return stage, left - HWB_HOT_LEFT end
    if stage == "warm" then return stage, left - HWB_WARM_LEFT end
    return stage, left
end

-- a bottle the game has hot, with water in it: full
local function stampIfHot(item)
    local heat = 1
    pcall(function() heat = item:getItemHeat() end)
    if (tonumber(heat) or 1) > HWB_HOT_HEAT and hasFluid(item) then
        local md = item:getModData()
        md.dtHwbLeft, md.dtHwbAt = HWB_FULL, nowHours()
        return true
    end
    return false
end
DanTraits_HwbStampIfHot = stampIfHot

-- anywhere the game is heating items (stoves, microwaves, fires): those lists
-- are the server's (empty on a multiplayer client, where the carried check
-- below still catches a bottle taken out hot)
local function stampHeating()
    pcall(function()
        local list = getCell():getProcessItems()
        for i = 0, (list and list:size() or 0) - 1 do
            local item = list:get(i)
            if item and isBottle(item) then stampIfHot(item) end
        end
    end)
end

-- the carried bottles' rate of cooling
local function carriedRate(player, asleep)
    if asleep then return HWB_RATE_BED end
    local outside, air = false, nil
    pcall(function() outside = player:isOutside() == true end)
    if outside then air = DanTraits_AirTemp(player) end
    if outside and type(air) == "number" and air < HWB_FREEZING then return HWB_RATE_FREEZING end
    return 1
end

local function feelsCold(player)
    if DanTraits_MoodleLevel(player, "HYPOTHERMIA") > 0 then return true end
    local air = DanTraits_AirTemp(player)
    return type(air) == "number" and air <= HWB_COLD_AIR
end

-- the carried bottles counted down (and stamped, if hot); the best stage among them
local function carriedBottles(player, asleep)
    local best, bestLeft = nil, 0
    local rate = carriedRate(player, asleep)
    pcall(function()
        local items = player:getInventory():getAllTypeRecurse(HWB_TYPE)
        for i = 0, (items and items:size() or 0) - 1 do
            local item = items:get(i)
            stampIfHot(item)
            local left = warmthLeft(item, rate)
            if left > bestLeft then best, bestLeft = stageOf(left), left end
        end
    end)
    return best
end

-- held on a group ---------------------------------------------------------------

local function heldBottle(player)
    local action = DanTraits_QueueHead(player)
    if action and action.Type == "ISDanTraitsHeatAction" and action.item and action.group then
        return action.item, action.group
    end
    return nil, nil
end

local function easeStiffness(player, g, amount)
    for _, name in ipairs(DanTraits_FIT_PARTS and DanTraits_FIT_PARTS[g] or {}) do
        pcall(function()
            local part = player:getBodyDamage():getBodyPart(BodyPartType[name])
            local now = part and part:getStiffness() or 0
            if now > 0 then part:setStiffness(math.max(0, now - amount)) end
        end)
    end
end

local function heatOn(player, d, g, stage)
    easeStiffness(player, g, HWB_STIFF[stage])
    local s = d.ftStrain
    if s and s.g == g then s.h = (s.h or 0) - HWB_STRAIN[stage] end   -- Fitness heals it when it reaches 0
    if g == "core" and DanTraits_BadBackEase then DanTraits_BadBackEase(player, HWB_BACK[stage], HWB_BACK_OUT[stage]) end
    d.hwbSoothedMin = HWB_SOOTHED_MIN
end

-- the minute ----------------------------------------------------------------------

local function updateBottleMinute(player, d)
    local asleep = DanTraits_Asleep(player)
    d.hwbGroup, d.hwbStage, d.hwbBed = nil, nil, nil
    stampHeating()
    local best = carriedBottles(player, asleep)

    local item, g = heldBottle(player)
    local stage = item and stageOf(warmthLeft(item, 1, true))   -- carriedBottles counted it down already
    if stage == "hot" or stage == "warm" then
        d.hwbGroup, d.hwbStage = g, stage
        heatOn(player, d, g, stage)
    elseif (d.hwbSoothedMin or 0) > 0 then
        d.hwbSoothedMin = d.hwbSoothedMin - 1
        if d.hwbSoothedMin <= 0 then d.hwbSoothedMin = nil end
    end

    if asleep and (best == "hot" or best == "warm") then
        d.hwbBed = best
        if feelsCold(player) then d.hwbNightMin = (d.hwbNightMin or 0) + 1 end
    end
    if asleep then
        d.hwbAwakeMin = nil
    elseif d.hwbNightMin then
        -- Vitality scores the night, and reads the count through nightQuality, once
        -- the player has been awake gapMin minutes (DanTraits_NIGHT; Restless Sleeper
        -- stretches it through nightGap), so the count must outlive that
        d.hwbAwakeMin = (d.hwbAwakeMin or 0) + 1
        local gap = DanTraits_RunHooks("nightGap", DanTraits_NIGHT.gapMin, player)
        if d.hwbAwakeMin > gap + HWB_NIGHT_KEEP then d.hwbNightMin, d.hwbAwakeMin = nil, nil end
    end
end

-- hooks --------------------------------------------------------------------------

-- Fitness: the group the bottle is on recovers faster; in bed, all of them a little
DanTraits_AddHook("fitnessGroupRecovery", function(k, player, d, g)
    if not d then return nil end
    if d.hwbGroup == g and HWB_RECOVER[d.hwbStage] then return k * HWB_RECOVER[d.hwbStage] end
    if d.hwbBed and HWB_BED_RECOVER[d.hwbBed] then return k * HWB_BED_RECOVER[d.hwbBed] end
    return nil
end)

-- Arthritis: heat on a stiff joint, and the hour after
DanTraits_AddHook("arthritisJoint", function(joint, player)
    local d = player and DanTraits_Data(player)
    if not d then return nil end
    if d.hwbGroup and HWB_JOINT[d.hwbStage] then return joint * HWB_JOINT[d.hwbStage] end
    if (d.hwbSoothedMin or 0) > 0 then return joint * HWB_SOOTHED end
    return nil
end)

-- Vitality: a cold night with a warm bottle in the bed scores better
DanTraits_AddHook("nightQuality", function(quality, player, d)
    if not d or not d.hwbNightMin then return nil end
    local lift = HWB_NIGHT * clamp01(d.hwbNightMin / HWB_NIGHT_FULL)
    d.hwbNightMin, d.hwbAwakeMin = nil, nil
    return quality + lift
end)

DanTraits_HWB_APPLY_MIN = HWB_APPLY_MIN

-- before Age (23.5), so Age paces the stiffness the heat takes off, and
-- before Fitness and Arthritis (40), which read what is held this minute
DanTraits_Every("minute", "HotWaterBottle", updateBottleMinute, 20)

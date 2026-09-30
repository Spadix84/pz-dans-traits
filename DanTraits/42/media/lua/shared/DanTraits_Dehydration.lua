-- Project Zomboid Vitality Project: dehydration.
-- Not a trait: every character has it (sandbox option DehydrationEnabled;
-- off: no load builds and any in progress clears).
--
-- Vanilla's thirst moodles (Slightly Thirsty, Thirsty, Parched, Dying of
-- Thirst) only cost health at the top end, and at the time of writing do
-- nothing else to the body. Going thirsty for hours now catches up with you:
-- a dehydration load (0..1) builds while the Thirst moodle is at Thirsty or
-- worse (twice as fast Parched, three times Dying of Thirst; about eight hours
-- at Thirsty to the full load), and drains in about two hours once you are
-- no more than Slightly Thirsty. It brings a headache (a pain floor through
-- DanTraits_PainFloor), tiredness, and slower endurance recovery (the
-- enduranceRegen hook of the stat delta pipeline), all scaling with the load.
-- Thirst already brings on migraines (DanTraits_Migraine.lua) and blood lost
-- comes back only with water (DanTraits_Blood.lua).
--
-- Mod data: dhLoad (0..1), dhTier (the last notice's tier).
-- Console: dehydration <load 0..1>
require "DanTraits"

local notify = DanTraits_Notify
local clamp01 = DanTraits_Clamp01

local DH_THIRST_AT     = { 0.12, 0.25, 0.70, 0.84 }  -- thirst (0..1) for each Thirst moodle level (if the moodle cannot be read)
local DH_BUILD_MIN     = 1 / 480 -- load a minute at Thirsty (eight hours to full)...
local DH_BUILD_LEVEL   = { 0, 1, 2, 3 }  -- ...x this by moodle level 1..4
local DH_DRAIN_MIN     = 1 / 120 -- load drained a minute at Slightly Thirsty or better
local DH_PAIN          = 30      -- pain floor at full load
local DH_PAIN_RAMP     = 2
local DH_FATIGUE_MIN   = 0.0004  -- tiredness a minute at full load
local DH_REGEN         = 0.4     -- endurance recovery x (1 - this x load)
local DH_TIER          = { 0.3, 0.7 }   -- a thirst headache | dehydrated

local function sandboxOn() return DanTraits_SandboxOn("DehydrationEnabled") end

-- 0..4: the vanilla Thirst moodle, or its level from the stat
local function thirstLevel(player)
    local level
    if MoodleType and MoodleType.THIRST then
        pcall(function() level = player:getMoodles():getMoodleLevel(MoodleType.THIRST) end)
    end
    if type(level) == "number" then return level end
    local thirst = DanTraits_StatFraction(player:getStats(), CharacterStat.THIRST)
    level = 0
    for i, at in ipairs(DH_THIRST_AT) do if thirst >= at then level = i end end
    return level
end

local function tierOf(load)
    local tier = 0
    for i, at in ipairs(DH_TIER) do if load >= at then tier = i end end
    return tier
end

local function updateDehydrationMinute(player, d)
    if not sandboxOn() then
        d.dhLoad, d.dhTier = nil, nil
        return
    end
    local level = thirstLevel(player)
    local load = d.dhLoad or 0
    local build = DH_BUILD_LEVEL[math.min(level, #DH_BUILD_LEVEL)] or 0
    if level >= 2 then
        load = math.min(1, load + DH_BUILD_MIN * build)
    elseif level <= 1 and load > 0 then
        load = math.max(0, load - DH_DRAIN_MIN)
    end
    d.dhLoad = load > 0 and load or nil
    local tier = tierOf(load)
    if tier > (d.dhTier or 0) then notify(player, "UI_DanTraits_DehydrationTier" .. tier) end
    if tier == 0 and (d.dhTier or 0) > 0 then DanTraits_NotifyGood(player, "UI_DanTraits_DehydrationEased") end
    d.dhTier = tier > 0 and tier or nil
    if load <= 0 then return end
    DanTraits_PainFloor(player, d, "dehydration", DH_PAIN * load, DH_PAIN_RAMP)
    DanTraits_StatAdd(player:getStats(), CharacterStat.FATIGUE, DH_FATIGUE_MIN * load)
end

function DanTraits_Dehydration(player)
    local d = player and player:getModData().DanTraits
    return d and d.dhLoad or 0
end

DanTraits_AddHook("enduranceRegen", function(delta, player, d)
    if not d or (d.dhLoad or 0) <= 0 then return nil end
    return delta * (1 - DH_REGEN * clamp01(d.dhLoad))
end)

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.dehydration = function(player, args)
    local d = DanTraits_Data(player)
    local load = tonumber(args[1])
    if not load then return "dehydration <load 0..1> (now " .. tostring(d.dhLoad or 0) .. ", thirst moodle " .. tostring(thirstLevel(player)) .. ")" end
    d.dhLoad = clamp01(load)
    return "dehydration load " .. tostring(d.dhLoad)
end

DanTraits_Every("minute", "Dehydration", updateDehydrationMinute, 40)

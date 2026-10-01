-- Project Zomboid Vitality Project: moodles for the effects that had none.
--
-- The older systems each feed their own moodle (Airway Irritation, Vitality,
-- Slept Badly, Hangover, Migraine, Blood Loss, Infection, Concussion). Every
-- other effect that holds a stat up or down for a while used to show only as
-- a notice when it began. They are all fed from here instead, once a minute
-- after every system has run (order 96), from what those systems keep in mod
-- data: this file changes nothing, it only reads and shows. Needs Moodle
-- Framework, like the others; without it nothing here does anything.
--
-- Each moodle is a level: 1 to 4 on the bad side, -1 on the good side (a
-- medication or sun block at work), 0 for nothing to show.
--
--   ChestPain          Heart Condition: a day of weak recovery, chest pain,
--                      pushing on through it; good: beta blockers working
--   Seizure            Epilepsy: the hour after, the aura before; good:
--                      anticonvulsants working
--   Tinnitus           ears ringing (Hard of Hearing for now)
--   GutFlare           Gluten Intolerance and Lactose Intolerance (a lactose
--                      flare is the milder: it tops out at the second level)
--   Filthy             Germaphobe: how grimy
--   Sunburn            anyone: skin hot, burnt, badly burnt; good: sun block on
--   Dehydration        anyone: thirst headache, dehydrated
--   CaffeineWithdrawal Caffeine Dependent
--   AlcoholWithdrawal  Alcoholic: craving, the shakes, delirium
--   NicotineCraving    Smoker
--   Depression         Major Depressive Disorder: an episode, by severity
--   LowIron            Anaemic
--   StiffJoints        Arthritis: the weather in the joints
--
-- Diabetes feeds its own (BloodSugar, from DanTraits_Diabetes.lua): out of
-- range, not which way; the meter is how you find out. Hallucinations has
-- none (it would give them away).
--
-- DanTraits_MoodleNames is the list the client creates them from
-- (client/DanTraits_Client.lua); DanTraits_MoodleLevels(player, d) is every
-- level now, by name, for the tests and the dashboard.
require "DanTraits"

local hasTrait = DanTraits_HasTrait

-- the level for a 0..1 value against ascending tier points
local function tierOf(value, tiers)
    local level = 0
    value = tonumber(value) or 0
    for i, at in ipairs(tiers) do if value >= at then level = i end end
    return level
end

local MED_ON           = 0.5     -- a medication level that protects (Heart's and Epilepsy's own)
local TN_LONG_MIN      = 60      -- ringing for this long or more is the second level
local GUT_TIER         = { 0.25, 0.5, 0.75 }
local GUT_LACTOSE      = 0.66    -- a full lactose flare, on Gluten's scale
local FILTHY_TIER      = { 0.15, 0.4, 0.7 }
local SUN_HOT          = 0.7     -- exposure at which the skin feels hot (Sunburn's own warning)
local SUN_BAD_PARTS    = 6       -- this many parts burnt is badly sunburnt
local DEHYDRATION_TIER = { 0.3, 0.7 }
local CAFFEINE_TIER    = { 0.01, 0.5 }
local NICOTINE_TIER    = { 0.15, 0.5, 0.8 }
local MDD_TIER         = { 0.01, 0.6, 0.85 }
local IRON_TIER        = { 0.1, 0.5, 0.9 }
local JOINT_TIER       = { 0.25, 0.5, 0.8 }

-- a drug in the system (the shared medication system, DanTraits_Meds.lua): the
-- good side of a moodle, so the icon going out is the reminder to take the next one
local function medOn(player, id)
    return DanTraits_MedCovered ~= nil and DanTraits_MedCovered(player, id) == true
end

local function count(t)
    local n = 0
    for _, v in pairs(t or {}) do if (tonumber(v) or 0) > 0 then n = n + 1 end end
    return n
end

local SPECS = {
    { name = "ChestPain", level = function(player, d)
        if (d.hcAnginaMin or 0) > 0 then return d.hcPushing and 3 or 2 end
        if (d.hcWeakH or 0) > 0 then return 1 end
        if hasTrait(player, "heart") and medOn(player, "beta") then return -1 end
        return 0
    end },
    { name = "Seizure", level = function(player, d)
        if not hasTrait(player, "epilepsy") then return 0 end
        if d.epAuraMin then return 2 end
        if (d.epAfterMin or 0) > 0 then return 1 end
        if medOn(player, "anticonvulsant") then return -1 end
        return 0
    end },
    { name = "Tinnitus", level = function(player, d)
        if not d.tnRinging then return 0 end
        return (d.tnDeafMin or 0) >= TN_LONG_MIN and 2 or 1
    end },
    { name = "GutFlare", level = function(player, d)
        local flare = 0
        if hasTrait(player, "gluten") then flare = d.gluten or 0 end
        if hasTrait(player, "lactose") then flare = math.max(flare, (d.lacFlare or 0) * GUT_LACTOSE) end
        return tierOf(flare, GUT_TIER)
    end },
    { name = "Filthy", level = function(player, d)
        if not hasTrait(player, "germaphobe") then return 0 end
        return tierOf(d.gmGrime, FILTHY_TIER)
    end },
    { name = "Sunburn", level = function(player, d)
        local burnt = count(d.sbBurn)
        if burnt >= SUN_BAD_PARTS then return 3 end
        if burnt > 0 then return 2 end
        if (d.sbHot or 0) >= SUN_HOT then return 1 end
        if (d.sbBlockMin or 0) > 0 then return -1 end
        return 0
    end },
    { name = "Dehydration", level = function(player, d)
        return tierOf(d.dhLoad, DEHYDRATION_TIER)
    end },
    { name = "CaffeineWithdrawal", level = function(player, d)
        if not hasTrait(player, "caffeine") then return 0 end
        return tierOf(d.cafWithdraw, CAFFEINE_TIER)
    end },
    { name = "AlcoholWithdrawal", level = function(player, d)
        if not d.alcWithdrawing or not hasTrait(player, "dependent") then return 0 end
        return math.max(0, math.min(3, d.alcStage or 0))
    end },
    { name = "NicotineCraving", level = function(player, d)
        if not DanTraits_NicotineWithdrawal then return 0 end
        return tierOf(DanTraits_NicotineWithdrawal(player), NICOTINE_TIER)
    end },
    { name = "Depression", level = function(player, d)
        if not d.mddEpisode or not hasTrait(player, "spiraling") then return 0 end
        return tierOf(d.mddSeverity, MDD_TIER)
    end },
    { name = "LowIron", level = function(player, d)
        if not hasTrait(player, "anemia") then return 0 end
        return tierOf(d.anDeficit, IRON_TIER)
    end },
    { name = "StiffJoints", level = function(player, d)
        if not hasTrait(player, "arthritis") then return 0 end
        return tierOf(d.artJoint, JOINT_TIER)
    end },
}

DanTraits_MoodleNames = {}
for i, spec in ipairs(SPECS) do DanTraits_MoodleNames[i] = spec.name end

-- every level now, by name; a spec that fails shows nothing
function DanTraits_MoodleLevels(player, d)
    local levels = {}
    d = d or {}
    for _, spec in ipairs(SPECS) do
        local ok, level = pcall(spec.level, player, d)
        levels[spec.name] = ok and tonumber(level) or 0
    end
    return levels
end

local function updateMoodlesMinute(player, d)
    if not MF or not MF.getMoodle then return end
    for name, level in pairs(DanTraits_MoodleLevels(player, d)) do
        DanTraits_LevelMoodle(player, name, level)
    end
end

DanTraits_Every("minute", "Moodles", updateMoodlesMinute, 96)

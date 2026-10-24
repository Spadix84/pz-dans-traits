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
-- Each moodle is a level: 1 to 4 on the bad side, -1 or -2 on the good side
-- (a medication or sun block at work), 0 for nothing to show. A daily drug's
-- moodle is the paler -1 while it builds up and the full -2 once it has
-- (DanTraits_MedMoodle, the same rule for every drug).
--
--   ChestPain          Heart Condition: the heart working hard, pounding,
--                      chest pain, pushing on through it; good: beta blockers
--                      building up, then working
--   WeakHeart          Heart Condition: the week after a heart attack, worst
--                      first
--   Seizure            Epilepsy: the hour after, the aura before; good:
--                      anticonvulsants building up, then working
--   Tinnitus           ears ringing (Hard of Hearing for now)
--   GutFlare           Gluten Intolerance and Lactose Intolerance (a lactose
--                      flare is the milder: it tops out at the second level)
--   Filthy             Germaphobe: how grimy
--   Sunburn            anyone: skin hot, burnt, badly burnt; good: sun block on
--   Dehydration        anyone: thirst headache, dehydrated
--   CaffeineWithdrawal Caffeine Dependent
--   AlcoholWithdrawal  Alcoholic: craving, the shakes, delirium
--   NicotineCraving    Smoker (the SmokerCravingMoodle sandbox option hides it)
--   Depression         Major Depressive Disorder: an episode, by severity
--   LowIron            Anaemic
--   StiffJoints        Arthritis: the weather in the joints
--   MSHeat             Multiple Sclerosis: heat sensitive, too hot, overheated
--   MSFlare            Multiple Sclerosis: a flare (the first level when
--                      prednisone is working on it)
--   Spoons             Multiple Sclerosis: the energy budget as felt (half gone,
--                      three left, the wall), after a coffee's mask
--   LightTooBright     Migraines, during an attack: how much pain the light is
--                      adding (a dim-lit room, a lit room, the sun; sunglasses
--                      take it down a level or so)
--   TriptanAfter       anyone, the day after sumatriptan: heavy-limbed and a
--                      little clumsy (tired sooner, a swing's grip can slip)
--   Antidepressants    good side only. Major Depressive Disorder: a pill's
--                      coverage is running, the paler green until the three-day
--                      regimen is at full benefit (its own moodle, so it shows
--                      through an episode). Anyone else: the game's own
--                      antidepressant effect is running
--   Home               anyone (DanTraits_Home.lua): good side Settling In, then
--                      At Home while at a place slept in three nights or more;
--                      bad side Missing Home, then Homesick, away from it
--   StaleClothes       anyone (DanTraits_Laundry.lua): Stale Clothes, then Musty
--                      Clothes, from the worst garment worn; good side Fresh
--                      Clothes, then Line-Dried, when everything worn is fresh
--   SensoryLoad        Sensory Issues: On Edge, Overwhelmed, then an overload:
--                      Meltdown (third level) or Shutdown (fourth)
--   SoreMuscles        anyone (DanTraits_Fitness.lua): Sore, Overworked, then
--                      Pulled Muscle
--   Pumped             anyone, good side only: Loosened Up after stretching,
--                      Pumped after a workout
--   Overtrained        anyone: seven hard days in a row, until two easy ones
--   BackStrain         Bad Back (DanTraits_AgeTraits.lua): Aching Back, Bad Back,
--                      then Back Thrown Out
--   Hyperfocus         ADHD (DanTraits_ADHD.lua), good side only: Getting Into
--                      It, then Hyperfocused
--   GoodMeal           anyone (DanTraits_Cooking.lua): good side Good Meal, then
--                      Great Meal (a Chef's dish), while its afterglow or Fuelled
--                      runs; bad side Side Stitch, after training stuffed
--   MedsDue            a daily medication for a trait the character has
--                      (DanTraits_Meds.lua): Medication Due, then Missed
--                      Medication once it has worn off (the MedReminderMoodle
--                      sandbox option hides it)
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
local tierOf = DanTraits_TierOf

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
local MS_HEAT_TIER     = { 0.25, 0.5, 0.8 }   -- MS's own heat tiers
local GLARE_TIER       = { 0.01, 0.5, 0.9 }   -- the light's pain against full sun: a lit room is 0.67, the sun 1

-- a drug in the system (the shared medication system, DanTraits_Meds.lua): the
-- good side of a moodle, paler while it builds up, so the icon going out is
-- the reminder to take the next one
local function medGood(player, id)
    if not DanTraits_MedMoodle then return 0 end
    return -(tonumber(DanTraits_MedMoodle(player, id)) or 0)
end

local function count(t)
    local n = 0
    for _, v in pairs(t or {}) do if (tonumber(v) or 0) > 0 then n = n + 1 end end
    return n
end

local SPECS = {
    { name = "ChestPain", level = function(player, d)
        if not hasTrait(player, "heart") then return 0 end
        if (d.hcAnginaMin or 0) > 0 then return d.hcPushing and 4 or 3 end
        local strain = d.hcStrain or 0
        if strain >= 0.75 then return 2 end
        if strain >= 0.4 then return 1 end
        return medGood(player, "beta")
    end },
    { name = "WeakHeart", level = function(player, d)
        -- the week after a heart attack, in three stages (DanTraits_Heart.lua: 168 hours in thirds)
        local h = d.hcWeakH or 0
        if h <= 0 then return 0 end
        if h > 112 then return 3 elseif h > 56 then return 2 end
        return 1
    end },
    { name = "Seizure", level = function(player, d)
        if not hasTrait(player, "epilepsy") then return 0 end
        if d.epAuraMin then return 2 end
        if (d.epAfterMin or 0) > 0 then return 1 end
        return medGood(player, "anticonvulsant")
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
        if not DanTraits_NicotineWithdrawal or not DanTraits_SandboxOn("SmokerCravingMoodle") then return 0 end
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
    { name = "MSHeat", level = function(player, d)
        if not hasTrait(player, "ms") then return 0 end
        return tierOf(d.msHeat, MS_HEAT_TIER)
    end },
    { name = "MSFlare", level = function(player, d)
        if not hasTrait(player, "ms") or (d.msFlareH or 0) <= 0 then return 0 end
        return (DanTraits_MedCovered and DanTraits_MedCovered(player, "prednisone")) and 1 or 2
    end },
    -- the spoon budget (DanTraits_Spoons.lua): the tier as felt, after a coffee's mask
    { name = "Spoons", level = function(player, d) return d.spFelt or 0 end },
    -- Migraines: the light making an attack worse (DanTraits_Migraine.lua keeps migGlare)
    { name = "LightTooBright", level = function(player, d)
        if not hasTrait(player, "migraine") then return 0 end
        return tierOf(d.migGlare, GLARE_TIER)
    end },
    -- anyone, the day after sumatriptan (DanTraits_Migraine.lua counts tripAfterMin down)
    { name = "TriptanAfter", level = function(player, d) return (d.tripAfterMin or 0) > 0 and 1 or 0 end },
    -- antidepressants taken: Depression's regimen (DanTraits_MDD.lua keeps mddMedDays, the
    -- coverage left), or for anyone else the game's own effect while it runs
    { name = "Antidepressants", level = function(player, d)
        if hasTrait(player, "spiraling") then
            if (d.mddMedDays or 0) <= 0 then return 0 end
            return (DanTraits_MddBenefit and DanTraits_MddBenefit(player) >= 1) and -2 or -1
        end
        return (player:getDepressEffect() or 0) > 0 and -2 or 0
    end },
    -- home (DanTraits_Home.lua keeps hmMoodle: -1 / -2 at home, 1 / 2 away and missing it)
    { name = "Home", level = function(player, d) return d.hmMoodle or 0 end },
    -- laundry (DanTraits_Laundry.lua keeps lnMoodle: 1 stale, 2 musty; -1 fresh, -2 line-dried)
    { name = "StaleClothes", level = function(player, d) return d.lnMoodle or 0 end },
    -- Sensory Issues (DanTraits_Sensory.lua keeps siTier and siOver): an overload is a meltdown or a shutdown
    { name = "SensoryLoad", level = function(player, d)
        if not hasTrait(player, "sensory") then return 0 end
        local tier = d.siTier or 0
        if tier >= 3 then return d.siOver == "shutdown" and 4 or 3 end
        return tier
    end },
    -- fitness (DanTraits_Fitness.lua keeps ftMoodle 1..3, ftPumpMoodle -1 / -2, ftOverMoodle 1)
    { name = "SoreMuscles", level = function(player, d) return d.ftMoodle or 0 end },
    { name = "Pumped", level = function(player, d) return d.ftPumpMoodle or 0 end },
    { name = "Overtrained", level = function(player, d) return d.ftOverMoodle or 0 end },
    -- Bad Back (DanTraits_AgeTraits.lua keeps bbMoodle: 1 aching, 2 bad, 3 thrown out)
    { name = "BackStrain", level = function(player, d)
        if not hasTrait(player, "badback") then return 0 end
        return d.bbMoodle or 0
    end },
    -- ADHD (DanTraits_ADHD.lua): -1 getting into it, -2 hyperfocused
    { name = "Hyperfocus", level = function(player, d)
        return DanTraits_AdhdMoodle and DanTraits_AdhdMoodle(player, d) or 0
    end },
    -- cooking (DanTraits_Cooking.lua keeps ckMoodle: -1 a good meal, -2 a Chef's, 1 a side stitch)
    { name = "GoodMeal", level = function(player, d) return d.ckMoodle or 0 end },
    -- a daily medication due (1) or worn off (2): the worst of the character's schedule
    { name = "MedsDue", level = function(player, d)
        if not DanTraits_MedDueLevel or not DanTraits_SandboxOn("MedReminderMoodle") then return 0 end
        return DanTraits_MedDueLevel(player)
    end },
}

DanTraits_MoodleNames = {}
for i, spec in ipairs(SPECS) do DanTraits_MoodleNames[i] = spec.name end

-- every level now, by name; a spec that fails shows nothing (and is logged once, DanTraits_Guard)
function DanTraits_MoodleLevels(player, d)
    local levels = {}
    d = d or {}
    for _, spec in ipairs(SPECS) do
        local ok, level = DanTraits_Guard("moodle:" .. spec.name, spec.level, player, d)
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

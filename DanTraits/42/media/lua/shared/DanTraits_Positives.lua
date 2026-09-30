-- Project Zomboid Vitality Project: the cheap positives.
-- Iron Stomach: rotten and burnt food hurts the diet score half as much,
--   and food sickness climbs half as fast (the foodSicknessRise hook of the
--   stat delta pipeline; a rise made by a mod floor, like a hangover's, is
--   left alone).
-- Early Riser: a new character's sleep score starts high, and every night
--   scores a little better.
-- Meal Prepper: a new character's diet score starts high, and variety is
--   counted over five days instead of three.
-- Night Shift: sleeping by day costs little. Between 6 AM and 8 PM, light
--   wakes you a quarter as easily and bright light costs a quarter of the rest
--   and the night's score (the sleepWake and sleepBright hooks of
--   DanTraits_Sleep.lua). Not with Early Riser.
-- Hollow Legs: every drink goes to your head a fifth less (the intoxication a
--   drink adds, through the drink action; so it takes more to dull pain too,
--   since drink relief follows the Drunk moodle), and a hangover is milder
--   (x0.6) and shorter (x0.7). Not with Straight Edge.
-- Fast Recovery (8: over vanilla Fast Healer's 6, which it contains): vanilla
--   Fast Healer folded in (granted with it), and after
--   blood loss the volume and the red cells come back half as fast again
--   (the bloodVolRefill and bloodCellRebuild hooks of DanTraits_Blood.lua).
--   Not with Fast Healer (it is already in here) or Slow Healer.
-- The one-shot starts are applied once, to a new character, like Gym
-- Regular; the hooks run for as long as the trait is there.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local traitData = DanTraits_Data

local IS_GRADE_CUT      = 0.5     -- rotten/burnt penalty x this
local IS_SICK_CUT       = 0.5     -- food sickness increases x this
local ER_SLEEP_START    = 0.8     -- Vitality sleep score for a new character
local ER_NIGHT_BONUS    = 0.1     -- added to every night's quality
local MP_DIET_START     = 0.8     -- Vitality diet score for a new character
local MP_VARIETY_HOURS  = 120     -- variety window (Vitality's default is 72)
local NS_DAY_FROM       = 6       -- Night Shift: the day, by the clock...
local NS_DAY_TO         = 20
local NS_WAKE           = 0.25    -- ...light wakes you x this
local NS_BRIGHT         = 0.25    -- ...bright light's cost x this
local HL_INTOX          = 0.8     -- Hollow Legs: intoxication a drink adds x this
local HL_SEVERITY       = 0.6     -- hangover severity x this
local HL_HOURS          = 0.7     -- hangover length x this
local FR_BLOOD          = 1.5     -- Fast Recovery: blood volume and red cells come back x this

-- Iron Stomach ---------------------------------------------------------------
DanTraits_AddHook("foodGrade", function(grade, player, item, why)
    if not hasTrait(player, "ironstomach") then return nil end
    why = tostring(why or "")
    if not (string.find(why, "rotten", 1, true) or string.find(why, "burnt", 1, true)) then return nil end
    if grade >= 0.5 then return nil end
    return 0.5 + (grade - 0.5) * IS_GRADE_CUT
end)

-- Food sickness climbs half as fast, through the stat delta pipeline
-- (DanTraits_Util.lua). Only the game's own rise is halved: when a mod system
-- (hangover, migraine, gluten, diabetes, concussion, MDD side effects,
-- dependence) raised food sickness with a floor since the last run, that rise
-- is theirs and Iron Stomach leaves it alone. The floor is a symptom of the
-- condition, not something eaten.
DanTraits_AddHook("foodSicknessRise", function(delta, player, d)
    if not hasTrait(player, "ironstomach") then return nil end
    if d and d.floorsThisMinute and d.floorsThisMinute.foodSicknessRise then return nil end
    return delta * IS_SICK_CUT
end)

-- Early Riser ----------------------------------------------------------------
DanTraits_AddHook("nightQuality", function(quality, player)
    if not hasTrait(player, "earlyriser") then return nil end
    return math.min(1, quality + ER_NIGHT_BONUS)
end)

-- Meal Prepper ---------------------------------------------------------------
DanTraits_AddHook("varietyHours", function(hours)
    local player = getSpecificPlayer(0)
    if not player or not hasTrait(player, "mealprepper") then return nil end
    return MP_VARIETY_HOURS
end)

-- Night Shift ----------------------------------------------------------------
local function daytime()
    local hour = 12
    pcall(function() hour = getGameTime():getHour() end)
    return hour >= NS_DAY_FROM and hour < NS_DAY_TO
end
DanTraits_NightShiftDay = daytime

DanTraits_AddHook("sleepWake", function(m, player)
    if not hasTrait(player, "nightshift") or not daytime() then return nil end
    return m * NS_WAKE
end)
DanTraits_AddHook("sleepBright", function(k, player)
    if not hasTrait(player, "nightshift") or not daytime() then return nil end
    return k * NS_BRIGHT
end)

-- Hollow Legs ----------------------------------------------------------------
DanTraits_AddHook("hangoverSeverity", function(severity, player)
    if not hasTrait(player, "hollowlegs") then return nil end
    return severity * HL_SEVERITY
end)
DanTraits_AddHook("hangoverHours", function(hours, player)
    if not hasTrait(player, "hollowlegs") then return nil end
    return hours * HL_HOURS
end)

-- the intoxication one sip added, cut
local function hollowSip(player, before)
    if not player or not before or not hasTrait(player, "hollowlegs") then return end
    pcall(function()
        local stats = player:getStats()
        local after = stats:get(CharacterStat.INTOXICATION) or before
        if after > before then stats:set(CharacterStat.INTOXICATION, before + (after - before) * HL_INTOX) end
    end)
end
DanTraits_HollowLegsSip = hollowSip

local function wrapHollowLegs()
    DanTraits_Wrap(ISDrinkFluidAction, "updateEat", "hollowlegs-drink", function(original, self, ...)
        local before
        pcall(function() before = self.character:getStats():get(CharacterStat.INTOXICATION) end)
        local result = original(self, ...)
        hollowSip(self.character, before)
        return result
    end)
end
wrapHollowLegs()
Events.OnGameStart.Add(wrapHollowLegs)

-- Fast Recovery --------------------------------------------------------------
DanTraits_AddHook("bloodVolRefill", function(gain, player)
    if not hasTrait(player, "fastrecovery") then return nil end
    return gain * FR_BLOOD
end)
DanTraits_AddHook("bloodCellRebuild", function(rate, player)
    if not hasTrait(player, "fastrecovery") then return nil end
    return rate * FR_BLOOD
end)

-- the one-shot starts, and the vanilla trait Fast Recovery carries
local function onPositivesCreate(player)
    if not player then return end
    DanTraits_GrantFoldIn(player, "fastrecovery", "FAST_HEALER", "frHealerGranted")
    local hours = 0
    pcall(function() hours = player:getHoursSurvived() or 0 end)
    if hours > 0 then return end
    local d = traitData(player)
    if hasTrait(player, "earlyriser") and not d.posEarlyRiser then
        d.posEarlyRiser = true
        d.vitSleep = math.max(d.vitSleep or 0, ER_SLEEP_START)
    end
    if hasTrait(player, "mealprepper") and not d.posMealPrepper then
        d.posMealPrepper = true
        d.vitDiet = math.max(d.vitDiet or 0, MP_DIET_START)
    end
end

local function onPositivesCreatePlayer(playerNum, player) onPositivesCreate(player) end
local function onPositivesGameStart() onPositivesCreate(getSpecificPlayer(0)) end

Events.OnCreatePlayer.Add(onPositivesCreatePlayer)
Events.OnGameStart.Add(onPositivesGameStart)

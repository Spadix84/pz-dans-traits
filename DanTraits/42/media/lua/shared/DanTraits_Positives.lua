-- Project Zomboid Vitality Project: the cheap positives.
-- Iron Stomach: rotten and burnt food hurts the diet score half as much,
--   and food sickness climbs half as fast.
-- Early Riser: a new character's sleep score starts high, and every night
--   scores a little better.
-- Meal Prepper: a new character's diet score starts high, and variety is
--   counted over five days instead of three.
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

-- Iron Stomach ---------------------------------------------------------------
DanTraits_AddHook("foodGrade", function(grade, player, item, why)
    if not hasTrait(player, "ironstomach") then return nil end
    why = tostring(why or "")
    if not (string.find(why, "rotten", 1, true) or string.find(why, "burnt", 1, true)) then return nil end
    if grade >= 0.5 then return nil end
    return 0.5 + (grade - 0.5) * IS_GRADE_CUT
end)

local function updateIronStomachMinute(player, d)
    if not hasTrait(player, "ironstomach") then return end
    pcall(function()
        local stats = player:getStats()
        local sick = stats:get(CharacterStat.FOOD_SICKNESS) or 0
        local last = d.isLastSick or sick
        if sick > last then
            sick = last + (sick - last) * IS_SICK_CUT
            stats:set(CharacterStat.FOOD_SICKNESS, sick)
        end
        d.isLastSick = sick
    end)
end
DanTraits_updateIronStomachMinute = updateIronStomachMinute

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

-- the one-shot starts
local function onPositivesCreate(player)
    if not player then return end
    local hours = 0
    pcall(function() hours = player:getHoursSurvived() or 0 end)
    if hours > 0 then return end
    local d = traitData(player)
    if hasTrait(player, "earlyriser") and not d.earlyRiserApplied then
        d.earlyRiserApplied = true
        d.vitSleep = math.max(d.vitSleep or 0, ER_SLEEP_START)
    end
    if hasTrait(player, "mealprepper") and not d.mealPrepperApplied then
        d.mealPrepperApplied = true
        d.vitDiet = math.max(d.vitDiet or 0, MP_DIET_START)
    end
end

local function onPositivesCreatePlayer(playerNum, player) onPositivesCreate(player) end
local function onPositivesGameStart() onPositivesCreate(getSpecificPlayer(0)) end

local function onPositivesMinute()
    local player = getSpecificPlayer(0)
    if not player or player:isDead() then return end
    updateIronStomachMinute(player, traitData(player))
end

Events.OnCreatePlayer.Add(onPositivesCreatePlayer)
Events.OnGameStart.Add(onPositivesGameStart)
Events.EveryOneMinute.Add(onPositivesMinute)

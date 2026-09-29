-- Project Zomboid Vitality Project: Major Depressive Disorder (trait id "spiraling").
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local traitData = DanTraits_Data
local DRINK = DanTraits_DRINK or { any = 0.01, tipsy = 0.05, buzz = 0.2, sober = 0.05 }  -- see DanTraits_Alcohol.lua
-- "tipsy" compares the raw stat, as it always has here (no 0..1 conversion)

-- Major Depressive Disorder (trait id "spiraling") ---------------------------
-- Two things run all the time: pain and stress drag mood down. On top of
-- that, depressive episodes start at random (more likely when stressed,
-- hurting, exhausted, short of sleep or shut indoors), last days, and hold unhappiness up to
-- a floor set by their severity. Books, TV and radio still work for a few
-- minutes and then the floor reasserts itself. What actually lowers the
-- floor is a drink (which quietly deepens the episode), a cigarette, a
-- comforting meal, regular exercise and time outdoors; the last two also
-- shorten the episode.
local MDD_EPISODE_BASE      = 0.0014  -- per 10 min: about one episode a week when nothing else is wrong
local MDD_STRESS_WEIGHT     = 2.0     -- chance x (1 + stress x this)
local MDD_PAIN_WEIGHT       = 1.5     -- chance x (1 + pain/100 x this)
local MDD_FATIGUE_WEIGHT    = 1.0     -- chance x (1 + fatigue x this)
local MDD_INDOORS_WEIGHT    = 1.0     -- chance x (1 + this) when under an hour outside in the last day
local MDD_SLEEP_DEBT_WEIGHT = 1.0     -- chance x (1 + Vitality's sleep debt x this): a bad night
local MDD_SLEEP_WAKE        = 1.5     -- during an episode, light wakes you this much more easily
local MDD_REFRACTORY_HOURS  = 48      -- no new episode this soon after one ends
local MDD_MIN_HOURS         = 24      -- an episode lasts at least a day
local MDD_MAX_EXTRA_HOURS   = 120     -- plus up to five more
local MDD_FLOOR_MAX         = 75      -- unhappiness floor at full severity (0..100)
local MDD_FLOOR_RAMP        = 2       -- per minute back towards the floor
local MDD_PAIN_MOOD         = 1.0     -- unhappiness per minute at full pain, episode or not
local MDD_STRESS_MOOD       = 0.8     -- unhappiness per minute at full stress, episode or not
local MDD_RELIEF_DRINK      = 20      -- floor reduction while intoxicated
local MDD_DRINK_SEVERITY    = 0.01    -- severity added per 10 min drunk: it helps now and costs later
local MDD_RELIEF_SMOKE      = 10      -- floor reduction after a cigarette
local MDD_SMOKE_MINUTES     = 120
local MDD_RELIEF_FOOD       = 10      -- floor reduction after a comforting meal
local MDD_FOOD_MINUTES      = 180
local MDD_RELIEF_EXERCISE   = 15      -- floor reduction at full exercise regularity
local MDD_RELIEF_OUTDOORS   = 15      -- floor reduction at four hours outside in the last day
local MDD_OUTDOORS_FULL_MIN = 240
local MDD_RECOVERY_BONUS    = 1.0     -- exercise and outdoors together shorten an episode by up to this (x2 speed)
-- Antidepressants (Base.PillsAntiDep) are a regimen, not a dose. Each pill
-- adds a day of coverage; benefit builds over two weeks of unbroken
-- coverage and drains if it lapses. The vanilla instant mood-clearing effect
-- is switched off for this trait.
local MDD_MED_PILL_DAYS     = 1       -- coverage a pill adds (halved when drunk)
local MDD_MED_MAX_DAYS      = 3       -- you can be a few days ahead, no more
local MDD_MED_FULL_DAYS     = 14      -- unbroken coverage needed for full benefit
local MDD_MED_ONSET_CUT     = 0.6     -- episode chance x (1 - this x benefit)
local MDD_MED_FLOOR_CUT     = 0.4     -- episode floor x (1 - this x benefit)
local MDD_MED_DRAG_CUT      = 0.3     -- pain/stress drag x (1 - this x benefit)
local MDD_MED_RECOVERY      = 0.5     -- episode shortening at full benefit (on top of habits)
local MDD_MED_SIDE_DAYS     = 3       -- first days on them: queasy and tired
local MDD_MED_SIDE_SICK     = 15      -- food sickness floor during side effects
local MDD_MED_SIDE_FATIGUE  = 0.0005  -- fatigue per minute during side effects
local MDD_MED_WITHDRAW_AFTER = 7      -- streak (days) after which stopping hurts
local MDD_MED_WITHDRAW_MIN  = 4320    -- discontinuation length in minutes (3 days)
local MDD_MED_WITHDRAW_MOOD = 0.3     -- unhappiness per minute while discontinuing
local MDD_MED_WITHDRAW_STRESS = 0.001 -- stress per minute while discontinuing
local MDD_MED_STREAK_DRAIN  = 3       -- streak days lost per day without coverage
-- TESTING: true forces an episode on the next ten-minute tick when none is running (severity 1,
-- 48 h) and makes the medication clock run a day per ten-minute tick. Set false for normal play.
local MDD_TEST_MODE         = (DanTraitsTestEpisode == nil) and false or DanTraitsTestEpisode

local function mddData(player)
    local d = traitData(player)
    d.mddSeverity = d.mddSeverity or 0
    d.mddOutside = d.mddOutside or 0
    d.mddSinceEnd = d.mddSinceEnd or MDD_REFRACTORY_HOURS
    return d
end

-- 0..1: average regularity of the character's three most regular exercises
local function mddRegularity(player)
    local values = {}
    pcall(function()
        local fitness = player:getFitness()
        for name, _ in pairs(FitnessExercises.exercisesType) do
            values[#values + 1] = math.max(0, math.min(100, fitness:getRegularity(name) or 0))
        end
    end)
    if #values == 0 then return 0 end
    table.sort(values, function(a, b) return a > b end)
    local total, n = 0, math.min(3, #values)
    for i = 1, n do total = total + values[i] end
    return total / n / 100
end
DanTraits_MddRegularity = mddRegularity

-- floor reduction from the things that help, and a 0..1 "healthy habits" score
local function mddRelief(player, d)
    local relief, habits = 0, 0
    pcall(function()
        if (player:getStats():get(CharacterStat.INTOXICATION) or 0) > DRINK.tipsy then relief = relief + MDD_RELIEF_DRINK end
    end)
    if (d.mddSmokeTimer or 0) > 0 then relief = relief + MDD_RELIEF_SMOKE end
    if (d.mddFoodTimer or 0) > 0 then relief = relief + MDD_RELIEF_FOOD end
    local regular = mddRegularity(player)
    relief = relief + regular * MDD_RELIEF_EXERCISE
    local outdoors = math.min(1, d.mddOutside / MDD_OUTDOORS_FULL_MIN)
    relief = relief + outdoors * MDD_RELIEF_OUTDOORS
    habits = (regular + outdoors) / 2
    return relief, habits
end

-- 0..1 antidepressant benefit from the current unbroken streak
local function mddBenefit(d)
    return math.min(1, (d.mddMedStreak or 0) / MDD_MED_FULL_DAYS)
end
DanTraits_MddBenefit = function(player) return mddBenefit(mddData(player)) end

-- called when an antidepressant is swallowed
function DanTraits_MddOnPill(player)
    if not hasTrait(player, "spiraling") then return false end
    local d = mddData(player)
    local dose = MDD_MED_PILL_DAYS
    pcall(function()
        if (player:getStats():get(CharacterStat.INTOXICATION) or 0) > DRINK.tipsy then dose = dose * 0.5 end
    end)
    d.mddMedDays = math.min(MDD_MED_MAX_DAYS, (d.mddMedDays or 0) + dose)
    d.mddMedEverStarted = true
    -- no instant lift: the vanilla effect is cancelled for this trait
    pcall(function() player:setDepressEffect(0) end)
    return true
end

-- called from the eat hook: comfort food
function DanTraits_MddOnEat(player, item)
    if not hasTrait(player, "spiraling") then return end
    local unhappy = 0
    pcall(function() unhappy = item:getUnhappyChange() or 0 end)
    if unhappy < 0 then mddData(player).mddFoodTimer = MDD_FOOD_MINUTES end
end

local function updateMddMinute(player, d)
    if not hasTrait(player, "spiraling") then return end
    d = mddData(player)
    local stats = player:getStats()

    -- bookkeeping: outdoors (rolling minutes per day), cigarettes, comfort food
    local outside = false
    pcall(function() outside = player:isOutside() end)
    d.mddOutside = d.mddOutside * (1 - 1 / 1440) + (outside and 1 or 0)
    pcall(function()
        local since = player:getTimeSinceLastSmoke()
        if d.mddLastSmokeSince ~= nil and since < d.mddLastSmokeSince then d.mddSmokeTimer = MDD_SMOKE_MINUTES end
        d.mddLastSmokeSince = since
    end)
    if (d.mddSmokeTimer or 0) > 0 then d.mddSmokeTimer = d.mddSmokeTimer - 1 end
    if (d.mddFoodTimer or 0) > 0 then d.mddFoodTimer = d.mddFoodTimer - 1 end

    -- antidepressants: never the vanilla instant lift; side effects early on; discontinuation
    local benefit = mddBenefit(d)
    pcall(function() if (player:getDepressEffect() or 0) > 0 then player:setDepressEffect(0) end end)
    if (d.mddMedDays or 0) > 0 and (d.mddMedStreak or 0) < MDD_MED_SIDE_DAYS then
        pcall(function()
            DanTraits_FloorUp(stats, CharacterStat.FOOD_SICKNESS, MDD_MED_SIDE_SICK, 1)
            DanTraits_StatAdd(stats, CharacterStat.FATIGUE, MDD_MED_SIDE_FATIGUE)
        end)
    end
    if (d.mddWithdraw or 0) > 0 then
        d.mddWithdraw = d.mddWithdraw - 1
        pcall(function()
            DanTraits_StatAdd(stats, CharacterStat.UNHAPPINESS, MDD_MED_WITHDRAW_MOOD)
            DanTraits_StatAdd(stats, CharacterStat.STRESS, MDD_MED_WITHDRAW_STRESS)
        end)
    end

    -- pain and stress wear mood down, episode or not (blunted a little by a working regimen)
    local unhappy = stats:get(CharacterStat.UNHAPPINESS) or 0
    local push = ((stats:get(CharacterStat.PAIN) or 0) / 100 * MDD_PAIN_MOOD + (stats:get(CharacterStat.STRESS) or 0) * MDD_STRESS_MOOD)
        * (1 - MDD_MED_DRAG_CUT * benefit)
    if push > 0 then
        unhappy = math.min(100, unhappy + push)
        stats:set(CharacterStat.UNHAPPINESS, unhappy)
    end

    -- during an episode, mood is held up to the floor
    if d.mddEpisode then
        local relief = mddRelief(player, d)
        local floor = math.max(0, d.mddSeverity * MDD_FLOOR_MAX * (1 - MDD_MED_FLOOR_CUT * benefit) - relief)
        DanTraits_FloorUp(stats, CharacterStat.UNHAPPINESS, floor, MDD_FLOOR_RAMP)
    end
end

-- the medication clock: coverage burns a day per day, the streak builds while covered
local function updateMddMeds(d, tickDays)
    d.mddMedDays = d.mddMedDays or 0
    d.mddMedStreak = d.mddMedStreak or 0
    if d.mddMedDays > 0 then
        d.mddMedDays = math.max(0, d.mddMedDays - tickDays)
        d.mddMedStreak = math.min(MDD_MED_FULL_DAYS * 4, d.mddMedStreak + tickDays)
        d.mddMedLapsed = false
    elseif d.mddMedStreak > 0 then
        if not d.mddMedLapsed then
            d.mddMedLapsed = true
            if d.mddMedStreak >= MDD_MED_WITHDRAW_AFTER then d.mddWithdraw = MDD_MED_WITHDRAW_MIN end
        end
        d.mddMedStreak = math.max(0, d.mddMedStreak - MDD_MED_STREAK_DRAIN * tickDays)
    end
end

local function updateMddTen(player, d)
    if not hasTrait(player, "spiraling") then return end
    d = mddData(player)
    local stats = player:getStats()
    updateMddMeds(d, MDD_TEST_MODE and 1 or (1 / 144))
    local benefit = mddBenefit(d)
    if MDD_TEST_MODE and not d.mddEpisode and not d.mddTestFired then
        d.mddTestFired = true
        d.mddEpisode = true
        d.mddSeverity = 1
        d.mddHoursLeft = 48
        notify(player, "UI_DanTraits_MddStart")
        return
    end
    if d.mddEpisode then
        local _, habits = mddRelief(player, d)
        d.mddHoursLeft = (d.mddHoursLeft or 0) - (1 / 6) * (1 + habits * MDD_RECOVERY_BONUS + benefit * MDD_MED_RECOVERY)
        if (stats:get(CharacterStat.INTOXICATION) or 0) > DRINK.tipsy then
            d.mddSeverity = math.min(1, d.mddSeverity + MDD_DRINK_SEVERITY)
        end
        if d.mddHoursLeft <= 0 then
            d.mddEpisode = false
            d.mddSinceEnd = 0
            DanTraits_NotifyGood(player, "UI_DanTraits_MddEnd")
        end
        return
    end
    d.mddSinceEnd = d.mddSinceEnd + 1 / 6
    if d.mddSinceEnd < MDD_REFRACTORY_HOURS then return end
    local chance = MDD_EPISODE_BASE
        * (1 + (stats:get(CharacterStat.STRESS) or 0) * MDD_STRESS_WEIGHT)
        * (1 + (stats:get(CharacterStat.PAIN) or 0) / 100 * MDD_PAIN_WEIGHT)
        * (1 + (stats:get(CharacterStat.FATIGUE) or 0) * MDD_FATIGUE_WEIGHT)
    if d.mddOutside < 60 then chance = chance * (1 + MDD_INDOORS_WEIGHT) end
    if DanTraits_SleepDebt then chance = chance * (1 + MDD_SLEEP_DEBT_WEIGHT * DanTraits_SleepDebt(player)) end
    chance = chance * (1 - MDD_MED_ONSET_CUT * benefit)
    if DanTraits_VitalityMddOnset then chance = chance * DanTraits_VitalityMddOnset(player) end
    if ZombRand(100000) >= chance * 100000 then return end
    d.mddEpisode = true
    d.mddSeverity = 0.4 + ZombRand(61) / 100
    d.mddHoursLeft = MDD_MIN_HOURS + ZombRand(MDD_MAX_EXTRA_HOURS + 1)
    notify(player, "UI_DanTraits_MddStart")
end

-- sleep is lighter during an episode: light wakes you more easily
DanTraits_AddHook("sleepWake", function(m, player, d)
    if not d or not d.mddEpisode or not hasTrait(player, "spiraling") then return nil end
    return m * MDD_SLEEP_WAKE
end)

DanTraits_Every("minute", "MDD", updateMddMinute, 40)
DanTraits_Every("ten", "MDD", updateMddTen, 40)

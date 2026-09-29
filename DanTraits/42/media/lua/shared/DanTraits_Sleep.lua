-- Project Zomboid Vitality Project: sleep and light.
-- Not a trait: every character has it. While asleep, the light on the
-- character's square is read every minute (the same per-player light level
-- the game's reading check uses). Dark sleep is deeper: tiredness drains
-- faster and the night scores better. Light sleep is shallow: tiredness
-- drains slower, the night scores worse, and anything brighter than about
-- reading light can wake you, more often the brighter it is. Exhaustion,
-- drink and sleeping pills let you sleep through it. Each wake also counts
-- as an interruption in Vitality's night score. Curtains and light
-- switches matter now.
--
-- How easily light wakes you depends on who you are:
--   Restless Sleeper, Night Owl, Cat's Eyes: x1.5 each. Restless Sleeper
--     sleeps in two halves (vanilla halves the sleep), so Vitality counts
--     two sleeps up to three hours apart as one night and does not charge
--     for the wake between them.
--   Caffeine, anyone: a full dose (a mug of coffee) keeps you on edge for
--     six hours, less for a smaller one: x2 while it lasts. A smoker clears
--     it faster, so theirs wears off sooner.
--   Other trait files add their own through the "sleepWake" hook
--     (a depressive episode, a migraine).
--   A wound infection's fever, anyone: the night scores x0.7 at full fever
--     and light wakes you x1.5 as easily.
--   Deep Sleeper: x0.25.
-- Desensitized: the things you have seen come back at night. A chance each
-- hour asleep of waking from a nightmare, stressed and low.
--
-- Deep Sleeper: Wakeful folded in (the vanilla trait is granted, so the
-- shorter sleep and Vitality's five-hour night come with it; Wakeful itself
-- is hidden at character creation, see media/lua/client). On top of that,
-- light rarely wakes you, bright light costs half as much rest, and the dark
-- does you more good.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local hasVanillaTrait = DanTraits_HasVanillaTrait
local notify = DanTraits_Notify
local traitData = DanTraits_Data
local fraction = DanTraits_StatFraction

local SL_DARK           = 0.25    -- light level at or below this: fully dark
local SL_BRIGHT         = 0.60    -- at or above this: fully lit (the midpoint, 0.425, is about vanilla's reading threshold)
local SL_REST_DARK      = 0.15    -- tiredness drains this much faster, fully dark...
local SL_REST_BRIGHT    = 0.15    -- ...and this much slower, fully lit
local SL_QUALITY_DARK   = 0.10    -- added to the night's score after a dark night...
local SL_QUALITY_BRIGHT = 0.15    -- ...taken off after a lit one
local SL_WAKE_HOUR      = 0.5     -- chance per hour of waking, fully lit
local SL_WAKE_SETTLE    = 30      -- minutes asleep before light (or a nightmare) can wake you
local SL_WAKE_TIRED     = 0.7     -- wake chance x (1 - this x fatigue): the exhausted sleep through it
local SL_WAKE_DRUNK     = 0.9     -- wake chance x (1 - this x intoxication)
-- who you are
local RS_WAKE           = 1.5     -- Restless Sleeper
local RS_NIGHT_GAP_MIN  = 180     -- two sleeps this close together are one night
local NO_WAKE           = 1.5     -- Night Owl
local NV_WAKE           = 1.5     -- Cat's Eyes
local CAF_WAKE          = 2       -- while caffeine is working
local CAF_FULL_DOSE     = 80      -- caffeine units (Caffeine Dependent's scale: a mug of coffee is about 100)...
local CAF_HOURS         = 6       -- ...that keep you on edge this long; a smaller dose, pro rata
local DES_NIGHTMARE_HOUR = 0.08   -- Desensitized: chance per hour asleep of a nightmare
local DES_STRESS        = 0.15
local DES_UNHAPPY       = 10
-- Deep Sleeper
local DS_WAKE           = 0.25    -- light wake chance x this
local DS_REST_BRIGHT    = 0.5     -- bright-light rest and score penalties x this
local DS_REST_DARK      = 1.5     -- dark rest and score bonuses x this
local SL_FEVER_CUT      = 0.3     -- the night's score x (1 - this x fever)
local SL_FEVER_WAKE     = 0.5     -- light wakes you x (1 + this x fever)

local clamp01 = DanTraits_Clamp01

-- -1 (fully lit) .. +1 (fully dark), from a light level
local function darknessOf(light)
    return 1 - 2 * clamp01((light - SL_DARK) / (SL_BRIGHT - SL_DARK))
end
DanTraits_SleepDarkness = darknessOf

local function lightLevel(player)
    local light = nil
    pcall(function()
        local square = player:getCurrentSquare() or player:getSquare()
        if square then light = square:getLightLevel(player:getPlayerNum()) end
    end)
    return light
end
DanTraits_SleepLight = lightLevel

-- a multiplier on a good (dark > 0) or bad (dark < 0) effect, for the trait
local function scaled(player, dark, good, bad)
    local deep = hasTrait(player, "deepsleeper")
    if dark > 0 then return good * dark * (deep and DS_REST_DARK or 1) end
    return bad * dark * (deep and DS_REST_BRIGHT or 1)
end

-- how easily light wakes this character: 1 is everyone
local function wakeMultiplier(player, d)
    local m = 1
    if hasVanillaTrait(player, "base:insomniac") then m = m * RS_WAKE end
    if hasVanillaTrait(player, "base:nightowl") then m = m * NO_WAKE end
    if hasVanillaTrait(player, "base:nightvision") then m = m * NV_WAKE end
    if d and (d.slCaffeineHours or 0) > 0 then m = m * CAF_WAKE end
    m = DanTraits_RunHooks("sleepWake", m, player, d)
    if hasTrait(player, "deepsleeper") then m = m * DS_WAKE end
    return m
end
DanTraits_SleepWakeMultiplier = wakeMultiplier

-- percent chance, this minute, that the light wakes you
local function wakeChance(player, dark, fatigue, intox, d)
    if dark >= 0 then return 0 end
    local chance = SL_WAKE_HOUR / 60 * -dark
    chance = chance * (1 - SL_WAKE_TIRED * clamp01(fatigue)) * (1 - SL_WAKE_DRUNK * clamp01(intox))
    return math.max(0, chance * wakeMultiplier(player, d) * 100)
end
DanTraits_SleepWakeChance = wakeChance

-- caffeine, for everyone: called by the Caffeine file for every dose it sees
function DanTraits_SleepOnCaffeine(player, amount)
    if not player or not amount or amount <= 0 then return end
    local d = traitData(player)
    local hours = CAF_HOURS * math.min(1, amount / CAF_FULL_DOSE)
    hours = hours / DanTraits_RunHooks("caffeineClearance", 1, player)   -- a smoker's wears off sooner
    d.slCaffeineHours = math.max(d.slCaffeineHours or 0, hours)
end

local function wakeUp(player, textKey)
    local ok = pcall(function() getSleepingEvent():wakeUp(player) end)
    if not ok then pcall(function() player:forceAwake() end) end
    notify(player, textKey)
end

local function nightmare(player, d)
    d.slNightmares = (d.slNightmares or 0) + 1
    d.slAsleepMin, d.slLastFatigue = nil, nil
    pcall(function()
        local stats = player:getStats()
        stats:set(CharacterStat.STRESS, math.min(1, (stats:get(CharacterStat.STRESS) or 0) + DES_STRESS))
        stats:set(CharacterStat.UNHAPPINESS, math.min(100, (stats:get(CharacterStat.UNHAPPINESS) or 0) + DES_UNHAPPY))
    end)
    wakeUp(player, "UI_DanTraits_SleepNightmare")
end

local function updateSleepMinute(player, d)
    if (d.slCaffeineHours or 0) > 0 then
        d.slCaffeineHours = d.slCaffeineHours - 1 / 60
        if d.slCaffeineHours < 1e-6 then d.slCaffeineHours = 0 end
    end
    local stats = player:getStats()
    local asleep, fatigue = false, 0
    asleep = DanTraits_Asleep(player)
    pcall(function() fatigue = stats:get(CharacterStat.FATIGUE) or 0 end)
    if not asleep then
        d.slAsleepMin, d.slLastFatigue = nil, nil
        return
    end
    local light = lightLevel(player)
    if light == nil then return end
    local dark = darknessOf(light)
    d.slLight, d.slDark = light, dark
    d.slAsleepMin = (d.slAsleepMin or 0) + 1
    d.slNightDark = (d.slNightDark or 0) + dark
    d.slNightMin = (d.slNightMin or 0) + 1

    -- rest: scale however much tiredness the game took off since last minute
    local last = d.slLastFatigue or fatigue
    if fatigue < last then
        fatigue = clamp01(last - (last - fatigue) * (1 + scaled(player, dark, SL_REST_DARK, SL_REST_BRIGHT)))
        pcall(function() stats:set(CharacterStat.FATIGUE, fatigue) end)
    end
    d.slLastFatigue = fatigue

    if d.slAsleepMin < SL_WAKE_SETTLE then return end
    -- nightmares: sleeping pills do not keep them away
    if hasVanillaTrait(player, "base:desensitized") and ZombRand(10000) < DES_NIGHTMARE_HOUR / 60 * 10000 then
        nightmare(player, d)
        return
    end
    -- light: not on sleeping pills
    local tablets = 0
    pcall(function() tablets = player:getSleepingTabletEffect() or 0 end)
    if tablets > 0 then return end
    local chance = wakeChance(player, dark, fatigue, fraction(stats, CharacterStat.INTOXICATION), d)
    d.slWakeChance = chance
    if chance > 0 and ZombRand(10000) < chance * 100 then
        d.slLightWakes = (d.slLightWakes or 0) + 1
        d.slAsleepMin, d.slLastFatigue = nil, nil
        wakeUp(player, "UI_DanTraits_SleepLightWoke")
    end
end
DanTraits_updateSleepMinute = updateSleepMinute

-- the night's score: how dark it was, on average, while asleep
DanTraits_AddHook("nightQuality", function(quality, player, d)
    if not d or not d.slNightMin or d.slNightMin <= 0 then return nil end
    local dark = d.slNightDark / d.slNightMin
    d.slLastNightDark = dark
    d.slNightDark, d.slNightMin = 0, 0
    return clamp01(quality + scaled(player, dark, SL_QUALITY_DARK, SL_QUALITY_BRIGHT))
end)

-- a fever is a bad night: a worse score, and lighter sleep (DanTraits_Infection.lua)
local function feverOf(player)
    local fever = 0
    if DanTraits_InfectionFever then pcall(function() fever = clamp01(DanTraits_InfectionFever(player)) end) end
    return fever
end
DanTraits_AddHook("nightQuality", function(quality, player)
    local fever = feverOf(player)
    if fever <= 0 then return nil end
    return quality * (1 - SL_FEVER_CUT * fever)
end)
DanTraits_AddHook("sleepWake", function(m, player)
    local fever = feverOf(player)
    if fever <= 0 then return nil end
    return m * (1 + SL_FEVER_WAKE * fever)
end)

-- Restless Sleeper: two halves are one night, and the wake between them is free
DanTraits_AddHook("nightGap", function(minutes, player)
    if not hasVanillaTrait(player, "base:insomniac") then return nil end
    return math.max(minutes, RS_NIGHT_GAP_MIN)
end)
DanTraits_AddHook("nightWakes", function(wakes, player)
    if not hasVanillaTrait(player, "base:insomniac") then return nil end
    return math.max(1, wakes - 1)
end)

-- Deep Sleeper carries Wakeful with it: granted once, whenever the trait is
-- first seen (new character, or added later)
local function grantWakeful(player)
    if not player or not hasTrait(player, "deepsleeper") then return end
    local d = traitData(player)
    if d.deepSleeperWakeful then return end
    local ok = pcall(function()
        local traits = player:getCharacterTraits()
        if not traits:get(CharacterTrait.NEEDS_LESS_SLEEP) then traits:add(CharacterTrait.NEEDS_LESS_SLEEP) end
    end)
    DanTraits_TraitsChanged(player)
    if ok then d.deepSleeperWakeful = true end
end
DanTraits_GrantWakeful = grantWakeful

local function onSleepCreatePlayer(playerNum, player) grantWakeful(player) end
local function onSleepGameStart() grantWakeful(getSpecificPlayer(0)) end

Events.OnCreatePlayer.Add(onSleepCreatePlayer)
Events.OnGameStart.Add(onSleepGameStart)
DanTraits_Every("minute", "Sleep", updateSleepMinute, 10)

-- Project Zomboid Vitality Project: Alcoholic (trait id "dependent").
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local fraction = DanTraits_StatFraction

-- Alcoholic -----------------------------------------------------------------
-- Everyone carries an alcoholism meter (0..1, saved as depTolerance). Drinking
-- fills it, by intoxication and time, but only so much a day, so it is the
-- habit that counts, not one big night; every sober hour drains it, full to
-- empty in a month. Past ALC_GAIN the character becomes an Alcoholic.
--
-- An Alcoholic in withdrawal goes through stages, each sooner the higher the
-- meter (onset x (1 - 0.5 x meter)), and everything scales with the meter:
--   craving   (a day dry):        stress and low mood climb, sleep is light and poor
--   shakes    (two days dry):     pain, nausea, and weapons slip from shaking hands
--   delirium  (three days dry, meter 0.6+ only): hallucinations and seizures
-- The acute phase holds for five days, then fades over the next five to a
-- lingering craving. A drink ends withdrawal, but the meter decides how much
-- of a drink: at a high meter a sip is not enough. A month without any
-- alcohol cures the trait. After that the character is never quite free: the
-- first drink of any drinking session is a coin flip to relapse.
local DRINK = DanTraits_DRINK or { any = 0.01, tipsy = 0.05, buzz = 0.2, sober = 0.05 }  -- DRINK.any: had any alcohol
local ALC_BUILD_H       = 10    -- intoxication-hours (1.0 intoxication for 1 h) to fill the meter...
local ALC_DAY_CAP       = 0.08  -- ...but it fills at most this much a day
local ALC_DECAY_H       = 720   -- sober hours to drain a full meter (30 days)
local ALC_GAIN          = 0.30  -- meter at which the trait is gained
local ALC_START         = 0.50  -- meter for a character who takes the trait (or has it from an older save)
local ALC_RELAPSE       = 0.50  -- meter set on relapse
local ALC_RELAPSE_ODDS  = 50    -- percent chance per drinking session to relapse
local ALC_CURE_H        = 720   -- sober hours to lose the trait (30 days)
local DRY_HOURS_STRESS  = 24    -- hours without a drink before craving (at an empty meter)
local DRY_HOURS_PAIN    = 48    -- ...before the shakes
local DRY_HOURS_DT      = 72    -- ...before delirium
local ALC_DT_METER      = 0.6   -- delirium needs at least this meter
local ALC_PEAK_H        = 120   -- dry hours the acute phase holds full strength
local ALC_FADE_H        = 120   -- then fades over this many hours...
local ALC_LINGER        = 0.2   -- ...to this share of it
local DEP_SATED_MIN     = 0.05  -- intoxication that counts as a drink at an empty meter...
local DEP_SATED_TOL     = 0.40  -- ...plus this much at a full one
local DEP_TOL_ONSET_CUT = 0.5   -- withdrawal starts this much sooner at a full meter
-- strength w = meter x fade (0..1); the rates below are per ten minutes at w = 1
local DEP_STRESS_RATE   = 0.02  -- stress (0..1)
local ALC_MOOD_RATE     = 2     -- unhappiness (0..100)
local DEP_PAIN_RATE     = 1     -- pain (0..100)
local ALC_SICK          = 40    -- nausea floor (food sickness, 0..100) at w = 1...
local ALC_SICK_RAMP     = 3     -- ...climbing this much a tick
local ALC_SHAKE_DROP    = 10    -- percent chance a swing drops the weapon at w = 1
local ALC_SLEEP_WAKE    = 2     -- light wakes you (1 + this x w) times as easily
local ALC_SLEEP_CUT     = 0.4   -- night quality x (1 - this x w)
local ALC_HALLU_CHANCE  = 0.15  -- hallucination chance per tick at w = 1 (delirium)
local ALC_SEIZE_CHANCE  = 0.005 -- seizure chance per tick at w = 1 (delirium): about one every 33 h at full
local ALC_SEIZE_PAIN    = 25
local ALC_SEIZE_PANIC   = 40
local ALC_SEIZE_FATIGUE = 0.2
local TICK_H            = 10 / 60

-- 0..1, read by the hangover system: an Alcoholic's meter doubles as tolerance
function DanTraits_AlcoholTolerance(player)
    if not player or not hasTrait(player, "dependent") then return 0 end
    local d = player:getModData().DanTraits
    return d and d.depTolerance or 0
end

local function setTrait(player, on)
    local entry = DanTraitsRegistry and DanTraitsRegistry.dependent
    if not entry then return false end
    local ok = pcall(function()
        local traits = player:getCharacterTraits()
        if on then traits:add(entry) else traits:remove(entry) end
    end)
    DanTraits_TraitsChanged(player)
    return ok
end

local function relapseRoll()
    if ZombRand then return ZombRand(100) < ALC_RELAPSE_ODDS end
    return math.random(100) <= ALC_RELAPSE_ODDS
end

local add = DanTraits_StatAdd

local function clearWithdrawal(d)
    d.withdrawing, d.alcStage, d.alcW, d.alcShakes = false, 0, 0, 0
end

-- a random hallucination from the Hallucinations trait's set, if it is loaded
local function hallucinate(player)
    local ep = DanTraits_Episodes
    if not ep then return end
    local roll = ZombRand(100)
    local fn = (roll < 30 and ep.whisper) or (roll < 55 and ep.footsteps) or (roll < 70 and ep.sound)
        or (roll < 85 and ep.thump) or ep.charge
    local ok, done = pcall(fn, player)
    if ok and done == false and ep.sound then pcall(ep.sound, player) end
end

-- down on the floor, whatever was in hand dropped, hurt, scared and wiped out
local function seize(player, stats)
    if DanTraits_FumbleDrop then pcall(DanTraits_FumbleDrop, player) end
    pcall(function()
        player:setBumpType("stagger")
        player:setVariable("BumpDone", false)
        player:setVariable("BumpFall", true)
        player:setVariable("BumpFallType", "pushedFront")
    end)
    add(stats, CharacterStat.PAIN, ALC_SEIZE_PAIN)
    add(stats, CharacterStat.PANIC, ALC_SEIZE_PANIC)
    add(stats, CharacterStat.FATIGUE, ALC_SEIZE_FATIGUE)
    notify(player, "UI_DanTraits_AlcoholicSeizure")
end

local STAGE_NOTICE = { "UI_DanTraits_DependentCraving", "UI_DanTraits_AlcoholicShakes", "UI_DanTraits_AlcoholicDelirium" }

-- withdrawal and its relief, for a character who has the trait
local function withdrawal(player, d, stats, intox, meter)
    if intox > DEP_SATED_MIN + DEP_SATED_TOL * meter then
        d.dryHours = 0
        if d.withdrawing then notify(player, "UI_DanTraits_DependentSated") end
        clearWithdrawal(d)
        return
    end

    local dry = (d.dryHours or 0) + TICK_H
    d.dryHours = dry
    local onset = 1 - DEP_TOL_ONSET_CUT * meter
    local stage = 0
    if dry >= DRY_HOURS_STRESS * onset then stage = 1 end
    if dry >= DRY_HOURS_PAIN * onset then stage = 2 end
    if dry >= DRY_HOURS_DT * onset and meter >= ALC_DT_METER then stage = 3 end
    if stage == 0 then clearWithdrawal(d) return end

    local fade = 1 - (1 - ALC_LINGER) * math.max(0, math.min(1, (dry - ALC_PEAK_H) / ALC_FADE_H))
    local w = meter * fade
    d.withdrawing, d.alcW = true, w
    if stage > (d.alcStage or 0) then notify(player, STAGE_NOTICE[stage]) end
    d.alcStage = stage

    local asleep = DanTraits_Asleep(player)

    -- STRESS is 0..1, the rest 0..100
    add(stats, CharacterStat.STRESS, DEP_STRESS_RATE * w)
    add(stats, CharacterStat.UNHAPPINESS, ALC_MOOD_RATE * w)
    if stage < 2 then d.alcShakes = 0 return end

    d.alcShakes = ALC_SHAKE_DROP * w
    add(stats, CharacterStat.PAIN, DEP_PAIN_RATE * w)
    pcall(function() DanTraits_FloorUp(stats, CharacterStat.FOOD_SICKNESS, ALC_SICK * w, ALC_SICK_RAMP) end)
    if stage < 3 or asleep then return end

    if ZombRand(10000) < ALC_SEIZE_CHANCE * w * 10000 then
        seize(player, stats)
    elseif ZombRand(1000) < ALC_HALLU_CHANCE * w * 1000 then
        hallucinate(player)
    end
end

local function updateDependent(player, d)
    local stats = player:getStats()
    local intox = fraction(stats, CharacterStat.INTOXICATION)
    local has = hasTrait(player, "dependent")
    local meter = d.depTolerance or 0

    -- taken at creation (or carried over from before the meter existed)
    if has and not d.alcInit then
        meter = math.max(meter, ALC_START)
        d.alcInit = true
    end

    -- the day's cap on how much drinking can add
    d.alcDayTicks = (d.alcDayTicks or 0) + 1
    if d.alcDayTicks >= 144 then d.alcDayTicks, d.alcDayGain = 0, 0 end

    local drinking = intox >= DRINK.any
    if drinking then
        local gain = math.min(intox * TICK_H / ALC_BUILD_H, ALC_DAY_CAP - (d.alcDayGain or 0))
        if gain > 0 then
            meter = math.min(1, meter + gain)
            d.alcDayGain = (d.alcDayGain or 0) + gain
        end
        d.alcSoberHours = 0
    else
        meter = math.max(0, meter - TICK_H / ALC_DECAY_H)
        d.alcSoberHours = (d.alcSoberHours or 0) + TICK_H
    end

    if not has then
        -- once an Alcoholic, the first drink of every session risks it all
        if drinking and not d.alcDrinking and d.alcEx and relapseRoll() and setTrait(player, true) then
            has = true
            meter = math.max(meter, ALC_RELAPSE)
            d.alcInit, d.dryHours = true, 0
            clearWithdrawal(d)
            notify(player, "UI_DanTraits_AlcoholicRelapse")
        elseif meter >= ALC_GAIN and setTrait(player, true) then
            has = true
            d.alcInit, d.dryHours = true, 0
            clearWithdrawal(d)
            notify(player, "UI_DanTraits_AlcoholicGained")
        end
    elseif d.alcSoberHours >= ALC_CURE_H - TICK_H / 2 and setTrait(player, false) then
        has = false
        meter = 0
        d.alcEx, d.alcInit, d.dryHours = true, false, 0
        clearWithdrawal(d)
        DanTraits_NotifyGood(player, "UI_DanTraits_AlcoholicCured")
    end
    d.alcDrinking = drinking
    d.depTolerance = meter

    if has then withdrawal(player, d, stats, intox, meter) end
end
DanTraits_Every("ten", "Dependent", updateDependent, 10)

local function withdrawalOf(player, d)
    if not d or not d.withdrawing or not hasTrait(player, "dependent") then return 0 end
    return d.alcW or 0
end

-- 0..1 alcohol withdrawal strength of this character now; read by Hallucinations
function DanTraits_AlcoholWithdrawal(player)
    if not player then return 0 end
    return withdrawalOf(player, player:getModData().DanTraits)
end

-- withdrawal: light, broken sleep
DanTraits_AddHook("sleepWake", function(m, player, d)
    local w = withdrawalOf(player, d)
    if w <= 0 then return nil end
    return m * (1 + ALC_SLEEP_WAKE * w)
end)
DanTraits_AddHook("nightQuality", function(quality, player, d)
    local w = withdrawalOf(player, d)
    if w <= 0 then return nil end
    return quality * (1 - ALC_SLEEP_CUT * w)
end)

-- the shakes: added to every weapon swing's drop chance (percent)
DanTraits_AddHook("swingDrop", function(chance, player)
    local d = player:getModData().DanTraits
    if withdrawalOf(player, d) <= 0 then return nil end
    return chance + (d.alcShakes or 0)
end)

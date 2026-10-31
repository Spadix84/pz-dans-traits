-- Project Zomboid Vitality Project: Smoker, the mod's own trait (DanTraits:smoker).
-- Not only for Smokers: anyone who smokes carries the nicotine meter.
--
-- Until Age 2.0 (2026-10-31) this reworked vanilla's Smoker: the script
-- re-costed it and the file leaned on the game's Java for the craving (the
-- NICOTINE_WITHDRAWAL stat rising between cigarettes and a cigarette clearing
-- it for a Smoker, with stress and unhappiness from it). The mod now leaves
-- vanilla's trait alone and has its own: vanilla's Smoker is hidden at
-- creation unless the sandbox shows it (SmokerVanillaShown; the two exclude
-- each other, and a vanilla Smoker is then a plain vanilla smoker to this
-- file). The craving is this file's: it owns the stat's rise (NIC_RISE_H at
-- pace 1, scaled by the habit as before), it clears the stat when a Smoker
-- smokes, and it adds the stress and unhappiness withdrawal brings. The game
-- still treats the character as a non-smoker when they smoke (it has no flag
-- to see): the nausea it adds is taken straight back off, by tolerance, as a
-- regular smoker's always was. A save from before: a character with vanilla
-- Smoker and this file's data (the habit meter, or the craving stat above
-- zero) is converted once on load, vanilla off and ours on, with a notice;
-- one with vanilla Smoker and no data (made with the mod off) is left alone.
--
-- What the mod adds to the habit:
--
-- Dependence. Everyone carries a nicotine meter (0..1, nicMeter). Tobacco
-- fills it, but only so much a day, so it is the habit that counts; it
-- drains over a month. Past NIC_GAIN the character becomes a Smoker, in
-- about a week of four or more a day. A cigarette holds the craving off for
-- an hour and a half; then the meter sets how fast it builds: a full
-- craving in eight hours for a Smoker taken at creation, slower for a
-- light smoker, nearly twice as fast for a heavy one, and faster again while
-- drunk. Three weeks without tobacco breaks the trait; the withdrawal
-- peaks in the first three days and eases over the rest. An ex-smoker
-- still gets cravings when drunk or badly stressed for three months, and
-- the first smoke of a session is a coin flip to relapse.
--
-- What a cigarette does. To someone without the habit: a head rush, a lift
-- in mood, sharper and less bored for a while. The buzz and the nausea
-- both fade as tolerance builds. To a Smoker it is relief, and only as much
-- as the craving it answers: a cigarette in full withdrawal takes real
-- stress and misery off, a chain-smoked one barely anything.
--
-- Withdrawal: irritability (the vanilla Angry moodle, which nothing else in
-- the game raises; DanTraits_Anger.lua gives it its effects), more hunger,
-- and light, broken sleep. A cigarette just before bed keeps you on edge for an hour too. Nicotine gum (a rare item,
-- found with the cigarettes) takes most of the edge off a craving without
-- smoking and without resetting the three-week clock.
--
-- Lungs (nicLungs, 0..1): every cigarette, cigar or pipe adds a little,
-- chewing tobacco and gum nothing. A Smoker taken at creation starts with
-- years of it, by age (LUNG_START_BAND, from the Age band: a 20s smoker is
-- nearly clean, a 50s one starts with over half; 0.35 with Age off). Damaged lungs recover endurance slower (through the
-- enduranceRegen hook of the stat delta pipeline), and cough, more
-- often the worse the lungs and the stronger the habit, on exertion and
-- in the first hour after waking. Smoke gets into your clothes too: for
-- six hours after any smoke worn clothes go stale half as fast again (the
-- laundry's odour hook, DanTraits_Laundry.lua). The cough is the game's own, heard by
-- zombies, through the one shared cough (DanTraits_Util.lua: a single gap
-- across Smoker and Asthma). A Brittle Asthma character's airway is irritated
-- by every cigarette (DanTraits_AsthmaSmoked) and by damaged lungs (Asthma
-- reads nicLungs). The lungs heal slowly once the smoking stops: months, not days.
--
-- Smoking also speeds up how fast the body clears caffeine (up to twice
-- as fast), which the Caffeine and Sleep files read through the
-- "caffeineClearance" hook. It wears off within days of the last cigarette,
-- so an ex-smoker's usual coffee hits much harder.
--
-- A Smoker's wound infection climbs faster, by the meter (the
-- infectionGrowth hook of DanTraits_Infection.lua), and an unstitched deep
-- wound heals slower (the woundHeal hook of DanTraits_WoundCare.lua). The
-- lungs' recovery goes through the lungHeal hook (Vitality speeds it).
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local hasVanillaTrait = DanTraits_HasVanillaTrait
local notify = DanTraits_Notify
local traitData = DanTraits_Data
local fraction = DanTraits_StatFraction

-- dependence
local NIC_GAIN          = 0.30    -- meter at which the trait is gained
local NIC_START         = 0.50    -- meter for a character who takes the trait
local NIC_RELAPSE       = 0.50    -- meter set on relapse
local NIC_PER_CIG       = 0.025   -- meter per cigarette...
local NIC_DAY_CAP       = 0.08    -- ...but at most this much a day
local NIC_EX_GAIN       = 2       -- an ex-smoker gets hooked this much faster
local NIC_DECAY_H       = 720     -- hours to drain a full meter (30 days)
local NIC_CURE_H        = 504     -- hours without tobacco to lose the trait (21 days)
local NIC_SESSION_H     = 12      -- tobacco after this long without starts a new session
local NIC_RELAPSE_ODDS  = 50      -- percent chance per session for an ex-smoker to relapse
-- craving
local NIC_GRACE_H       = 1.5     -- hours after a whole cigarette before the craving builds (a drag: its share),
                                  -- divided by the cravingOnset hook (2026-10-31: it built from the first minute)
local NIC_RISE_H        = 4       -- hours from no craving to a full one at pace 1 (the stat's range; 3 until 2026-10-31)...
local NIC_RATE_BASE     = 0.125   -- ...x (this + NIC_RATE_METER x meter): half pace for a Smoker taken at creation
local NIC_RATE_METER    = 0.75
local NIC_RATE_DRUNK    = 1.5     -- and x this at Drunk level 2 or more
local NIC_DRUNK_LEVEL   = 2
local NIC_FADE_FROM_H   = 72      -- withdrawal peaks for three days...
local NIC_FADE_FLOOR    = 0.25    -- ...then its ceiling eases to this by the time the trait goes
local NIC_ANGER         = 0.4     -- irritability floor (0..1) at full withdrawal: Annoyed, not Angry (0.6 until 2026-10-31)
local NIC_ANGER_RAMP    = 0.01    -- per minute
local NIC_ANGER_MARGIN  = 0.002   -- held this far above the floor, clear of vanilla's per-tick drain
local NIC_CRAVE_ANGER   = 0.25    -- irritability that counts as showing, if the Angry moodle cannot be read
local NIC_HUNGER        = 0.0002  -- hunger per minute at full withdrawal
local NIC_SLEEP_WAKE    = 1       -- light wakes you (1 + this x withdrawal) times as easily
local NIC_SLEEP_CUT     = 0.2     -- night quality x (1 - this x withdrawal)
local NIC_STIM_H        = 1       -- hours a cigarette keeps you on edge...
local NIC_STIM_WAKE     = 1.5     -- ...light wakes you this much more easily meanwhile
-- a cigarette (fractions of the stat's range, per cigarette, one at most)
local NIC_RELIEF_STRESS = 0.10    -- x withdrawal before the smoke
local NIC_RELIEF_MOOD   = 0.10
local NIC_BUZZ_MOOD     = 0.08    -- x (1 - tolerance)
local NIC_BUZZ_BOREDOM  = 0.15
local NIC_BUZZ_FATIGUE  = 0.03
local NIC_BUZZ_SHOW     = 0.5     -- buzz at which "Head rush" shows
-- nicotine gum
local NIC_GUM_RELIEF    = 0.6     -- share of the craving (and the irritability) a piece takes away
local NIC_GUM_ITEM      = "DanTraits.NicotineGum"
-- ex-smokers
local NIC_CUE_H         = 2160    -- cravings on cue for 90 days after quitting, fading
local NIC_CUE_STRESS    = 0.5     -- stress (0..1) that sets one off (or Drunk level 2)
local NIC_CUE_ANGER     = 0.2     -- irritability floor for the next NIC_CUE_MIN, fresh off quitting
local NIC_CUE_MIN       = 60
local NIC_CUE_GAP_H     = 4
-- lungs
local LUNG_PER_CIG      = 0.0004  -- a pack a day: about 0.25 a month
local LUNG_START        = 0.35    -- a Smoker taken at creation has years behind them (Age off)...
local LUNG_START_BAND   = { [20] = 0.05, [30] = 0.15, [40] = 0.33, [50] = 0.55 }   -- ...or by age band
local LUNG_HEAL_AFTER_H = 24      -- no healing within a day of the last smoke
local LUNG_HEAL_H       = 2880    -- hours to heal fully damaged lungs (120 days)
local LUNG_ENDURANCE    = 0.3     -- endurance recovery x (1 - this x lungs)
local COUGH_RATE        = 0.004   -- chance per waking minute at full lungs and a full meter (one in four hours)
local COUGH_LUNGS       = 0.6     -- how much of that comes from the lungs...
local COUGH_METER       = 0.4     -- ...and how much from the habit (Smokers only)
local COUGH_EXERT       = 4       -- x this exerted (running, or endurance under COUGH_EXERT_ENDURANCE)
local COUGH_EXERT_ENDURANCE = 0.5
local COUGH_MORNING     = 5       -- x this in the first COUGH_MORNING_MIN after waking
local COUGH_MORNING_MIN = 60
-- wounds
local NIC_INF_GROWTH   = 0.2     -- wound infection climb x (1 + this x meter), Smokers only
local NIC_WOUND_HEAL   = 0.2     -- an unstitched deep wound heals x (1 - this x meter), Smokers only
local NIC_ODOUR        = 1.5     -- worn clothes go stale x this (the laundryOdour hook)...
local NIC_ODOUR_H      = 6       -- ...for this many hours after a smoke, anyone who smokes
-- caffeine
local CAF_INDUCE_PER_CIG = 0.1    -- caffeine clearance x (1 + induction), induction up to 1
local CAF_INDUCE_HALF_H  = 39

-- nicotine per item (cigarettes' worth), and whether it is smoked
local NIC_ITEMS = {
    cigarettepack = { 1, true }, cigarettesingle = { 1, true }, cigaretterolled = { 1, true },
    cigarillo = { 1.5, true }, cigar = { 3, true },
    smokingpipe_tobacco = { 2, true }, canpipe_tobacco = { 2, true },
    tobaccochewing = { 1, false },
}

local INDUCE_DECAY = 0.5 ^ (1 / (CAF_INDUCE_HALF_H * 60))
local MIN_H = 1 / 60

local clamp01 = DanTraits_Clamp01

local function isSmoker(player) return hasTrait(player, "smoker") end
DanTraits_IsSmoker = isSmoker

local function setSmoker(player, on) return DanTraits_SetTrait(player, "smoker", on) end

-- the lungs a Smoker taken at creation starts with: by age band when Age is on
local function lungStart(player)
    if DanTraits_AgeBand and DanTraits_SandboxOn("AgeEnabled") then
        local band = LUNG_START_BAND[DanTraits_AgeBand(player)]
        if band then return band end
    end
    return LUNG_START
end

local statMax = DanTraits_StatMax

-- add a fraction of the stat's range, clamped to it
local function addFrac(stats, stat, frac)
    if not stat then return end
    DanTraits_StatAdd(stats, stat, frac * statMax(stat))
end

local roll = DanTraits_RollPercent

local function drunkLevel(player)
    if not DanTraits_DrunkLevel then return 0 end
    return tonumber(DanTraits_DrunkLevel(player)) or 0
end

local function withdrawalStat() return CharacterStat and CharacterStat.NICOTINE_WITHDRAWAL end

-- nicotine in an item: cigarettes' worth and whether it is smoked; nil if none
local function nicotineOf(kind, item)
    local entry = NIC_ITEMS[string.lower(tostring(kind or ""))]
    if entry then return entry[1], entry[2] end
    local onEat = ""
    -- only food has getOnEat; calling a missing method trips debug mode's Break On Error even in a pcall
    if item and item.getOnEat then
        pcall(function() onEat = string.lower(tostring(item:getOnEat() or "")) end)
    end
    if string.find(onEat, "nicotine", 1, true) then return 1, true end
    return nil
end
DanTraits_NicotineOf = nicotineOf

local function smokerData(player)
    local d = traitData(player)
    d.nicMeter = d.nicMeter or 0
    d.nicLungs = d.nicLungs or 0
    return d
end

local function wakeWithdrawalClock(player)
    pcall(function() player:setTimeSinceLastSmoke(0) end)
end

-- irritability ---------------------------------------------------------------
-- Vanilla drains ANGER a little every tick. Topping it up once a minute let
-- it dip under a moodle threshold between top-ups, so the moodle flickered.
-- Instead the minute update sets a level (nicAnger, climbing a ramp at a
-- time towards the floor) and every frame holds ANGER at or above it.
-- Vanilla never raises ANGER and drains it slowly, so when the craving eases
-- (a cigarette, sleep, the habit winding down) the irritability it was
-- holding up is taken off with it; left to the drain, the Angry moodle
-- lingered for hours after the craving had gone.
local function holdAnger(stats, d)
    local hold = d.nicAnger or 0
    if hold <= 0 then return end
    pcall(function()
        if (stats:get(CharacterStat.ANGER) or 0) < hold then
            stats:set(CharacterStat.ANGER, math.min(1, hold + NIC_ANGER_MARGIN))
        end
    end)
end

-- the craving eased: take `by` off the hold and off ANGER with it
local function easeAnger(stats, d, by)
    by = math.min(by, d.nicAnger or 0)
    if by <= 0 then return end
    d.nicAnger = d.nicAnger - by
    pcall(function() stats:set(CharacterStat.ANGER, math.max(0, (stats:get(CharacterStat.ANGER) or 0) - by)) end)
end

local function setAngerFloor(stats, d, floor)
    local held = d.nicAnger or 0
    local hold = 0
    if floor > 0 then
        local now = 0
        pcall(function() now = stats:get(CharacterStat.ANGER) or 0 end)
        hold = math.min(floor, math.max(held, now) + NIC_ANGER_RAMP)
    end
    if hold < held then
        easeAnger(stats, d, held - hold)
    else
        d.nicAnger = hold
    end
    holdAnger(stats, d)
end

local function angryLevel(player, stats)
    local level
    if MoodleType and MoodleType.ANGRY then
        pcall(function() level = player:getMoodles():getMoodleLevel(MoodleType.ANGRY) end)
    end
    if level then return level end
    local anger = 0
    pcall(function() anger = stats:get(CharacterStat.ANGER) or 0 end)
    return anger >= NIC_CRAVE_ANGER and 1 or 0
end

-- the trait, gained ------------------------------------------------------------
local function becomeSmoker(player, d, textKey)
    if not setSmoker(player, true) then return false end
    d.nicInit, d.nicCueMin = true, 0
    d.nicDryHours = d.nicDryHours or 0
    local ws = withdrawalStat()
    if ws then pcall(function() d.nicLastW = player:getStats():get(ws) or 0 end) end
    wakeWithdrawalClock(player)
    notify(player, textKey)
    return true
end

-- a dose, after the vanilla effect has landed. pre holds what it acted on.
local function applyDose(player, dose, smoked, pre)
    local d = smokerData(player)
    local stats = player:getStats()
    local one = math.min(1, dose)

    -- a Smoker's relief is the craving answered
    if pre.smoker and pre.w > 0 then
        addFrac(stats, CharacterStat.STRESS, -NIC_RELIEF_STRESS * pre.w * one)
        addFrac(stats, CharacterStat.UNHAPPINESS, -NIC_RELIEF_MOOD * pre.w * one)
    end
    -- and the irritability goes with the craving it came from (an ex-smoker's cue too)
    easeAnger(stats, d, (d.nicAnger or 0) * one)
    if one >= 1 then d.nicCueMin = 0 end

    -- to anyone else a buzz, fading with tolerance, and so does the nausea
    local tolerance = pre.smoker and 1 or clamp01(pre.meter / NIC_GAIN)
    local buzz = one * (1 - tolerance)
    if buzz > 0 then
        addFrac(stats, CharacterStat.UNHAPPINESS, -NIC_BUZZ_MOOD * buzz)
        addFrac(stats, CharacterStat.BOREDOM, -NIC_BUZZ_BOREDOM * buzz)
        addFrac(stats, CharacterStat.FATIGUE, -NIC_BUZZ_FATIGUE * buzz)
        if buzz >= NIC_BUZZ_SHOW then
            DanTraits_NotifyGood(player, "UI_DanTraits_SmokerBuzz")
        end
    end
    if tolerance > 0 and pre.sick then
        pcall(function()
            local sick = stats:get(CharacterStat.FOOD_SICKNESS) or 0
            local added = sick - pre.sick
            if added > 0 then stats:set(CharacterStat.FOOD_SICKNESS, sick - added * tolerance) end
        end)
    end

    -- the habit
    local newSession = (d.nicDryHours == nil) or d.nicDryHours >= NIC_SESSION_H
    d.nicDryHours = 0
    d.nicStimH = math.max(d.nicStimH or 0, NIC_STIM_H * one)
    local onset = tonumber(DanTraits_RunHooks("cravingOnset", 1, player)) or 1   -- Age: sooner young
    d.nicGraceH = math.max(d.nicGraceH or 0, NIC_GRACE_H * one / onset)
    if smoked then
        d.nicSmokeHours = 0
        d.nicLungs = math.min(1, d.nicLungs + LUNG_PER_CIG * dose)
        d.nicInduce = math.min(1, (d.nicInduce or 0) + CAF_INDUCE_PER_CIG * dose)
    end
    local kindling = (d.nicEx and not pre.smoker) and NIC_EX_GAIN or 1
    -- the habitGain hook (Age: the young get hooked faster) scales the gain and the day's cap alike
    kindling = kindling * (tonumber(DanTraits_RunHooks("habitGain", 1, player)) or 1)
    local gain = math.min(NIC_PER_CIG * dose * kindling, NIC_DAY_CAP * kindling - (d.nicDayGain or 0))
    if gain > 0 then
        d.nicMeter = math.min(1, d.nicMeter + gain)
        d.nicDayGain = (d.nicDayGain or 0) + gain
    end
    d.nicTotal = (d.nicTotal or 0) + dose
    if smoked and DanTraits_AsthmaSmoked then DanTraits_AsthmaSmoked(player, dose) end
    if DanTraits_MddOnSmoke then DanTraits_MddOnSmoke(player, dose, smoked) end   -- MDD's relief (not the vanilla smoke clock)

    -- a vanilla Smoker (shown by the sandbox option) is a plain vanilla smoker: never ours on top
    if not isSmoker(player) and not hasVanillaTrait(player, "base:smoker") then
        if d.nicEx and newSession and roll(NIC_RELAPSE_ODDS) then
            if becomeSmoker(player, d, "UI_DanTraits_SmokerRelapse") then
                d.nicMeter = math.max(d.nicMeter, NIC_RELAPSE)
            end
        elseif d.nicMeter >= NIC_GAIN then
            becomeSmoker(player, d, "UI_DanTraits_SmokerGained")
        end
    end

    -- a Smoker's cigarette clears the craving (a whole one all of it, a drag its
    -- share); the next craving starts from here
    local ws = withdrawalStat()
    if ws then
        pcall(function()
            local w = stats:get(ws) or 0
            if pre.smoker or isSmoker(player) then
                w = math.max(0, w * (1 - one))
                stats:set(ws, w)
                wakeWithdrawalClock(player)
            end
            d.nicLastW = w
            d.nicWithdraw = isSmoker(player) and clamp01(w / statMax(ws)) or 0
        end)
    end
    return true
end

-- a dose of tobacco: note the state now, act once vanilla has had its turn
local function onTobacco(player, kind, item, portion)
    local dose, smoked = nicotineOf(kind, item)
    if not player or not dose then return false end
    dose = dose * math.max(0, math.min(1, portion or 1))
    if dose <= 0 then return false end
    local d = smokerData(player)
    local stats = player:getStats()
    local pre = { smoker = isSmoker(player), meter = d.nicMeter, w = 0 }
    local ws = withdrawalStat()
    if ws and pre.smoker then pre.w = fraction(stats, ws) end
    pcall(function() pre.sick = stats:get(CharacterStat.FOOD_SICKNESS) or 0 end)
    DanTraits_Later(1, function()
        if player and not player:isDead() then applyDose(player, dose, smoked, pre) end
    end, "smoker-dose")
    return true
end

-- cigarettes and cigars through the eat action (runs before vanilla's)
DanTraits_AddHook("eat", function(_, player, item, portion)
    if not item then return nil end
    local kind = ""
    pcall(function() kind = item:getType() end)
    onTobacco(player, kind, item, portion)
    return nil
end)
-- a pack or chewing tobacco through the pill action (before vanilla's)
DanTraits_AddHook("prePill", function(_, player, kind, item)
    onTobacco(player, kind, item, 1)
    return nil
end)

-- nicotine gum --------------------------------------------------------------------
function DanTraits_ChewNicotineGum(player)
    if not player then return false end
    local d = smokerData(player)
    local stats = player:getStats()
    local ws = withdrawalStat()
    if ws and isSmoker(player) then
        pcall(function()
            local w = (stats:get(ws) or 0) * (1 - NIC_GUM_RELIEF)
            stats:set(ws, w)
            d.nicLastW = w
            d.nicWithdraw = clamp01(w / statMax(ws))
            player:setTimeSinceLastSmoke(w / statMax(ws))
        end)
        pcall(function() stats:set(CharacterStat.ANGER, (stats:get(CharacterStat.ANGER) or 0) * (1 - NIC_GUM_RELIEF)) end)
        d.nicAnger = (d.nicAnger or 0) * (1 - NIC_GUM_RELIEF)
    end
    d.nicCueMin = 0
    d.nicStimH = math.max(d.nicStimH or 0, NIC_STIM_H * 0.5)
    if DanTraits_MddOnSmoke then DanTraits_MddOnSmoke(player, 0.4, false) end   -- a lesser relief for MDD
    DanTraits_NotifyGood(player, "UI_DanTraits_SmokerGum")
    return true
end

function DanTraits_IsNicotineGum(item) return DanTraits_IsItem(item, NIC_GUM_ITEM) end

DanTraits_AddHook("pill", function(_, player, kind)
    if string.lower(tostring(kind or "")) == "nicotinegum" then DanTraits_ChewNicotineGum(player) end
    return nil
end)

-- every minute ----------------------------------------------------------------------
-- 0..1: how much of the withdrawal the three-week wind-down still allows
local function fadeCeiling(dryHours)
    if dryHours <= NIC_FADE_FROM_H then return 1 end
    local t = clamp01((dryHours - NIC_FADE_FROM_H) / (NIC_CURE_H - NIC_FADE_FROM_H))
    return 1 - (1 - NIC_FADE_FLOOR) * t
end

-- the shared cough keeps the gap between coughs (Asthma's included)
local function cough(player, d)
    if DanTraits_Cough(player, nil, "smoker") then d.nicCoughs = (d.nicCoughs or 0) + 1 end   -- the game's own cough, at its radius
end

local function exerted(player, stats)
    local running = false
    pcall(function() running = player:isSprinting() or player:isRunning() end)
    if running then return true end
    local endurance = 1
    pcall(function() endurance = stats:get(CharacterStat.ENDURANCE) or 1 end)
    return endurance < COUGH_EXERT_ENDURANCE
end

local function updateSmokerMinute(player, d)
    local smoker = isSmoker(player)
    -- nothing to do for someone who has never touched tobacco
    if not smoker and not d.nicMeter then return end
    d = smokerData(player)
    local stats = player:getStats()

    if smoker and not d.nicInit then
        d.nicInit = true
        d.nicMeter = math.max(d.nicMeter, NIC_START)
        d.nicLungs = math.max(d.nicLungs, lungStart(player))
        d.nicDryHours = d.nicDryHours or 0
    end

    -- the day's cap on how much tobacco can add
    d.nicDayMin = (d.nicDayMin or 0) + 1
    if d.nicDayMin >= 1440 then d.nicDayMin, d.nicDayGain = 0, 0 end

    d.nicMeter = math.max(0, d.nicMeter - MIN_H / NIC_DECAY_H)
    if d.nicDryHours then d.nicDryHours = d.nicDryHours + MIN_H end
    if d.nicSmokeHours then d.nicSmokeHours = d.nicSmokeHours + MIN_H end
    if d.nicLungs > 0 and (d.nicSmokeHours or LUNG_HEAL_AFTER_H) >= LUNG_HEAL_AFTER_H then
        d.nicLungs = math.max(0, d.nicLungs - DanTraits_RunHooks("lungHeal", MIN_H / LUNG_HEAL_H, player, d))
    end
    if (d.nicInduce or 0) > 0 then
        d.nicInduce = d.nicInduce * INDUCE_DECAY
        if d.nicInduce < 0.001 then d.nicInduce = 0 end
    end
    if (d.nicStimH or 0) > 0 then d.nicStimH = math.max(0, d.nicStimH - MIN_H) end
    local grace = (d.nicGraceH or 0) > MIN_H / 2   -- clear of the float left after the last minute
    d.nicGraceH = grace and d.nicGraceH - MIN_H or nil

    local asleep = DanTraits_Asleep(player)
    if asleep then
        d.nicSleptMin = (d.nicSleptMin or 0) + 1
    else
        if (d.nicSleptMin or 0) >= 60 then d.nicMorningMin = COUGH_MORNING_MIN end
        d.nicSleptMin = 0
    end
    local ws = withdrawalStat()

    -- three weeks clean breaks it
    if smoker and (d.nicDryHours or 0) >= NIC_CURE_H - MIN_H / 2 and setSmoker(player, false) then
        smoker = false
        d.nicMeter, d.nicEx, d.nicInit, d.nicExHours, d.nicWithdraw = 0, true, false, 0, 0
        if ws then pcall(function() stats:set(ws, 0) end) end
        DanTraits_NotifyGood(player, "UI_DanTraits_SmokerCured")
    end

    local drunk = drunkLevel(player) >= NIC_DRUNK_LEVEL
    local angerK = tonumber(DanTraits_RunHooks("angerFloor", 1, player)) or 1   -- Age: hotter young
    local angerFloor = 0
    if smoker and ws then
        -- the craving builds at the habit's pace (the stat is this file's: the game
        -- only moves it for its own Smoker) once a smoke's grace is over, capped as
        -- the habit winds down
        pcall(function()
            local max = statMax(ws)
            local w = stats:get(ws) or 0   -- as it stands: the gum and a cigarette move it too
            if not grace then
                local rate = NIC_RATE_BASE + NIC_RATE_METER * d.nicMeter
                if drunk then rate = rate * NIC_RATE_DRUNK end
                rate = rate * (tonumber(DanTraits_RunHooks("cravingOnset", 1, player)) or 1)   -- Age: sooner young
                w = w + max * rate * MIN_H / NIC_RISE_H
            end
            w = math.min(w, max * fadeCeiling(d.nicDryHours or 0), max)
            stats:set(ws, w)
            d.nicLastW = w
            d.nicWithdraw = clamp01(w / max)
        end)
        if not asleep and (d.nicWithdraw or 0) > 0 then
            angerFloor = math.min(1, NIC_ANGER * d.nicWithdraw * angerK)
            addFrac(stats, CharacterStat.HUNGER, NIC_HUNGER * d.nicWithdraw)
            -- no stress or mood of the mod's own: the game's Stress moodle reads the
            -- withdrawal stat on top of STRESS for everyone (Stats.getNicotineStress), so
            -- the craving already shows and counts as stress, as it did for vanilla's Smoker
            -- told to the stat delta pipeline, or next minute it reads the rise as the
            -- game's and Age and Bottomless Pit scale it again (the shape Pace Yourself uses)
            pcall(function() DanTraits_DeltaRemember(d, "hungerRise", stats:get(CharacterStat.HUNGER)) end)
        end
    else
        d.nicWithdraw = 0
    end

    -- an ex-smoker: a drink or a bad moment brings it back for a while
    if not smoker and d.nicEx then
        d.nicExHours = (d.nicExHours or 0) + MIN_H
        d.nicCueGapH = math.max(0, (d.nicCueGapH or 0) - MIN_H)
        local strength = 1 - d.nicExHours / NIC_CUE_H
        local stress = 0
        pcall(function() stress = fraction(stats, CharacterStat.STRESS) end)
        -- Burnt Out on strain counts as a bad moment too (DanTraits_Strain.lua)
        local burnt = DanTraits_StrainTier ~= nil and DanTraits_StrainTier(player) >= 3
        local cue = strength > 0 and not asleep and (drunk or stress >= NIC_CUE_STRESS or burnt)
        if cue and not d.nicCue and d.nicCueGapH <= 0 then
            d.nicCueMin, d.nicCueGapH = NIC_CUE_MIN, NIC_CUE_GAP_H
            notify(player, "UI_DanTraits_SmokerCue")
        end
        d.nicCue = cue
        if (d.nicCueMin or 0) > 0 then
            d.nicCueMin = d.nicCueMin - 1
            if strength > 0 and not asleep then angerFloor = math.max(angerFloor, math.min(1, NIC_CUE_ANGER * strength * angerK)) end
        end
    end
    setAngerFloor(stats, d, angerFloor)
    -- say why, once, when the craving first shows as the Angry moodle (not
    -- with the craving moodle hidden: then the player reads it from the mood)
    if smoker and (d.nicAnger or 0) > 0 then
        if not d.nicCraveShown and angryLevel(player, stats) > 0 then
            d.nicCraveShown = true
            if DanTraits_SandboxOn("SmokerCravingMoodle") then notify(player, "UI_DanTraits_SmokerCraving") end
        end
    elseif (d.nicAnger or 0) <= 0 then
        d.nicCraveShown = nil
    end

    -- the cough, worst in the first hour after a real sleep
    if not asleep then
        local chance = COUGH_RATE * (COUGH_LUNGS * d.nicLungs + (smoker and COUGH_METER * d.nicMeter or 0))
        if chance > 0 then
            if exerted(player, stats) then chance = chance * COUGH_EXERT end
            if (d.nicMorningMin or 0) > 0 then chance = chance * COUGH_MORNING end
            if roll(chance * 100) then cough(player, d) end
        end
    end
    if (d.nicMorningMin or 0) > 0 then d.nicMorningMin = d.nicMorningMin - 1 end
end

-- per frame: hold the irritability
local function updateSmokerFrame(player, d)
    d = d or player:getModData().DanTraits   -- the driver hands it over; the tests call this bare
    if d and (d.nicAnger or 0) > 0 then holdAnger(player:getStats(), d) end
end
DanTraits_updateSmokerFrame = updateSmokerFrame

-- damaged lungs recover endurance slower: x (1 - LUNG_ENDURANCE x lungs)
DanTraits_AddHook("enduranceRegen", function(delta, player, d)
    if not d or (d.nicLungs or 0) <= 0 then return nil end
    return delta * (1 - LUNG_ENDURANCE * d.nicLungs)
end)

-- read by other systems ----------------------------------------------------------
-- 0..1 craving strength now, for a Smoker (Migraines reads it as a trigger)
function DanTraits_NicotineWithdrawal(player)
    local d = player and player:getModData().DanTraits
    if not d or (d.nicWithdraw or 0) <= 0 or not isSmoker(player) then return 0 end
    return d.nicWithdraw
end

DanTraits_AddHook("caffeineClearance", function(k, player)
    local d = player and player:getModData().DanTraits
    if not d or (d.nicInduce or 0) <= 0 then return nil end
    return k * (1 + d.nicInduce)
end)

DanTraits_AddHook("sleepWake", function(m, player, d)
    if not d then return nil end
    local w = (d.nicWithdraw or 0) > 0 and DanTraits_NicotineWithdrawal(player) or 0
    local stim = (d.nicStimH or 0) > 0
    if w <= 0 and not stim then return nil end
    m = m * (1 + NIC_SLEEP_WAKE * w)
    if stim then m = m * NIC_STIM_WAKE end
    return m
end)

DanTraits_AddHook("nightQuality", function(quality, player, d)
    local w = DanTraits_NicotineWithdrawal(player)
    if w <= 0 then return nil end
    return quality * (1 - NIC_SLEEP_CUT * w)
end)

-- smoking slows wound healing: an infection climbs faster (DanTraits_Infection.lua)
DanTraits_AddHook("infectionGrowth", function(k, player)
    local d = player and player:getModData().DanTraits
    if not d or (d.nicMeter or 0) <= 0 or not isSmoker(player) then return nil end
    return k * (1 + NIC_INF_GROWTH * d.nicMeter)
end)

-- and so does an unstitched deep wound (DanTraits_WoundCare.lua)
DanTraits_AddHook("woundHeal", function(rate, player)
    local d = player and player:getModData().DanTraits
    if not d or (d.nicMeter or 0) <= 0 or not isSmoker(player) then return nil end
    return rate * (1 - NIC_WOUND_HEAL * d.nicMeter)
end)

-- smoke gets into your clothes: for a few hours after a cigarette, cigar or
-- pipe (anyone's, habit or not) worn clothes go stale faster (the laundry's
-- odour rate, DanTraits_Laundry.lua), on top of Sweaty or Cool Customer
DanTraits_AddHook("laundryOdour", function(k, player)
    local d = player and player:getModData().DanTraits
    if not d or not d.nicSmokeHours or d.nicSmokeHours >= NIC_ODOUR_H then return nil end
    return k * NIC_ODOUR
end)

-- a save from before the mod's own Smoker: vanilla's trait with this file's
-- data behind it becomes ours, once; vanilla's with no data is a plain vanilla smoker
local function convertOldSmoker(player)
    if not player then return end
    local d = traitData(player)
    if d.nicConverted then return end
    d.nicConverted = true
    if isSmoker(player) or not hasVanillaTrait(player, "base:smoker") then return end
    local w = 0
    local ws = withdrawalStat()
    if ws then pcall(function() w = player:getStats():get(ws) or 0 end) end
    if not (d.nicInit or (d.nicMeter or 0) > 0 or w > 0) then return end
    DanTraits_SetTrait(player, "base:SMOKER", false)
    if setSmoker(player, true) then notify(player, "UI_DanTraits_SmokerConverted") end
end
DanTraits_OnPlayerReady("SmokerConvert", convertOldSmoker, 35)

DanTraits_Every("minute", "Smoker", updateSmokerMinute, 40)
DanTraits_Every("frame", "Smoker", updateSmokerFrame, 40, { active = function(player, d) return d ~= nil and (d.nicAnger or 0) > 0 end })   -- frames only while anger is held

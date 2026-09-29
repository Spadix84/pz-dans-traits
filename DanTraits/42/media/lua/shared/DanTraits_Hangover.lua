-- Project Zomboid Vitality Project: Hangovers.
-- Not a trait: every character has it. Drinking past a light buzz builds a
-- "load" (drunk-hours weighted by how drunk). When the character sobers up
-- with enough load behind them a hangover is set: if they are asleep it
-- waits for them to wake, and either way it lasts at least HO_BASE_HOURS
-- after they are up, more for a heavier night. Symptoms scale with
-- severity and fade over the last two hours: a headache (pain, which
-- painkillers can take the edge off), a low mood, thirst that keeps coming
-- back, tiredness, and nausea after a really heavy one. A drink while
-- hungover hides the symptoms and stops the clock, and counts toward the
-- next one. The night's sleep is scored lower too. Alcohol tolerance
-- (Alcoholic) blunts it a little.
require "DanTraits"

local notify = DanTraits_Notify
local traitData = DanTraits_Data
local fraction = DanTraits_StatFraction

local DRINK = DanTraits_DRINK or { any = 0.01, tipsy = 0.05, buzz = 0.2, sober = 0.05 }  -- buzz: load builds above it; sober: below it a session ends
local HO_LOAD_MIN       = 0.5     -- drunk-hours needed for any hangover at all
local HO_LOAD_FULL      = 3.0     -- drunk-hours for a full-severity one
local HO_SEV_MIN        = 0.25
local HO_BASE_HOURS     = 6       -- at least this long after waking (or sobering, if awake)
local HO_EXTRA_HOURS    = 6       -- added at full severity
local HO_FADE_HOURS     = 2       -- symptoms taper over the last two hours
local HO_TOLERANCE_CUT  = 0.3     -- severity x (1 - this x tolerance)
local HO_SLEEP_CUT      = 0.3     -- night quality x (1 - this x severity)
local HO_PAIN           = 35      -- pain floor at full strength (skipped while painkillers work)
local HO_MOOD           = 25      -- unhappiness floor
local HO_MOOD_RAMP      = 1
local HO_FATIGUE        = 0.0008  -- per minute
local HO_THIRST         = 0.0010  -- per minute
local HO_STRESS         = 0.0003  -- per minute
local HO_SICK           = 25      -- food sickness floor, only past HO_SICK_FROM severity
local HO_SICK_FROM      = 0.6
local HO_TIER           = { 0.25, 0.5, 0.75 }   -- Hungover | Rough | Wrecked

local function hoData(player)
    local d = traitData(player)
    d.hoLoad = d.hoLoad or 0
    return d
end

local clamp01 = DanTraits_Clamp01

-- 0..1 current symptom strength (severity x fade), for the moodle and other systems
local function hangoverStrength(d)
    if not d or not d.hoActive then return 0 end
    local fade = math.min(1, (d.hoHoursLeft or 0) / HO_FADE_HOURS)
    return (d.hoSeverity or 0) * fade
end
function DanTraits_HangoverStrength(player)
    local d = player and player:getModData().DanTraits
    return hangoverStrength(d)
end

local function updateMoodle(player, strength)
    DanTraits_BadMoodle(player, "Hangover", strength, HO_TIER)
end

local floorUp = DanTraits_FloorUp

local function startHangover(player, d)
    d.hoActive = true
    d.hoPending = false
    d.hoHoursLeft = math.max(d.hoHoursLeft or 0, HO_BASE_HOURS + HO_EXTRA_HOURS * d.hoSeverity)
    local tier = 0
    for i, threshold in ipairs(HO_TIER) do if d.hoSeverity >= threshold then tier = i end end
    notify(player, "UI_DanTraits_Hangover" .. math.max(1, tier))
end

local function armHangover(player, d, asleep)
    local tolerance = DanTraits_AlcoholTolerance and DanTraits_AlcoholTolerance(player) or 0
    local severity = clamp01(math.max(HO_SEV_MIN, d.hoLoad / HO_LOAD_FULL) * (1 - HO_TOLERANCE_CUT * tolerance))
    d.hoSeverity = math.max(d.hoActive and d.hoSeverity or 0, severity)
    d.hoLoad = 0
    if asleep then
        d.hoPending = true
    else
        startHangover(player, d)
    end
end

local function updateHangoverMinute(player, d)
    d = hoData(player)
    local stats = player:getStats()
    local intox = fraction(stats, CharacterStat.INTOXICATION)
    local asleep = DanTraits_Asleep(player)

    -- drinking: build the load; a drink mid-hangover pauses it
    local drinking = intox > DRINK.buzz
    if drinking then
        d.hoLoad = d.hoLoad + (intox - DRINK.buzz) / (1 - DRINK.buzz) / 60
        d.hoDrinking = true
    elseif intox < DRINK.sober and d.hoDrinking then
        d.hoDrinking = false
        if d.hoLoad >= HO_LOAD_MIN then armHangover(player, d, asleep) else d.hoLoad = 0 end
    end

    -- waking up: a pending hangover starts; an active one gets its six hours back
    local wasAsleep = d.hoAsleep or false
    d.hoAsleep = asleep
    if wasAsleep and not asleep then
        if d.hoPending then
            startHangover(player, d)
        elseif d.hoActive then
            d.hoHoursLeft = math.max(d.hoHoursLeft or 0, HO_BASE_HOURS)
        end
    end

    if not d.hoActive then
        updateMoodle(player, 0)
        return
    end

    -- the clock only runs while up and sober-ish
    if not asleep and not drinking then
        d.hoHoursLeft = (d.hoHoursLeft or 0) - 1 / 60
        if d.hoHoursLeft <= 0 then
            d.hoActive, d.hoHoursLeft, d.hoSeverity = false, 0, 0
            updateMoodle(player, 0)
            DanTraits_NotifyGood(player, "UI_DanTraits_HangoverOver")
            return
        end
    end

    local s = hangoverStrength(d)
    if drinking or asleep then s = 0 end   -- hair of the dog hides it; sleep is a break from it
    updateMoodle(player, s)
    if s <= 0 then return end
    pcall(function()
        local meds = 0
        pcall(function() meds = player:getPainEffect() or 0 end)
        if meds <= 0 then floorUp(stats, CharacterStat.PAIN, HO_PAIN * s, HO_MOOD_RAMP) end
        floorUp(stats, CharacterStat.UNHAPPINESS, HO_MOOD * s, HO_MOOD_RAMP)
        stats:set(CharacterStat.FATIGUE, math.min(1, (stats:get(CharacterStat.FATIGUE) or 0) + HO_FATIGUE * s))
        stats:set(CharacterStat.THIRST, math.min(1, (stats:get(CharacterStat.THIRST) or 0) + HO_THIRST * s))
        stats:set(CharacterStat.STRESS, math.min(1, (stats:get(CharacterStat.STRESS) or 0) + HO_STRESS * s))
        if d.hoSeverity >= HO_SICK_FROM then
            floorUp(stats, CharacterStat.FOOD_SICKNESS, HO_SICK * s, HO_MOOD_RAMP)
        end
    end)
end
DanTraits_updateHangoverMinute = updateHangoverMinute

-- the night's sleep is worse for it
DanTraits_AddHook("nightQuality", function(quality, player, d)
    if not d or not (d.hoPending or d.hoActive or d.hoDrinking) then return nil end
    local severity = d.hoSeverity or 0
    if d.hoDrinking then severity = math.max(severity, clamp01((d.hoLoad or 0) / HO_LOAD_FULL)) end
    return quality * (1 - HO_SLEEP_CUT * severity)
end)

DanTraits_Every("minute", "Hangover", updateHangoverMinute, 40)

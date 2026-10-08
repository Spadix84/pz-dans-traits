-- Project Zomboid Vitality Project: Migraines.
-- Every ten minutes there is a small chance of an attack, pushed up by a
-- bad night (Vitality's sleep debt), thirst, stress, a hangover, nicotine
-- withdrawal, caffeine withdrawal, a wound infection's fever, bright
-- daylight outdoors, sleeping with the light on, heat (hot air or an
-- overheated body), the smell of corpses close by and a storm on the way (in
-- the twelve hours before the forecast says it starts), and never
-- within a day of the last one. An aura gives
-- twenty minutes' warning. The attack lasts three to six hours by severity:
-- pain (a DanTraits_PainFloor floor), nausea, low mood and stress. Daylight
-- outdoors slows the recovery to half and adds to the pain; awake indoors (or
-- out of the sun), a lit room adds pain and slows it, a dark one speeds it;
-- sleeping it off is twice as fast, in the dark (a lit room loses the
-- benefit), and during an attack light wakes you twice as easily.
-- Sunglasses (MIG_SHADES, or any worn item named sunglasses or shades) halve
-- the pain the light adds. The attack blurs the screen with the game's own
-- Short Sighted blur: the game blurs when Short Sighted and wearing glasses
-- disagree, and only works that out when clothing changes, so for the attack
-- the trait is flipped whenever they agree (updateVisionEffects re-reads it),
-- and the character's own state (migBlur) is put back when it ends. That
-- brings Short Sighted's shorter sight and worse aim for the attack, too.
--
-- Everyone's triggers are their own. Eight of them are personal (bad sleep,
-- thirst, stress, light, hangovers, heat, corpses, storms): each character
-- draws three that hit twice as hard, and the other five count for half
-- (MIG_STRONG_N, MIG_STRONG_X, MIG_WEAK_X). Withdrawal, fever and a
-- concussion count the same for everyone. Nobody is told which: the trigger
-- that did the most to bring on an attack is noted, and once one of the
-- strong ones has done it twice (MIG_LEARN) the character works it out and
-- says so as the attack ends.
--
-- Treatment. Ordinary painkillers barely touch it: during an attack their
-- relief lasts about a third as long as on other pain, and the first dose
-- takes only a tenth off the time left. Sumatriptan (DanTraits.Sumatriptan,
-- on the shared medication list) is what works: in the system during the
-- aura it halves the attack to come; during an attack it ends it within two
-- hours and halves the pain and nausea meanwhile. Once per attack. Anyone
-- who takes it is heavy and a little clumsy for a day after (tiredness, and
-- a swing can slip: the gripSlip hook, see DanTraits_Arthritis.lua). A new
-- character with Migraines starts with a pack down to its last two tablets
-- (none with the Starting Medication sandbox option off).
--
-- Mod data: migSinceEnd, migAuraLeft, migSeverity, migActive, migHoursLeft,
-- migMedsUsed, migTripUsed ("aura" or "attack": when sumatriptan was
-- taken), migChance, migStrong (the character's three
-- strong triggers), migCause (the trigger behind this attack), migSeen
-- (attacks each trigger has brought on), migKnown (strong triggers worked
-- out), tripAfterMin (minutes of the sumatriptan after-effect left),
-- migKitGiven, migBlur (the character's own Short Sighted, true or false,
-- while the attack has flipped it), migGlare (0..1, the pain the light adds
-- right now against full sun, after sunglasses; the Light Too Bright moodle
-- in DanTraits_Moodles.lua; nil when the light adds none).
-- Console: migraine | migraine start | migraine triggers
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local traitData = DanTraits_Data

local MIG_BASE          = 0.3     -- percent per ten minutes, rested and calm
local MIG_SLEEP_DEBT    = 2.5     -- added at a full sleep debt
local MIG_THIRST        = 2.0     -- added at full thirst (from 30%)
local MIG_THIRST_FROM   = 0.3
local MIG_STRESS        = 2.0     -- added at full stress
local MIG_LIGHT         = 1.5     -- added in bright daylight outdoors
local MIG_HANGOVER      = 2.0     -- added at a full-strength hangover
local MIG_NICOTINE      = 1.5     -- added at full nicotine withdrawal (Smoker)
local MIG_CONCUSSION    = 3.0     -- added at the worst concussion
local MIG_FEVER         = 2.0     -- added at full fever (wound infection)
local MIG_CAFFEINE      = 2.0     -- added at full caffeine withdrawal (Caffeine Dependent)
local MIG_HEAT          = 2.0     -- added at full heat: the hotter of the air...
local MIG_HEAT_AIR      = { 27, 35 }      -- ...degrees C from the first to full...
local MIG_HEAT_BODY     = { 37.5, 38.5 }  -- ...and the body's temperature, from the first to full
local MIG_CORPSE        = 0.5     -- added per corpse within MIG_CORPSE_TILES...
local MIG_CORPSE_TILES  = 3
local MIG_CORPSE_MAX    = 3       -- ...counting up to this many
local MIG_STORM         = 1.5     -- added while a storm is forecast to start within...
local MIG_STORM_AHEAD_H = 12      -- ...this many hours (the pressure dropping ahead of the front)
local MIG_STORM_RAIN    = 0.1     -- rain intensity at which it has started anyway
local MIG_SLEEP_LIGHT   = 1.0     -- added asleep in a fully lit room (counts as light)
-- personal triggers
local MIG_PERSONAL      = { "sleep", "thirst", "stress", "light", "hangover", "heat", "corpses", "storm" }
local MIG_STRONG_N      = 3       -- strong triggers each character draws...
local MIG_STRONG_X      = 2       -- ...counting this much...
local MIG_WEAK_X        = 0.5     -- ...and the rest of the personal ones this much
local MIG_LEARN         = 2       -- attacks a strong trigger brings on before the character knows it
-- the attack
local MIG_REFRACTORY_H  = 24      -- no roll for this long after an attack ends
local MIG_AURA_H        = 20 / 60 -- warning before the pain
local MIG_SEV_MIN       = 0.5     -- severity is this plus up to 0.5
local MIG_HOURS_BASE    = 3       -- attack length: this plus MIG_HOURS_SEV x severity
local MIG_HOURS_SEV     = 3
local MIG_PAIN          = 60      -- pain floor at severity 1 (see DanTraits_PainFloor)
local MIG_PAIN_LIGHT    = 15      -- extra floor in daylight outdoors
local MIG_PAIN_ROOM     = 10      -- extra floor in a fully lit room (awake, out of the sun)
local MIG_ROOM_DARK     = 0.25    -- light level at or below this: a dark room...
local MIG_ROOM_LIT      = 0.60    -- ...at or above this: a lit one (the sleep system's readings)
local MIG_SICK          = 50      -- food sickness floor at severity 1 (an untreated attack is 25..50: Queasy)
local MIG_MOOD          = 15
local MIG_RAMP          = 1
local MIG_STRESS_RATE   = 0.0005  -- per minute
local MIG_LIGHT_RATE    = 0.5     -- recovery rate in daylight outdoors...
local MIG_SLEEP_RATE    = 2.0     -- ...and asleep in the dark (fully lit room: 1)
local MIG_LIT_RATE      = 0.75    -- awake, out of the sun: in a fully lit room...
local MIG_DARK_RATE     = 1.25    -- ...and a fully dark one
local MIG_SLEEP_WAKE    = 2       -- during an attack, light wakes you this much more easily
local MIG_NIGHT         = 0.3     -- night strength under this is day
local MIG_CLOUD         = 0.5     -- cloud cover under this is bright
local MIG_TIER          = { 0.01, 0.5, 0.8 }   -- Aura | Migraine | Splitting
local MIG_SHADES_GLARE  = 0.5     -- sunglasses: the light's extra pain x this
-- tinted eyewear; anything else worn whose name says sunglasses or shades counts too (other mods' items)
local MIG_SHADES = {
    ["Base.Glasses"] = true,                            -- Reflective Sunglasses
    ["Base.Glasses_Prescription"] = true,               -- Prescription Reflective Sunglasses
    ["Base.Glasses_Sun"] = true,                        -- Sunglasses
    ["Base.Glasses_Prescription_Sun"] = true,           -- Prescription Sunglasses
    ["Base.Glasses_SunCheap"] = true,                   -- Cheap Sunglasses
    ["Base.Glasses_Aviators"] = true,                   -- Aviator Glasses
    ["Base.Glasses_Prescription_Aviators"] = true,      -- Prescription Aviator Glasses
    ["Base.Glasses_CatsEye_Sun"] = true,                -- Cat-Eye Sunglasses
    ["Base.Glasses_Prescription_CatsEye_Sun"] = true,   -- Cat-Eye Prescription Sunglasses
    ["Base.Glasses_JackieO"] = true,                    -- Big Retro Sunglasses
    ["Base.Glasses_Prescription_JackieO"] = true,       -- Big Retro Prescription Sunglasses
    ["Base.Glasses_Macho"] = true,                      -- Fancy Reflective Sunglasses
    ["Base.Glasses_NewWave"] = true,                    -- New Wave Sunglasses
    ["Base.Glasses_Round_Shades"] = true,               -- Round Sunglasses
    ["Base.Glasses_Prescription_Round_Shades"] = true,  -- Round Prescription Sunglasses
    ["Base.Glasses_Round_HoloSkulls"] = true,           -- Hologram Skull Sunglasses
    ["Base.Glasses_Venetian"] = true,                   -- Venetian Sunglasses
    ["Base.Glasses_SkiGoggles"] = true,                 -- Ski Goggles (tinted)
    ["Base.Glasses_OldWeldingGoggles"] = true,          -- Old Welding Goggles (dark lenses)
}
-- treatment
local MIG_MEDS_CUT      = 0.9     -- painkillers, first time in an attack: hours left x this
local MIG_PILL_KEEP     = 0.35    -- painkillers in an attack: this share of their usual relief
local MIG_TRIP_AURA     = 0.5     -- sumatriptan in the aura: severity x this
local MIG_TRIP_HOURS    = 2       -- sumatriptan in an attack: over within this many hours...
local MIG_TRIP_EASE     = 0.5     -- ...pain and nausea x this meanwhile
local MIG_TRIP_AFTER_H  = 24      -- the after-effect, for anyone who takes it
local MIG_TRIP_FATIGUE  = 0.0002  -- tiredness a minute awake
local MIG_TRIP_SLIP     = 3       -- percent added to a swing's grip slip
local MIG_TRIP_ITEM     = "DanTraits.Sumatriptan"
local MIG_TRIP_START    = 2 / 6   -- a new character's pack: two of its six tablets left

local clamp01 = DanTraits_Clamp01

local function migData(player)
    local d = traitData(player)
    d.migSinceEnd = d.migSinceEnd or MIG_REFRACTORY_H
    return d
end

local function isPersonal(key)
    for _, k in ipairs(MIG_PERSONAL) do if k == key then return true end end
    return false
end

local function isStrong(d, key)
    for _, k in ipairs(d and d.migStrong or {}) do if k == key then return true end end
    return false
end

-- draw the character's strong triggers, once
local function rollTriggers(d)
    if d.migStrong then return end
    local pool = {}
    for i, k in ipairs(MIG_PERSONAL) do pool[i] = k end
    local strong = {}
    for _ = 1, MIG_STRONG_N do
        strong[#strong + 1] = table.remove(pool, ZombRand(#pool) + 1)
    end
    d.migStrong = strong
end

-- how much a trigger counts for this character (1 until the strong ones are drawn)
local function weightOf(d, key)
    if not d or not d.migStrong or not isPersonal(key) then return 1 end
    return isStrong(d, key) and MIG_STRONG_X or MIG_WEAK_X
end

-- bright daylight, outdoors: the trigger and the thing that makes an attack worse
local function inBrightLight(player)
    local bright = false
    pcall(function()
        if not player:isOutside() then return end
        local climate = getClimateManager()
        if climate:getNightStrength() >= MIG_NIGHT then return end
        if (climate:getRainIntensity() or 0) > 0.1 then return end
        if (climate:getCloudIntensity() or 0) >= MIG_CLOUD then return end
        bright = true
    end)
    return bright
end
DanTraits_InBrightLight = inBrightLight

local over = DanTraits_Over

-- 0..1 how hot: the hotter of the air around the character and their body
local function heatOf(player)
    local heat = 0
    heat = over(DanTraits_AirTemp(player) or 0, MIG_HEAT_AIR[1], MIG_HEAT_AIR[2])
    pcall(function()
        local t = player:getStats():get(CharacterStat.TEMPERATURE)
        if type(t) == "number" and t > 30 then heat = math.max(heat, over(t, MIG_HEAT_BODY[1], MIG_HEAT_BODY[2])) end
    end)
    return heat
end

-- a storm, heavy rain or a blizzard forecast to start within the next twelve
-- hours (today's or tomorrow's weather period), and not raining yet: the
-- pressure dropping ahead of the front. Once per storm, as the 24-hour
-- refractory outlasts the window.
local function stormComing()
    local coming = false
    pcall(function()
        local climate = getClimateManager()
        if (climate:getRainIntensity() or 0) >= MIG_STORM_RAIN then return end
        local now = getGameTime():getTimeOfDay()
        local forecaster = climate:getClimateForecaster()
        local days = { forecaster:getForecast(), forecaster:getForecast(1) }
        for i = 1, 2 do
            local day = days[i]
            if day then
                pcall(function()
                    if not day:isWeatherStarts() then return end   -- a period carried over from the day before has arrived already
                    if not (day:isHasStorm() or day:isHasTropicalStorm() or day:isHasHeavyRain() or day:isHasBlizzard()) then return end
                    local ahead = (i - 1) * 24 + day:getWeatherStartTime() - now
                    if ahead > 0 and ahead <= MIG_STORM_AHEAD_H then coming = true end
                end)
            end
        end
    end)
    return coming
end

-- awake, out of the sun: how lit (0..1) and how dark (0..1) the square is;
-- a dim room between the two readings is neither
local function roomLight(player)
    local level
    pcall(function()
        local square = player:getCurrentSquare() or player:getSquare()
        if square then level = square:getLightLevel(player:getPlayerNum()) end
    end)
    if not level then return 0, 0 end
    local side = 2 * clamp01((level - MIG_ROOM_DARK) / (MIG_ROOM_LIT - MIG_ROOM_DARK)) - 1
    return clamp01(side), clamp01(-side)
end

-- wearing sunglasses: a listed item, or anything worn named sunglasses or shades
local function wearingShades(player)
    local found = false
    pcall(function()
        local worn = player:getWornItems()
        for i = 0, worn:size() - 1 do
            local item = worn:getItemByIndex(i)
            if item then
                local name = string.lower(item:getDisplayName() or "")
                if MIG_SHADES[item:getFullType()] or name:find("sunglass", 1, true) or name:find("shades", 1, true) then
                    found = true
                    return
                end
            end
        end
    end)
    return found
end
DanTraits_WearingShades = wearingShades

-- the attack's blur: flip Short Sighted while it and wearing glasses agree
-- (the game blurs when they differ); put the character's own state back after
local function updateBlur(player, d, want)
    local trait = CharacterTrait and CharacterTrait.SHORT_SIGHTED
    if not trait then return end
    local have, glasses = nil, false
    pcall(function()
        have = player:getCharacterTraits():get(trait) == true
        glasses = player:isWearingGlasses() == true
    end)
    if have == nil then return end
    local target = have
    if want then
        if have == glasses then
            if d.migBlur == nil then d.migBlur = have end
            target = not have
        end
    elseif d.migBlur ~= nil then
        target = d.migBlur
        d.migBlur = nil
    end
    if target == have then return end
    if DanTraits_SetTrait(player, "base:SHORT_SIGHTED", target) then
        pcall(function() player:updateVisionEffects() end)
    end
end

-- 0..1 how lit the room is, while asleep (the sleep system's reading)
local function sleepLit(player)
    local lit = 0
    pcall(function()
        if not DanTraits_Asleep(player) then return end
        local d = player:getModData().DanTraits
        if d and d.slDark then lit = clamp01(-d.slDark) end
    end)
    return lit
end

-- a stat as 0..1 (the game's read is the only call that can fail: 0 then)
local function statOf(player, stat)
    local value = 0
    pcall(function() value = player:getStats():get(stat) or 0 end)
    return clamp01(tonumber(value) or 0)
end

-- another system's 0..1, when that system is loaded (its getters never throw)
local function strengthOf(getter, player)
    if not getter then return 0 end
    return clamp01(tonumber(getter(player)) or 0)
end

-- each trigger's share of the chance right now, before the character's weights (percent per ten minutes).
-- Each trigger is read on its own, so one that cannot be read leaves the others standing.
local function migraineParts(player)
    local parts = {}
    parts.sleep = MIG_SLEEP_DEBT * strengthOf(DanTraits_SleepDebt, player)
    local thirst = statOf(player, CharacterStat.THIRST)
    if thirst > MIG_THIRST_FROM then parts.thirst = MIG_THIRST * (thirst - MIG_THIRST_FROM) / (1 - MIG_THIRST_FROM) end
    parts.stress = MIG_STRESS * statOf(player, CharacterStat.STRESS)
    if DanTraits_HangoverStrength then parts.hangover = MIG_HANGOVER * strengthOf(DanTraits_HangoverStrength, player) end
    if DanTraits_NicotineWithdrawal then parts.nicotine = MIG_NICOTINE * strengthOf(DanTraits_NicotineWithdrawal, player) end
    if DanTraits_ConcussionStrength then parts.concussion = MIG_CONCUSSION * strengthOf(DanTraits_ConcussionStrength, player) end
    if DanTraits_CaffeineWithdrawalOf then parts.caffeine = MIG_CAFFEINE * strengthOf(DanTraits_CaffeineWithdrawalOf, player) end
    if DanTraits_InfectionFever then parts.fever = MIG_FEVER * strengthOf(DanTraits_InfectionFever, player) end
    parts.light = MIG_SLEEP_LIGHT * sleepLit(player) + (inBrightLight(player) and MIG_LIGHT or 0)
    parts.heat = MIG_HEAT * heatOf(player)
    if DanTraits_CorpsesNearby then parts.corpses = MIG_CORPSE * math.min(MIG_CORPSE_MAX, DanTraits_CorpsesNearby(player, MIG_CORPSE_TILES)) end
    if stormComing() then parts.storm = MIG_STORM end
    return parts
end

-- percent chance per ten minutes, with the character's own weights; and the
-- personal trigger doing the most right now (nil when none is)
local function migraineChance(player)
    local d = player:getModData().DanTraits
    local chance, cause, most = MIG_BASE, nil, 0
    for key, share in pairs(migraineParts(player)) do
        local weighted = share * weightOf(d, key)
        chance = chance + weighted
        if isPersonal(key) and weighted > most then cause, most = key, weighted end
    end
    return chance, cause
end
DanTraits_MigraineChance = migraineChance

local function updateMoodle(player, value)
    DanTraits_BadMoodle(player, "Migraine", value, MIG_TIER)
end

local floorUp = DanTraits_FloorUp

local function startAura(player, d, cause)
    d.migAuraLeft = MIG_AURA_H
    d.migSeverity = MIG_SEV_MIN + ZombRand(0, 51) / 100
    d.migCause = cause
    d.migTripUsed = nil
    notify(player, "UI_DanTraits_MigraineAura")
end

local function startAttack(player, d)
    d.migAuraLeft = nil
    d.migActive = true
    d.migHoursLeft = MIG_HOURS_BASE + MIG_HOURS_SEV * d.migSeverity
    d.migMedsUsed = false
    notify(player, "UI_DanTraits_MigraineStart")
end

-- the attack is over: note what brought it on, and say so once a strong trigger has been caught twice
local function learnCause(player, d)
    local cause = d.migCause
    d.migCause = nil
    if not cause then return end
    d.migSeen = d.migSeen or {}
    d.migSeen[cause] = (d.migSeen[cause] or 0) + 1
    d.migKnown = d.migKnown or {}
    if d.migSeen[cause] >= MIG_LEARN and isStrong(d, cause) and not d.migKnown[cause] then
        d.migKnown[cause] = true
        notify(player, "UI_DanTraits_MigraineTrigger_" .. cause)
    end
end

local function endAttack(player, d)
    updateBlur(player, d, false)
    d.migActive = false
    d.migHoursLeft = 0
    d.migSinceEnd = 0
    updateMoodle(player, 0)
    DanTraits_NotifyGood(player, "UI_DanTraits_MigraineEnd")
    learnCause(player, d)
end

local function triptanIn(player)
    return DanTraits_MedCovered and DanTraits_MedCovered(player, "sumatriptan") or false
end

-- the ten-minute roll
local function updateMigraineTen(player, d)
    if not hasTrait(player, "migraine") then return end
    d = migData(player)
    rollTriggers(d)
    if d.migActive or d.migAuraLeft then return end
    if d.migSinceEnd < MIG_REFRACTORY_H then
        d.migSinceEnd = d.migSinceEnd + 10 / 60
        return
    end
    local chance, cause = migraineChance(player)
    d.migChance = chance
    if ZombRand(10000) < chance * 100 then startAura(player, d, cause) end
end

local function updateMigraineMinute(player, d)
    if d then d.migGlare = nil end
    if not hasTrait(player, "migraine") then
        if d and d.migBlur ~= nil then updateBlur(player, d, false) end   -- the trait went mid-attack
        return
    end
    d = migData(player)
    if d.migAuraLeft then
        -- sumatriptan taken in the aura: the attack to come is half as bad
        if not d.migTripUsed and triptanIn(player) then
            d.migTripUsed = "aura"
            d.migSeverity = (d.migSeverity or MIG_SEV_MIN) * MIG_TRIP_AURA
            DanTraits_NotifyGood(player, "UI_DanTraits_MigraineTriptan")
        end
        d.migAuraLeft = d.migAuraLeft - 1 / 60
        updateMoodle(player, MIG_TIER[1])
        if d.migAuraLeft <= 1e-6 then startAttack(player, d) end
        return
    end
    if not d.migActive then
        if d.migBlur ~= nil then updateBlur(player, d, false) end
        return
    end

    local asleep, bright = false, inBrightLight(player)
    asleep = DanTraits_Asleep(player)
    local lit, dark = 0, 0
    if not asleep and not bright then lit, dark = roomLight(player) end
    local rate = 1
    if asleep then rate = MIG_SLEEP_RATE - (MIG_SLEEP_RATE - 1) * sleepLit(player)
    elseif bright then rate = MIG_LIGHT_RATE
    else rate = 1 - (1 - MIG_LIT_RATE) * lit + (MIG_DARK_RATE - 1) * dark end
    local meds = 0
    pcall(function() meds = player:getPainEffect() or 0 end)
    if meds > 0 and not d.migMedsUsed then
        d.migMedsUsed = true
        d.migHoursLeft = d.migHoursLeft * MIG_MEDS_CUT
    end
    -- sumatriptan in an attack: over within two hours
    if not d.migTripUsed and triptanIn(player) then
        d.migTripUsed = "attack"
        d.migHoursLeft = math.min(d.migHoursLeft, MIG_TRIP_HOURS)
        DanTraits_NotifyGood(player, "UI_DanTraits_MigraineTriptan")
    end
    d.migHoursLeft = d.migHoursLeft - rate / 60
    if d.migHoursLeft <= 0 then endAttack(player, d) return end

    updateBlur(player, d, true)
    local s = d.migSeverity or MIG_SEV_MIN
    -- an attack shows as Migraine at least, even halved by sumatriptan in the aura (level 1 is the Aura)
    updateMoodle(player, math.max(s, MIG_TIER[2]))
    if asleep then return end
    -- only a pill taken in the attack eases it; one taken in the aura already halved the severity
    local ease = d.migTripUsed == "attack" and MIG_TRIP_EASE or 1
    local glare = (bright and MIG_PAIN_LIGHT or MIG_PAIN_ROOM * lit) * (wearingShades(player) and MIG_SHADES_GLARE or 1)
    if glare > 0 then d.migGlare = clamp01(glare / MIG_PAIN_LIGHT) end
    pcall(function()
        local stats = player:getStats()
        DanTraits_PainFloor(player, d, "migraine", (MIG_PAIN * s + glare) * ease, MIG_RAMP)
        floorUp(stats, CharacterStat.FOOD_SICKNESS, MIG_SICK * s * ease, MIG_RAMP)
        floorUp(stats, CharacterStat.UNHAPPINESS, MIG_MOOD, MIG_RAMP)
        stats:set(CharacterStat.STRESS, math.min(1, (stats:get(CharacterStat.STRESS) or 0) + MIG_STRESS_RATE * s))
    end)
end

-- sumatriptan's day after, for anyone who takes it: heavy and a little clumsy
local function updateTriptanMinute(player, d)
    if not d or (d.tripAfterMin or 0) <= 0 then return end
    d.tripAfterMin = d.tripAfterMin - 1
    if d.tripAfterMin <= 0 then d.tripAfterMin = nil end
    if not DanTraits_Asleep(player) then DanTraits_StatAdd(player:getStats(), CharacterStat.FATIGUE, MIG_TRIP_FATIGUE) end
end

DanTraits_AddHook("gripSlip", function(chance, player)
    local d = player:getModData().DanTraits
    if not d or (d.tripAfterMin or 0) <= 0 then return nil end
    return chance + MIG_TRIP_SLIP
end)

-- painkillers during an attack: snapshot their timer before the pill, keep a share of what it added after
local painBefore = {}
DanTraits_AddHook("prePill", function(_, player, kind)
    if tostring(kind) ~= "Pills" then return nil end
    local d = player:getModData().DanTraits
    if not d or not d.migActive or not hasTrait(player, "migraine") then return nil end
    pcall(function() painBefore[player] = player:getPainEffect() or 0 end)
    return nil
end)

DanTraits_AddHook("pill", function(_, player, kind)
    kind = tostring(kind)
    if kind == "Sumatriptan" then
        local d = traitData(player)
        d.tripAfterMin = tonumber(DanTraits_RunHooks("tripAfterMinutes", MIG_TRIP_AFTER_H * 60, player)) or MIG_TRIP_AFTER_H * 60   -- Thick Skull
        notify(player, "UI_DanTraits_TriptanAfter")
        return nil
    end
    if kind ~= "Pills" then return nil end
    local before = painBefore[player]
    painBefore[player] = nil
    if not before then return nil end
    pcall(function()
        local after = player:getPainEffect() or 0
        if after > before then player:setPainEffect(before + (after - before) * MIG_PILL_KEEP) end
    end)
    return nil
end)

-- an attack makes the eyes sensitive: light wakes you more easily
DanTraits_AddHook("sleepWake", function(m, player, d)
    if not d or not d.migActive or not hasTrait(player, "migraine") then return nil end
    return m * MIG_SLEEP_WAKE
end)

-- a new character: their triggers drawn, and the end of a pack of sumatriptan
local function onMigraineCreatePlayer(playerNum, player)
    if not player or not hasTrait(player, "migraine") then return end
    local d = migData(player)
    if d.migKitGiven or player:getHoursSurvived() > 0 then return end
    d.migKitGiven = true
    rollTriggers(d)
    if not DanTraits_SandboxOn("StartingMedication") then return end
    pcall(function()
        local pack = player:getInventory():AddItem(MIG_TRIP_ITEM)
        if not pack then return end
        pack:getModData().DanTraitsFilled = true   -- not the random spawn fill
        pack:setUsedDelta(MIG_TRIP_START)
    end)
end

-- console: migraine | migraine start | migraine triggers
DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.migraine = function(player, args)
    local d = migData(player)
    rollTriggers(d)
    if args[1] == "start" then
        local _, cause = migraineChance(player)
        startAura(player, d, cause)
        return "aura started (cause " .. tostring(cause) .. ")"
    end
    if args[1] == "triggers" then
        local seen = {}
        for k, n in pairs(d.migSeen or {}) do seen[#seen + 1] = k .. " " .. tostring(n) end
        table.sort(seen)
        local known = {}
        for k in pairs(d.migKnown or {}) do known[#known + 1] = k end
        table.sort(known)
        return "strong: " .. table.concat(d.migStrong, ", ") .. " | seen: " .. table.concat(seen, ", ")
            .. " | known: " .. table.concat(known, ", ")
    end
    local chance, cause = migraineChance(player)
    return string.format("chance %.2f%% per ten minutes (most: %s)%s", chance, tostring(cause),
        d.migActive and string.format(", attack %.1f h left", d.migHoursLeft or 0) or "")
end

DanTraits_Every("minute", "Migraine", updateMigraineMinute, 40)
DanTraits_Every("minute", "Triptan", updateTriptanMinute, 40)
DanTraits_Every("ten", "Migraine", updateMigraineTen, 40)
Events.OnCreatePlayer.Add(onMigraineCreatePlayer)

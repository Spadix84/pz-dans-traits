-- Project Zomboid Vitality Project: Migraines.
-- Every ten minutes there is a small chance of an attack, pushed up by a
-- bad night (Vitality's sleep debt), thirst, stress, a hangover, nicotine
-- withdrawal, caffeine withdrawal, a wound infection's fever, bright
-- daylight outdoors and sleeping with the light on, and never within a day
-- of the last one. An aura gives
-- twenty minutes' warning. The attack lasts three to six hours by severity:
-- pain (a DanTraits_PainFloor floor: painkillers lower it by their strength and, taken once, shorten the attack), nausea,
-- low mood and stress. Daylight outdoors slows the recovery to half and
-- adds to the pain; sleeping it off is twice as fast, in the dark (a lit
-- room loses the benefit), and during an attack light wakes you twice as
-- easily.
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
local MIG_REFRACTORY_H  = 24      -- no roll for this long after an attack ends
local MIG_AURA_H        = 20 / 60 -- warning before the pain
local MIG_SEV_MIN       = 0.5     -- severity is this plus up to 0.5
local MIG_HOURS_BASE    = 3       -- attack length: this plus MIG_HOURS_SEV x severity
local MIG_HOURS_SEV     = 3
local MIG_PAIN          = 60      -- pain floor at severity 1 (see DanTraits_PainFloor)
local MIG_PAIN_LIGHT    = 15      -- extra floor in daylight outdoors
local MIG_SICK          = 30      -- food sickness floor at severity 1
local MIG_MOOD          = 15
local MIG_RAMP          = 1
local MIG_STRESS_RATE   = 0.0005  -- per minute
local MIG_MEDS_CUT      = 0.6     -- painkillers, first time in an attack: hours left x this
local MIG_LIGHT_RATE    = 0.5     -- recovery rate in daylight outdoors...
local MIG_SLEEP_RATE    = 2.0     -- ...and asleep in the dark (fully lit room: 1)
local MIG_SLEEP_LIGHT   = 1.0     -- percent per ten minutes added asleep in a fully lit room
local MIG_SLEEP_WAKE    = 2       -- during an attack, light wakes you this much more easily
local MIG_NIGHT         = 0.3     -- night strength under this is day
local MIG_CLOUD         = 0.5     -- cloud cover under this is bright
local MIG_TIER          = { 0.01, 0.5, 0.8 }   -- Aura | Migraine | Splitting

local function migData(player)
    local d = traitData(player)
    d.migSinceEnd = d.migSinceEnd or MIG_REFRACTORY_H
    return d
end

local clamp01 = DanTraits_Clamp01

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

-- percent chance per ten minutes
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

local function migraineChance(player)
    local chance = MIG_BASE + MIG_SLEEP_LIGHT * sleepLit(player)
    pcall(function()
        local stats = player:getStats()
        local debt = DanTraits_SleepDebt and DanTraits_SleepDebt(player) or 0
        chance = chance + MIG_SLEEP_DEBT * clamp01(debt)
        local thirst = stats:get(CharacterStat.THIRST) or 0
        if thirst > MIG_THIRST_FROM then chance = chance + MIG_THIRST * (thirst - MIG_THIRST_FROM) / (1 - MIG_THIRST_FROM) end
        chance = chance + MIG_STRESS * clamp01(stats:get(CharacterStat.STRESS) or 0)
        if DanTraits_HangoverStrength then chance = chance + MIG_HANGOVER * clamp01(DanTraits_HangoverStrength(player)) end
        if DanTraits_NicotineWithdrawal then chance = chance + MIG_NICOTINE * clamp01(DanTraits_NicotineWithdrawal(player)) end
        if DanTraits_ConcussionStrength then chance = chance + MIG_CONCUSSION * clamp01(DanTraits_ConcussionStrength(player)) end
        if DanTraits_CaffeineWithdrawalOf then chance = chance + MIG_CAFFEINE * clamp01(DanTraits_CaffeineWithdrawalOf(player)) end
        if DanTraits_InfectionFever then chance = chance + MIG_FEVER * clamp01(DanTraits_InfectionFever(player)) end
    end)
    if inBrightLight(player) then chance = chance + MIG_LIGHT end
    return chance
end
DanTraits_MigraineChance = migraineChance

local function updateMoodle(player, value)
    DanTraits_BadMoodle(player, "Migraine", value, MIG_TIER)
end

local floorUp = DanTraits_FloorUp

local function startAura(player, d)
    d.migAuraLeft = MIG_AURA_H
    d.migSeverity = MIG_SEV_MIN + ZombRand(0, 51) / 100
    notify(player, "UI_DanTraits_MigraineAura")
end

local function startAttack(player, d)
    d.migAuraLeft = nil
    d.migActive = true
    d.migHoursLeft = MIG_HOURS_BASE + MIG_HOURS_SEV * d.migSeverity
    d.migMedsUsed = false
    notify(player, "UI_DanTraits_MigraineStart")
end

local function endAttack(player, d)
    d.migActive = false
    d.migHoursLeft = 0
    d.migSinceEnd = 0
    updateMoodle(player, 0)
    DanTraits_NotifyGood(player, "UI_DanTraits_MigraineEnd")
end

-- the ten-minute roll
local function updateMigraineTen(player, d)
    if not hasTrait(player, "migraine") then return end
    d = migData(player)
    if d.migActive or d.migAuraLeft then return end
    if d.migSinceEnd < MIG_REFRACTORY_H then
        d.migSinceEnd = d.migSinceEnd + 10 / 60
        return
    end
    local chance = migraineChance(player)
    d.migChance = chance
    if ZombRand(10000) < chance * 100 then startAura(player, d) end
end
DanTraits_updateMigraineTen = updateMigraineTen

local function updateMigraineMinute(player, d)
    if not hasTrait(player, "migraine") then return end
    d = migData(player)
    if d.migAuraLeft then
        d.migAuraLeft = d.migAuraLeft - 1 / 60
        updateMoodle(player, MIG_TIER[1])
        if d.migAuraLeft <= 1e-6 then startAttack(player, d) end
        return
    end
    if not d.migActive then return end

    local asleep, bright = false, inBrightLight(player)
    asleep = DanTraits_Asleep(player)
    local rate = 1
    if asleep then rate = MIG_SLEEP_RATE - (MIG_SLEEP_RATE - 1) * sleepLit(player) elseif bright then rate = MIG_LIGHT_RATE end
    local meds = 0
    pcall(function() meds = player:getPainEffect() or 0 end)
    if meds > 0 and not d.migMedsUsed then
        d.migMedsUsed = true
        d.migHoursLeft = d.migHoursLeft * MIG_MEDS_CUT
    end
    d.migHoursLeft = d.migHoursLeft - rate / 60
    if d.migHoursLeft <= 0 then endAttack(player, d) return end

    local s = d.migSeverity or MIG_SEV_MIN
    updateMoodle(player, s)
    if asleep then return end
    pcall(function()
        local stats = player:getStats()
        DanTraits_PainFloor(player, d, "migraine", MIG_PAIN * s + (bright and MIG_PAIN_LIGHT or 0), MIG_RAMP)
        floorUp(stats, CharacterStat.FOOD_SICKNESS, MIG_SICK * s, MIG_RAMP)
        floorUp(stats, CharacterStat.UNHAPPINESS, MIG_MOOD, MIG_RAMP)
        stats:set(CharacterStat.STRESS, math.min(1, (stats:get(CharacterStat.STRESS) or 0) + MIG_STRESS_RATE * s))
    end)
end
DanTraits_updateMigraineMinute = updateMigraineMinute

-- an attack makes the eyes sensitive: light wakes you more easily
DanTraits_AddHook("sleepWake", function(m, player, d)
    if not d or not d.migActive or not hasTrait(player, "migraine") then return nil end
    return m * MIG_SLEEP_WAKE
end)

DanTraits_Every("minute", "Migraine", updateMigraineMinute, 40)
DanTraits_Every("ten", "Migraine", updateMigraineTen, 40)

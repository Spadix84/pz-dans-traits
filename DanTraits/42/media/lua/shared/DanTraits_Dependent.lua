-- Project Zomboid Vitality Project: Dependent.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local fraction = DanTraits_StatFraction

-- Dependent -----------------------------------------------------------------
-- Stress climbs once the character has been sober for a day; past two days it
-- starts hurting. A drink resets the clock, but tolerance decides how much of
-- a drink: every drunk hour raises it, every dry day lowers it, and with it
-- the intoxication needed to feel sated goes up, withdrawal comes sooner and
-- bites harder, and hangovers ease a little.
local DRY_HOURS_STRESS  = 24    -- hours sober before withdrawal starts (at no tolerance)
local DRY_HOURS_PAIN    = 48    -- hours sober before it turns painful
local DEP_SATED_MIN     = 0.05  -- intoxication (0..1) that counts as a drink with no tolerance...
local DEP_SATED_TOL     = 0.40  -- ...plus this much at full tolerance
local DEP_BUZZ          = 0.20  -- intoxication above this builds tolerance
local DEP_TOL_BUILD_H   = 48    -- drunk hours from no tolerance to full
local DEP_TOL_DECAY_H   = 168   -- dry hours from full tolerance to none
local DEP_TOL_ONSET_CUT = 0.5   -- withdrawal starts this much sooner at full tolerance
local DEP_STRESS_RATE   = 0.01  -- per ten minutes, x (1 + tolerance)
local DEP_PAIN_RATE     = 0.5

-- 0..1, read by the hangover system
function DanTraits_AlcoholTolerance(player)
    if not player or not hasTrait(player, "dependent") then return 0 end
    local d = player:getModData().DanTraits
    return d and d.depTolerance or 0
end

local function updateDependent(player, d)
    if not hasTrait(player, "dependent") then return end

    local stats = player:getStats()
    local intox = fraction(stats, CharacterStat.INTOXICATION)
    local tol = d.depTolerance or 0
    if intox > DEP_BUZZ then
        tol = math.min(1, tol + (intox - DEP_BUZZ) / (1 - DEP_BUZZ) * (10 / 60) / DEP_TOL_BUILD_H)
    elseif intox < DEP_SATED_MIN then
        tol = math.max(0, tol - (10 / 60) / DEP_TOL_DECAY_H)
    end
    d.depTolerance = tol

    if intox > DEP_SATED_MIN + DEP_SATED_TOL * tol then
        d.dryHours = 0
        if d.withdrawing then
            d.withdrawing = false
            notify(player, "UI_DanTraits_DependentSated")
        end
        return
    end

    d.dryHours = (d.dryHours or 0) + (10 / 60)
    local onset = 1 - DEP_TOL_ONSET_CUT * tol
    if d.dryHours < DRY_HOURS_STRESS * onset then return end

    if not d.withdrawing then
        d.withdrawing = true
        notify(player, "UI_DanTraits_DependentCraving")
    end

    -- STRESS is 0..1, PAIN is 0..100.
    stats:set(CharacterStat.STRESS, math.min(1.0, stats:get(CharacterStat.STRESS) + DEP_STRESS_RATE * (1 + tol)))

    if d.dryHours >= DRY_HOURS_PAIN * onset then
        stats:set(CharacterStat.PAIN, math.min(100, stats:get(CharacterStat.PAIN) + DEP_PAIN_RATE * (1 + tol)))
    end
end
DanTraits_updateDependent = updateDependent

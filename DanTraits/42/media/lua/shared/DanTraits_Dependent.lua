-- Project Zomboid Vitality Project: Dependent.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify

-- Dependent -----------------------------------------------------------------
-- Stress climbs once the character has been sober for a day; past two days it
-- starts hurting. Any intoxication at all resets the clock.
local DRY_HOURS_STRESS  = 24    -- hours sober before withdrawal starts
local DRY_HOURS_PAIN    = 48    -- hours sober before it turns painful

local function updateDependent(player, d)
    if not hasTrait(player, "dependent") then return end

    local stats = player:getStats()
    if stats:get(CharacterStat.INTOXICATION) > 0.05 then
        d.dryHours = 0
        if d.withdrawing then
            d.withdrawing = false
            notify(player, "UI_DanTraits_DependentSated")
        end
        return
    end

    d.dryHours = (d.dryHours or 0) + (10 / 60)
    if d.dryHours < DRY_HOURS_STRESS then return end

    if not d.withdrawing then
        d.withdrawing = true
        notify(player, "UI_DanTraits_DependentCraving")
    end

    -- STRESS is 0..1, PAIN is 0..100.
    stats:set(CharacterStat.STRESS, math.min(1.0, stats:get(CharacterStat.STRESS) + 0.01))

    if d.dryHours >= DRY_HOURS_PAIN then
        stats:set(CharacterStat.PAIN, math.min(100, stats:get(CharacterStat.PAIN) + 0.5))
    end
end
DanTraits_updateDependent = updateDependent

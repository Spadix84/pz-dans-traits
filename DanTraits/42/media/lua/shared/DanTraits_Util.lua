-- Project Zomboid Vitality Project: small shared helpers.
--
-- The one-liners every trait file used to carry its own copy of: clamping,
-- floor-raising and adding on a stat, dice, body-part lookups, the asleep
-- check, the sandbox toggle and the Moodle Framework updater. It requires
-- nothing and is loaded by DanTraits.lua right after DanTraits_Attrib, so any
-- file that requires "DanTraits" can read these into locals at the top
-- (`local clamp01 = DanTraits_Clamp01`). Core sits near the 200-local limit
-- and this file keeps well under the 60-upvalue one: everything is a global
-- prefixed DanTraits_, and nothing here touches a game object outside pcall.
--
--   DanTraits_Clamp01(x)                   x limited to 0..1
--   DanTraits_StatMax(stat)                the stat's maximum (1 when unknown)
--   DanTraits_FloorUp(stats, stat, floor, ramp)
--                                          raise the stat toward floor by at
--                                          most ramp; never above floor or the
--                                          stat's maximum
--   DanTraits_StatAdd(stats, stat, amount) add, clamped to 0..maximum (in pcall)
--   DanTraits_Roll(chance01)               true with that chance (0 never, 1 always)
--   DanTraits_RollPercent(pct)             the same on a 0..100 scale, in
--                                          millionths so 0.05 works; goes
--                                          through ZombRand (the queue tests use)
--   DanTraits_RandRange(lo, hi)            a random number in lo..hi
--   DanTraits_PartNames                    short console names -> BodyPartType names
--   DanTraits_PartOf(player, shortName)    the BodyPart for a short name, or nil
--   DanTraits_PartNum(part, method)        a numeric BodyPart getter, 0 on failure
--   DanTraits_PartIs(part, method)         a boolean BodyPart getter, false on failure
--   DanTraits_Asleep(player)               whether the player is asleep, false on failure
--   DanTraits_SandboxOn(optionName)        SandboxVars.DanTraits[option] ~= false
--                                          (true when the table is absent)
--   DanTraits_BadMoodle(player, name, value01, tiers)
--                                          Moodle Framework updater for a
--                                          bad-side-only moodle (0.5 is none,
--                                          lower is worse): value 0.5 * (1 - value01)
--                                          and thresholds 0.5 * (1 - t) for the 3 or
--                                          4 tier points given, ascending; or
--                                          { thresholds = { a, b, c, d } } to hand-set them

function DanTraits_Clamp01(x) return math.max(0, math.min(1, x)) end

function DanTraits_StatMax(stat)
    local max = 1
    pcall(function() max = stat:getMaximumValue() or 1 end)
    if not max or max <= 0 then max = 1 end
    return max
end

function DanTraits_FloorUp(stats, stat, floor, ramp)
    local value = stats:get(stat) or 0
    floor = math.min(floor, DanTraits_StatMax(stat))
    if value < floor then stats:set(stat, math.min(floor, value + ramp)) end
end

function DanTraits_StatAdd(stats, stat, amount)
    if not stat then return end
    pcall(function()
        stats:set(stat, math.max(0, math.min(DanTraits_StatMax(stat), (stats:get(stat) or 0) + amount)))
    end)
end

function DanTraits_Roll(chance)
    if chance <= 0 then return false end
    if chance >= 1 then return true end
    if ZombRandFloat then return ZombRandFloat(0, 1) < chance end
    return math.random() < chance
end

function DanTraits_RollPercent(percent)
    if ZombRand then return ZombRand(1000000) < percent * 10000 end
    return math.random() * 100 < percent
end

function DanTraits_RandRange(lo, hi)
    if ZombRandFloat then return ZombRandFloat(lo, hi) end
    return lo + math.random() * (hi - lo)
end

DanTraits_PartNames = {
    hand_l = "Hand_L", hand_r = "Hand_R", forearm_l = "ForeArm_L", forearm_r = "ForeArm_R",
    upperarm_l = "UpperArm_L", upperarm_r = "UpperArm_R", thigh_l = "UpperLeg_L", thigh_r = "UpperLeg_R",
    shin_l = "LowerLeg_L", shin_r = "LowerLeg_R", foot_l = "Foot_L", foot_r = "Foot_R",
    chest = "Torso_Upper", belly = "Torso_Lower", groin = "Groin", head = "Head", neck = "Neck",
}

function DanTraits_PartOf(player, shortName)
    local typeName = DanTraits_PartNames[string.lower(tostring(shortName or ""))]
    if not typeName then return nil end
    local part = nil
    pcall(function() part = player:getBodyDamage():getBodyPart(BodyPartType[typeName]) end)
    return part
end

function DanTraits_PartNum(part, method)
    local v = 0
    pcall(function() v = part[method](part) or 0 end)
    return tonumber(v) or 0
end

function DanTraits_PartIs(part, method)
    local ok, res = pcall(function() return part[method](part) end)
    return ok and res == true
end

function DanTraits_Asleep(player)
    local asleep = false
    pcall(function() asleep = player:isAsleep() end)
    return asleep
end

function DanTraits_SandboxOn(optionName)
    local sv = SandboxVars and SandboxVars.DanTraits
    return not sv or sv[optionName] ~= false
end

-- Moodle Framework is client side and optional; without it the trait still
-- works, you just do not get the icon.
function DanTraits_BadMoodle(player, name, value01, tiers)
    if not MF or not MF.getMoodle then return end
    pcall(function()
        local moodle = MF.getMoodle(name, player:getPlayerNum())
        if not moodle then return end
        local th = tiers.thresholds
        if th then
            moodle:setThresholds(th[1], th[2], th[3], th[4])
        elseif #tiers >= 4 then
            moodle:setThresholds(0.5 * (1 - tiers[4]), 0.5 * (1 - tiers[3]), 0.5 * (1 - tiers[2]), 0.5 * (1 - tiers[1]))
        else
            moodle:setThresholds(nil, 0.5 * (1 - tiers[3]), 0.5 * (1 - tiers[2]), 0.5 * (1 - tiers[1]))
        end
        moodle:setValue(0.5 * (1 - value01))
    end)
end

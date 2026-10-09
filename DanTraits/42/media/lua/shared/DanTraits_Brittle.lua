-- Project Zomboid Vitality Project: Brittle.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify

-- Brittle -------------------------------------------------------------------
-- A solid hit (a weapon, a zombie: 2 damage or more) rolls FRACTURE_CHANCE.
-- Falls, car crashes and being hit by a car are judged on Concussion's
-- "impact" hook instead, by the same scale as the head: the chance of a
-- concussion times IMPACT_SCALE times FRACTURE_CHANCE. A bump at 11 km/h
-- (the game reports it as 2-3 damage) or a hop off a fence is nothing; a
-- fence at 50 km/h about a fifth; a crash sure to concuss, two fifths.
local FRACTURE_CHANCE = 20    -- percent, on a solid hit
local IMPACT_SCALE    = 2     -- a crash certain to concuss rolls this many times FRACTURE_CHANCE
local IMPACT_TYPES    = { FALLDOWN = true, CARCRASHDAMAGE = true, CARHITDAMAGE = true }
local BRITTLE_PARTS = {
    BodyPartType.ForeArm_L, BodyPartType.ForeArm_R,
    BodyPartType.LowerLeg_L, BodyPartType.LowerLeg_R,
    BodyPartType.Hand_L, BodyPartType.Hand_R,
}

-- fracture a random intact limb; returns true if one snapped
local function fracture(player)
    local part = nil
    pcall(function() part = player:getBodyDamage():getBodyPart(BRITTLE_PARTS[ZombRand(#BRITTLE_PARTS) + 1]) end)
    if not part then return false end

    local intact = true
    pcall(function() intact = part:getFractureTime() <= 0 end)
    if not intact then return false end

    pcall(function() part:setFractureTime(40 + ZombRand(40)) end)
    notify(player, "UI_DanTraits_BrittleSnap")
    return true
end
DanTraits_BrittleFracture = fracture

local function onPlayerGetDamage(player, damageType, damage)
    if not player or player ~= getSpecificPlayer(0) then return end   -- the local player only (zombies come through here too)
    if IMPACT_TYPES[damageType] then return end   -- judged on the impact hook below
    if not hasTrait(player, "brittle") then return end
    if not damage or damage < 2 then return end
    if ZombRand(100) >= DanTraits_RunHooks("brittleChance", FRACTURE_CHANCE, player) then return end   -- Age: likelier in the 40s
    fracture(player)
end

-- a fall or crash, with the chance Concussion gives it (0 under its scale's floor)
DanTraits_AddHook("impact", function(_, player, chance)
    if not player or player ~= getSpecificPlayer(0) then return nil end
    if not hasTrait(player, "brittle") or not chance or chance <= 0 then return nil end
    local pct = DanTraits_RunHooks("brittleChance", FRACTURE_CHANCE, player) * IMPACT_SCALE * chance
    if ZombRand(100) >= pct then return nil end
    fracture(player)
    return nil
end)

Events.OnPlayerGetDamage.Add(onPlayerGetDamage)

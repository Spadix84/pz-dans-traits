-- Project Zomboid Vitality Project: Brittle.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify

-- Brittle -------------------------------------------------------------------
local FRACTURE_CHANCE = 20    -- percent, on a solid hit
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
    if not hasTrait(player, "brittle") then return end
    if not damage or damage < 2 then return end
    if ZombRand(100) >= DanTraits_RunHooks("brittleChance", FRACTURE_CHANCE, player) then return end   -- Age: likelier in the 40s
    fracture(player)
end

Events.OnPlayerGetDamage.Add(onPlayerGetDamage)

-- Project Zomboid Vitality Project: Brittle.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local clamp01 = DanTraits_Clamp01

-- Brittle -------------------------------------------------------------------
-- A solid hit (a weapon, a zombie: 2 damage or more) rolls FRACTURE_CHANCE.
-- Only what the game reports as a hit (OnPlayerGetDamage "WEAPONHIT", from
-- IsoGameCharacter.Hit) counts: the same event carries fire, a wound
-- infection, hunger and thirst taking health off, and none of those snaps
-- a bone. Falls, car crashes and being hit by a car are judged on
-- Concussion's "impact" hook instead, by the same scale as the head: the
-- chance of a concussion times IMPACT_SCALE times FRACTURE_CHANCE. A bump
-- at 11 km/h (the game reports it as 2-3 damage) or a hop off a fence is
-- nothing; a fence at 50 km/h about a fifth; a crash sure to concuss, two
-- fifths.
--
-- The bones themselves (brBone, 0..1, BONE_START to begin with) set the
-- chance: FRACTURE_CHANCE x (BONE_WEAK - score), so a fifth at the start,
-- a tenth with bones as strong as they get, three tenths at the bottom. The
-- score drifts down BONE_DRIFT_DAY a day and is fed by calcium (dairy,
-- greens, eggs: BONE_DAIRY, BONE_GREENS, BONE_EGG a full portion, at most
-- BONE_FOOD_DAY a day) and by weight-bearing exercise (Vitality's exercise
-- score at BONE_EXERCISE_FROM or better puts BONE_EXERCISE_DAY back a day,
-- which holds the drift). Brittle with Lactose Intolerance pays for its
-- calcium in cramps. Mod data: brBone, brBoneDay (today's calcium), brDay.
-- Console: brittle bone [0..1].
local FRACTURE_CHANCE = 20    -- percent, on a solid hit, with bones as they start
local IMPACT_SCALE    = 2     -- a crash certain to concuss rolls this many times FRACTURE_CHANCE
local BONE_START      = 0.5
local BONE_WEAK       = 1.5   -- chance x (this - score)
local BONE_DRIFT_DAY  = 0.02
local BONE_DAIRY      = 0.04
local BONE_GREENS     = 0.02
local BONE_EGG        = 0.01
local BONE_FOOD_DAY   = 0.06
local BONE_EXERCISE_FROM = 0.5
local BONE_EXERCISE_DAY  = 0.02
local BONE_LEGS_MIN      = 20      -- minutes today on the legs (squats, burpees, a jog, a carry; DanTraits_Fitness.lua)...
local BONE_LEGS_DAY      = 0.02    -- ...put this much more back a day: bone grows where it is loaded
local HIT_TYPE        = "WEAPONHIT"   -- the one damage report that is a hit
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

-- the chance this body's bones give a solid hit, in percent
local function fractureChance(player)
    local d = player and player:getModData().DanTraits
    local bone = d and d.brBone or BONE_START
    return FRACTURE_CHANCE * (BONE_WEAK - clamp01(bone))
end
DanTraits_BrittleChance = fractureChance

-- a solid hit; also how another mod's NPC hit arrives (DanTraits_OtherHit)
function DanTraits_BrittleHit(player, damage)
    if not player or player ~= getSpecificPlayer(0) then return end   -- the local player only (zombies come through here too)
    if not hasTrait(player, "brittle") then return end
    if not damage or damage < 2 then return end
    if ZombRand(100) >= DanTraits_RunHooks("brittleChance", fractureChance(player), player) then return end   -- Age: likelier in the 40s
    fracture(player)
end

local function onPlayerGetDamage(player, damageType, damage)
    -- a fall or a crash is judged on the impact hook below; fire, infection, hunger and thirst are not hits
    if damageType ~= HIT_TYPE then return end
    DanTraits_BrittleHit(player, damage)
end

-- a fall or crash, with the chance Concussion gives it (0 under its scale's floor)
DanTraits_AddHook("impact", function(_, player, chance)
    if not player or player ~= getSpecificPlayer(0) then return nil end
    if not hasTrait(player, "brittle") or not chance or chance <= 0 then return nil end
    local pct = DanTraits_RunHooks("brittleChance", fractureChance(player), player) * IMPACT_SCALE * chance
    if ZombRand(100) >= pct then return nil end
    fracture(player)
    return nil
end)

-- the bones: a slow drift down, held by exercise; calcium puts some back
local function worldDay()
    local hours = 0
    pcall(function() hours = getGameTime():getWorldAgeHours() or 0 end)
    return math.floor(hours / 24)
end

local function updateBoneMinute(player, d)
    d.brBone = d.brBone or BONE_START
    local day = worldDay()
    if d.brDay ~= day then d.brDay, d.brBoneDay = day, 0 end
    local drift = -BONE_DRIFT_DAY / 1440
    if (d.vitExercise or 0) >= BONE_EXERCISE_FROM then drift = drift + BONE_EXERCISE_DAY / 1440 end   -- Vitality's exercise score
    if DanTraits_FitLegMinutes and DanTraits_FitLegMinutes(player) >= BONE_LEGS_MIN then drift = drift + BONE_LEGS_DAY / 1440 end
    d.brBone = clamp01(d.brBone + drift)
end

DanTraits_AddHook("eat", function(_, player, item, fraction)
    if not player or not item or not hasTrait(player, "brittle") then return nil end
    local tags = DanTraits_FoodTags(item)
    local gain = 0
    if tags.dairy then gain = BONE_DAIRY elseif tags.greens then gain = BONE_GREENS elseif tags.egg then gain = BONE_EGG end
    gain = gain * clamp01(fraction or 1)
    if gain <= 0 then return nil end
    local d = DanTraits_Data(player)
    d.brBone = d.brBone or BONE_START
    gain = math.min(gain, math.max(0, BONE_FOOD_DAY - (d.brBoneDay or 0)))   -- only so much calcium a day counts
    d.brBoneDay = (d.brBoneDay or 0) + gain
    d.brBone = clamp01(d.brBone + gain)
    return nil
end)

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.brittle = function(player, args)
    local d = DanTraits_Data(player)
    if args[1] == "bone" and tonumber(args[2]) then d.brBone = clamp01(tonumber(args[2])) end
    return "brittle: bone " .. string.format("%.3f", d.brBone or BONE_START) .. ", today's calcium " .. tostring(d.brBoneDay or 0)
        .. ", fracture chance " .. string.format("%.1f", fractureChance(player)) .. "% (brittle bone [0..1])"
end

Events.OnPlayerGetDamage.Add(onPlayerGetDamage)
DanTraits_Every("minute", "Brittle", updateBoneMinute, 40, { trait = "brittle" })

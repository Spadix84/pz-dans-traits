-- Project Zomboid Vitality Project: Wounded.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local traitData = DanTraits_Data

-- Wounded -------------------------------------------------------------------
-- A start you nurse your way out of, for points: a fractured left upper arm
-- and four fresh wounds, one deep, on random body parts, with a single
-- bandage in the pocket. A Really Bad Day's sibling (DanTraits_BadDay.lua):
-- applied exactly once at creation, tracked in mod data so reloads and
-- respawns are safe, replayed from the console with `wounded`.
--
-- What it costs under the health overhaul: the fracture (WD_FRACTURE time,
-- the top of Brittle's range) hurts for a fortnight even splinted, and a
-- splint is the first thing to make (plank or branch, ripped sheet). It is
-- the LEFT arm on purpose: a one-handed weapon in the right still works.
-- The deep wound bleeds at the blood system's rate until it is bandaged or
-- stitched; the laceration and the two scratches bleed less but the
-- laceration can land anywhere, the neck included (x3 the bleed), which is
-- what the one bandage is for. Every open wound takes the hourly infection
-- roll (DanTraits_Infection.lua), so disinfectant is the second thing to
-- find. Hemophilia and Wounded are mutually exclusive (scripts/DanTraits.txt);
-- it stacks with A Really Bad Day (its cut is on the left forearm, the
-- fracture here is the upper arm).
local WD_FRACTURE_PART = "UpperArm_L"
local WD_FRACTURE_MIN, WD_FRACTURE_SPAN = 70, 15   -- fracture time 70..84 (Brittle: 40..79, breakbone's default 50)
local WD_BANDAGES = 1
local WD_NOTICE = "UI_DanTraits_WoundedWake"

-- the deep wound goes on a limb (a plain x1.0 bleed site, DanTraits_Blood.lua),
-- never the neck, head, groin, thighs or torso; the laceration and the
-- scratches can go anywhere. Never the fractured arm: four separate hurts.
local WD_DEEP_PARTS = { "ForeArm_L", "ForeArm_R", "UpperArm_R", "LowerLeg_L", "LowerLeg_R" }
local WD_ANY_PARTS = { "Hand_L", "Hand_R", "ForeArm_L", "ForeArm_R", "UpperArm_R",
    "Torso_Upper", "Torso_Lower", "Head", "Neck", "Groin",
    "UpperLeg_L", "UpperLeg_R", "LowerLeg_L", "LowerLeg_R", "Foot_L", "Foot_R" }
-- the four wounds, in the order they are placed
local WD_KINDS = { "deep", "cut", "scratch", "scratch" }

local function woundedFresh(player)
    if not player or not hasTrait(player, "wounded") then return nil end
    if player:getHoursSurvived() > 0 then return nil end
    return traitData(player)
end

local function partOf(player, name)
    local part = nil
    pcall(function() part = player:getBodyDamage():getBodyPart(BodyPartType[name]) end)
    return part
end

-- a random part from `pool` that is not in `taken`; nil when the pool is used up
local function pickPart(pool, taken)
    local free = {}
    for _, name in ipairs(pool) do if not taken[name] then free[#free + 1] = name end end
    if #free == 0 then return nil end
    return free[ZombRand(#free) + 1]
end

-- the second argument is the game's "infect" flag: setCut(b) alone is
-- setCut(b, true), a 25% Knox roll (BodyPart.generateZombieInfection), and
-- setScratched(b, true) a 7% one. These wounds are a knife's, not a bite's.
local function inflict(part, kind)
    if kind == "deep" then
        pcall(function() part:generateDeepWound() end)
    elseif kind == "cut" then
        pcall(function() part:setCut(true, false) end)
    else
        pcall(function() part:setScratched(true, false) end)
    end
end

-- the body of the opening: the fracture, the four wounds, the bandage;
-- returns the wounds placed, { { part = name, kind = kind }, ... }
local function applyWounded(player)
    local arm = partOf(player, WD_FRACTURE_PART)
    if arm then
        pcall(function() arm:setFractureTime(WD_FRACTURE_MIN + ZombRand(WD_FRACTURE_SPAN)) end)
    end

    local taken, placed = { [WD_FRACTURE_PART] = true }, {}
    for _, kind in ipairs(WD_KINDS) do
        local name = pickPart(kind == "deep" and WD_DEEP_PARTS or WD_ANY_PARTS, taken)
        local part = name and partOf(player, name)
        if part then
            taken[name] = true
            inflict(part, kind)
            placed[#placed + 1] = { part = name, kind = kind }
        end
    end

    pcall(function()
        local inv = player:getInventory()
        for _ = 1, WD_BANDAGES do inv:AddItem("Base.Bandage") end
    end)
    notify(player, WD_NOTICE)
    return placed
end

local function onWoundedCreatePlayer(playerNum, player)
    local d = woundedFresh(player)
    if not d or d.wdApplied then return end
    d.wdApplied = true
    d.wdWounds = applyWounded(player)
end

local function describe(placed)
    local parts = {}
    for _, w in ipairs(placed) do parts[#parts + 1] = w.kind .. " " .. w.part end
    return #parts > 0 and table.concat(parts, ", ") or "no wounds (no body parts)"
end

-- Console `wounded` (Telemetry, via DanTraits_ExtraCommands): replay the
-- opening on the current character, for balancing it without a new game.
-- Skips the first-hour gate and the trait check, and does not undo what is
-- already there (another fracture time, more wounds). Returns a line for the log.
function DanTraits_WoundedReplay(player)
    if not player then return "wounded: no player" end
    local d = traitData(player)
    d.wdApplied = true
    d.wdWounds = applyWounded(player)
    return "wounded: opening replayed: fractured " .. WD_FRACTURE_PART .. ", " .. describe(d.wdWounds)
end

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.wounded = function(player) return DanTraits_WoundedReplay(player) end

Events.OnCreatePlayer.Add(onWoundedCreatePlayer)

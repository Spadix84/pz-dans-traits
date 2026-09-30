-- Project Zomboid Vitality Project: Germaphobe.
--
-- Dirt gets under your skin. How grimy you are (0..1) is the larger of the
-- blood and dirt on your body (the game's own per-part visual, averaged) and
-- the share of your body under dirty clothes (each part's hasDirtyClothing).
-- Past a little grime, stress builds and your mood is held down, both scaling
-- with it; wash up and change, and the relief is real: stress and misery
-- drop the moment you are clean again. The upside of all that scrubbing: a
-- wound is a fifth less likely to take an infection (the infectionHazard hook
-- of DanTraits_Infection.lua).
--
-- Mod data: gmGrime (0..1, last minute's), gmFilthy (the notice was given).
-- Console: germ <grime 0..1>  (holds the reading for a game hour)
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local clamp01 = DanTraits_Clamp01

local GM_FROM          = 0.15    -- grime under this is fine
local GM_CLEAN         = 0.05    -- under this after being filthy: relief
local GM_STRESS_MIN    = 0.0006  -- stress a minute at full grime (0..1 scale)
local GM_UNHAPPY       = 35      -- unhappiness floor at full grime
local GM_UNHAPPY_RAMP  = 1
local GM_RELIEF_STRESS = 0.1
local GM_RELIEF_SAD    = 10
local GM_HAZARD        = 0.8     -- wound infection hazard x this

-- 0..1 blood and dirt on the body, averaged over the parts the visual keeps
local function bodyGrime(player)
    local total, n = 0, 0
    pcall(function()
        local visual = player:getHumanVisual()
        local count = BloodBodyPartType.MAX:index()
        for i = 0, count - 1 do
            local part = BloodBodyPartType.FromIndex(i)
            total = total + math.min(1, (visual:getBlood(part) or 0) + (visual:getDirt(part) or 0))
            n = n + 1
        end
    end)
    if n == 0 then return 0 end
    return total / n
end

-- 0..1 share of the body parts under dirty clothes
local function clothesGrime(player)
    local dirty, n = 0, 0
    pcall(function()
        local parts = player:getBodyDamage():getBodyParts()
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            n = n + 1
            if DanTraits_PartIs(part, "hasDirtyClothing") then dirty = dirty + 1 end
        end
    end)
    if n == 0 then return 0 end
    return dirty / n
end

local function grimeOf(player, d)
    if d.gmHold and (d.gmHoldMin or 0) > 0 then return d.gmHold end
    return clamp01(math.max(bodyGrime(player), clothesGrime(player)))
end
DanTraits_GermGrime = grimeOf

local function updateGermMinute(player, d)
    if (d.gmHoldMin or 0) > 0 then d.gmHoldMin = d.gmHoldMin - 1 end
    if not hasTrait(player, "germaphobe") then return end
    local grime = grimeOf(player, d)
    d.gmGrime = grime
    local stats = player:getStats()
    if grime >= GM_FROM then
        if not d.gmFilthy then
            d.gmFilthy = true
            notify(player, "UI_DanTraits_GermFilthy")
        end
        DanTraits_StatAdd(stats, CharacterStat.STRESS, GM_STRESS_MIN * grime)
        pcall(function() DanTraits_FloorUp(stats, CharacterStat.UNHAPPINESS, GM_UNHAPPY * grime, GM_UNHAPPY_RAMP) end)
    elseif d.gmFilthy and grime < GM_CLEAN then
        d.gmFilthy = nil
        DanTraits_StatAdd(stats, CharacterStat.STRESS, -GM_RELIEF_STRESS)
        DanTraits_StatAdd(stats, CharacterStat.UNHAPPINESS, -GM_RELIEF_SAD)
        DanTraits_NotifyGood(player, "UI_DanTraits_GermClean")
    end
end
DanTraits_updateGermMinute = updateGermMinute

DanTraits_AddHook("infectionHazard", function(h, player)
    if not hasTrait(player, "germaphobe") then return nil end
    return h * GM_HAZARD
end)

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.germ = function(player, args)
    local d = DanTraits_Data(player)
    local g = tonumber(args[1])
    if not g then return "germ <grime 0..1> (now " .. tostring(grimeOf(player, d)) .. ")" end
    d.gmHold, d.gmHoldMin = clamp01(g), 60
    return "grime held at " .. tostring(d.gmHold) .. " for an hour"
end

DanTraits_Every("minute", "Germaphobe", updateGermMinute, 40)

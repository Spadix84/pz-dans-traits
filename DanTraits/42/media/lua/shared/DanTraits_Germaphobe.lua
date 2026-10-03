-- Project Zomboid Vitality Project: Germaphobe.
--
-- Dirt gets under your skin. How grimy you are (0..1) is the larger of the
-- blood and dirt on your body (the game's own per-part visual: the mean of
-- the four worst parts, so bloody hands and a spattered chest count in full
-- however clean the rest of you is) and the share of your body under dirty
-- clothes (each part's hasDirtyClothing, half as much again: a filthy shirt
-- and trousers are most of the way there).
-- Past a little grime, stress builds and your mood is held down, both scaling
-- with it; wash up and change, and the relief is real: stress and misery
-- drop the moment you are clean again. The upside of all that scrubbing: a
-- wound is a fifth less likely to take an infection (the infectionHazard hook
-- of DanTraits_Infection.lua).
--
-- Mod data: gmGrime (0..1, last minute's), gmFilthy (the notice was given),
-- gmHold and gmHoldMin (the console's held reading and how long it has left).
-- Console: germ <grime 0..1>  (holds the reading for a game hour)
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local clamp01 = DanTraits_Clamp01

local GM_FROM          = 0.15    -- grime under this is fine
local GM_CLEAN         = 0.05    -- under this after being filthy: relief
local GM_WORST         = 4       -- body grime is the mean of this many of the worst parts
local GM_CLOTHES       = 1.5     -- share of the body under dirty clothes x this
local GM_STRESS_MIN    = 0.002   -- stress a minute at full grime (0..1 scale)
local GM_UNHAPPY       = 35      -- unhappiness floor at full grime
local GM_UNHAPPY_RAMP  = 1
local GM_RELIEF_STRESS = 0.1
local GM_RELIEF_SAD    = 10
local GM_HAZARD        = 0.8     -- wound infection hazard x this

-- the mean of the largest GM_WORST values in the list (missing ones count as 0)
local function worstMean(values)
    table.sort(values, function(a, b) return a > b end)
    local total = 0
    for i = 1, GM_WORST do total = total + (values[i] or 0) end
    return total / GM_WORST
end
DanTraits_GermWorstMean = worstMean

-- 0..1 blood and dirt on the body: the worst few of the parts the visual keeps
local function bodyGrime(player)
    local values = {}
    pcall(function()
        local visual = player:getHumanVisual()
        local count = BloodBodyPartType.MAX:index()
        for i = 0, count - 1 do
            local part = BloodBodyPartType.FromIndex(i)
            values[#values + 1] = math.min(1, (visual:getBlood(part) or 0) + (visual:getDirt(part) or 0))
        end
    end)
    if #values == 0 then return 0 end
    return worstMean(values)
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
    return math.min(1, dirty / n * GM_CLOTHES)
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

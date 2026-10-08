-- Project Zomboid Vitality Project: Resilient against the Knox virus.
-- Vanilla Resilient, re-costed from 4 to 10 (scripts/DanTraits.txt), keeps
-- its own effect and gains a chance (sandbox KnoxSurviveChance, default 25%)
-- that the body beats a zombie infection. The roll is made, hidden, the
-- first minute the body is seen infected. A lucky character gets sick like
-- anyone else; when the infection (CharacterStat.ZOMBIE_INFECTION) has run
-- KX_BREAK_AT of its way, the fever breaks: the infection and its fever are
-- cleared and a notice says so. Every new infection rolls again; one already
-- there when a save loads rolls then. Mod data: knox = { lucky, breakAt }.
-- Console `knox [infect|lucky|unlucky|jump <percent>]` (Telemetry).
require "DanTraits"

local hasVanillaTrait = DanTraits_HasVanillaTrait
local notifyGood = DanTraits_NotifyGood
local traitData = DanTraits_Data

local KX_CHANCE    = 25           -- percent, when the sandbox has no value
local KX_BREAK_AT  = { 40, 70 }   -- percent of the infection's way when a lucky one breaks

local function chance()
    return math.max(0, math.min(100, DanTraits_SandboxNum("KnoxSurviveChance", KX_CHANCE)))
end

local function infected(player)
    local on = false
    pcall(function() on = player:getBodyDamage():isInfected() == true end)
    return on
end

-- how far the infection has run, 0..1
local function progress(player)
    return DanTraits_StatFraction(player:getStats(), CharacterStat.ZOMBIE_INFECTION)
end

local function rollKnox()
    return { lucky = DanTraits_RollPercent(chance()), breakAt = DanTraits_RandRange(KX_BREAK_AT[1], KX_BREAK_AT[2]) / 100 }
end

-- the body wins: every part's infection, the body's, its clock and the fever
local function cure(player)
    DanTraits_EachPart(player, function(part)
        if part:IsInfected() then part:SetInfected(false) end
    end, "Knox")
    pcall(function()
        local bd = player:getBodyDamage()
        bd:setInfected(false)
        bd:setInfectionTime(-1)
        bd:setInfectionMortalityDuration(-1)
    end)
    pcall(function()
        local stats = player:getStats()
        stats:set(CharacterStat.ZOMBIE_INFECTION, 0)
        stats:set(CharacterStat.ZOMBIE_FEVER, 0)
    end)
end

local function updateKnoxMinute(player, d)
    if not infected(player) then
        d.knox = nil
        return
    end
    if not hasVanillaTrait(player, "base:resilient") then return end
    if not d.knox then d.knox = rollKnox() end
    if not d.knox.lucky then return end
    if progress(player) >= (d.knox.breakAt or 1) then
        cure(player)
        d.knox = nil
        notifyGood(player, "UI_DanTraits_KnoxBeaten")
    end
end

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.knox = function(player, args)
    local d = traitData(player)
    local op = args[1]
    if op == "infect" then
        pcall(function()
            local bd = player:getBodyDamage()
            bd:getBodyPart(BodyPartType.ForeArm_L):SetInfected(true)
            bd:setInfected(true)
            bd:setInfectionTime(getGameTime():getWorldAgeHours())
            bd:setInfectionMortalityDuration(bd:pickMortalityDuration())
        end)
        d.knox = nil
    elseif op == "lucky" or op == "unlucky" then
        d.knox = rollKnox()
        d.knox.lucky = op == "lucky"
    elseif op == "jump" then
        local pct = tonumber(args[2]) or 50
        pcall(function()
            local max = DanTraits_StatMax(CharacterStat.ZOMBIE_INFECTION)
            player:getStats():set(CharacterStat.ZOMBIE_INFECTION, max * pct / 100)
        end)
    end
    local k = d.knox
    return "knox: infected " .. tostring(infected(player)) .. ", progress " .. string.format("%.2f", progress(player))
        .. ", resilient " .. tostring(hasVanillaTrait(player, "base:resilient"))
        .. (k and (", lucky " .. tostring(k.lucky) .. ", breaks at " .. string.format("%.2f", k.breakAt or 0)) or ", not rolled")
        .. ", chance " .. chance() .. "%"
end

DanTraits_Every("minute", "Knox", updateKnoxMinute, 42)

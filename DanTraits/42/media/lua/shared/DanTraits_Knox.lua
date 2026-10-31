-- Project Zomboid Vitality Project: Resilient against the Knox virus.
-- Vanilla Resilient, 6 points dearer (DanTraits_VanillaPrices.lua; the
-- definition itself is vanilla's), keeps its own effect and gains a chance
-- (sandbox KnoxSurviveChance, 10% by default) that the body beats a zombie
-- infection, once. The chance belongs to a Resilient chosen at creation: the
-- flag is read once, the first time the character is seen (mod data
-- knoxResilient), so a trait another mod hands out in play (Dynamic Traits
-- gives Resilient for a fit body) does not bring the roll with it. The roll is
-- made, hidden, the first minute the body is seen infected, and a Run Down
-- body has less of a chance (Vitality's effect, -1..1: down to half at the
-- bottom; a fit body gets the full chance, never more). A lucky character
-- gets sick like anyone else; when the infection
-- (CharacterStat.ZOMBIE_INFECTION) has run KX_BREAK_AT of its way, the fever
-- breaks: the infection and its fever are cleared and a notice says so. The
-- body beats it once: a second infection is not rolled, says so, and is set
-- to run its course in KX_SECOND_H hours. One already there when a save
-- loads rolls then. Mod data: knox = { lucky, breakAt, second }, knoxBeaten.
-- Console `knox [infect|lucky|unlucky|jump <percent>|again]` (Telemetry).
require "DanTraits"

local hasVanillaTrait = DanTraits_HasVanillaTrait
local notifyGood = DanTraits_NotifyGood
local traitData = DanTraits_Data

local KX_CHANCE    = 10           -- percent, when the sandbox has no value
local KX_BREAK_AT  = { 40, 70 }   -- percent of the infection's way when a lucky one breaks
local KX_VITALITY  = 0.5          -- a Run Down body: chance x (1 - this x how run down, 0..1); a fit one gets it whole
local KX_SECOND_H  = 6            -- a second infection runs its course in this many hours

-- the chance this body has: the sandbox value, less for a Run Down one (DanTraits_Vitality.lua)
local function chance(player)
    local c = math.max(0, math.min(100, DanTraits_SandboxNum("KnoxSurviveChance", KX_CHANCE)))
    local e = 0
    if player and DanTraits_VitalityEffect then e = tonumber(DanTraits_VitalityEffect(player)) or 0 end
    if e < 0 then c = c * (1 - KX_VITALITY * math.min(1, -e)) end
    return c
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

local function rollKnox(player)
    return { lucky = DanTraits_RollPercent(chance(player)), breakAt = DanTraits_RandRange(KX_BREAK_AT[1], KX_BREAK_AT[2]) / 100 }
end

-- the body has beaten it once already: this one runs its course, quickly
local function secondInfection(player, d)
    d.knox = { lucky = false, second = true }
    pcall(function() player:getBodyDamage():setInfectionMortalityDuration(KX_SECOND_H) end)
    DanTraits_Notify(player, "UI_DanTraits_KnoxSecond")
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

-- Resilient as chosen at creation (or as held when this version first saw an older save)
local function resilient(player, d)
    if d.knoxResilient == nil then d.knoxResilient = hasVanillaTrait(player, "base:resilient") == true end
    return d.knoxResilient
end

local function updateKnoxMinute(player, d)
    if not infected(player) then
        d.knox = nil
        return
    end
    if not resilient(player, d) then return end
    if not d.knox then
        if d.knoxBeaten then secondInfection(player, d) else d.knox = rollKnox(player) end
    end
    if not d.knox.lucky then return end
    if progress(player) >= (d.knox.breakAt or 1) then
        cure(player)
        d.knox = nil
        d.knoxBeaten = true
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
        d.knox = rollKnox(player)
        d.knox.lucky = op == "lucky"
    elseif op == "again" then   -- forget that it was beaten, so the next infection rolls
        d.knoxBeaten = nil
    elseif op == "jump" then
        local pct = tonumber(args[2]) or 50
        pcall(function()
            local max = DanTraits_StatMax(CharacterStat.ZOMBIE_INFECTION)
            player:getStats():set(CharacterStat.ZOMBIE_INFECTION, max * pct / 100)
        end)
    end
    local k = d.knox
    return "knox: infected " .. tostring(infected(player)) .. ", progress " .. string.format("%.2f", progress(player))
        .. ", resilient " .. tostring(resilient(player, d))
        .. (k and (", lucky " .. tostring(k.lucky) .. ", breaks at " .. string.format("%.2f", k.breakAt or 0)) or ", not rolled")
        .. (k and k.second and " (a second infection)" or "")
        .. ", chance " .. string.format("%.1f", chance(player)) .. "%" .. (d.knoxBeaten and ", beaten once already" or "")
end

DanTraits_OnPlayerReady("Knox", function(player) resilient(player, traitData(player)) end, 60)
DanTraits_Every("minute", "Knox", updateKnoxMinute, 42)

-- Project Zomboid Vitality Project: Tinnitus.
--
-- Damaged ears. Every shot you fire adds to a noise load, more for a louder
-- gun (the weapon's own sound radius: 100 for the game's pistol, 70 for the
-- M1911, 150 to 170 for the rifles, 200 for the shotguns), and the load halves
-- every ten game minutes. A burst of shooting (half a dozen pistol shots, or
-- three from a shotgun, close together) leaves you half deaf and ringing: the
-- vanilla Hard of Hearing trait is put on for half an hour, and longer the
-- louder it got; more shooting while it lasts adds to the time. Keen Hearing
-- is taken off while it lasts and given back after. The ringing also makes
-- light sleep lighter (the sleepWake hook). Only your own shots count: the
-- game gives no event for someone else's, or for an explosion.
--
-- Not with Hard of Hearing or Deaf (Tinnitus would do nothing).
--
-- Mod data: tnNoise (the load), tnDeafMin (minutes left half deaf),
-- tnRinging, tnGranted (we put Hard of Hearing on), tnKeen (we took Keen
-- Hearing off), tnBouts.
-- Console: tinnitus ring [minutes] | tinnitus clear
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local hasVanillaTrait = DanTraits_HasVanillaTrait
local notify = DanTraits_Notify
local traitData = DanTraits_Data

local TN_RADIUS_UNIT   = 100     -- a shot of this sound radius (the pistol's) adds 1 to the load
local TN_SHOT_MAX      = 2       -- no single shot adds more than this (a shotgun's)
local TN_HALF_MIN      = 10      -- minutes for the load to halve
local TN_DEAF_AT       = 6       -- load at which the ears give out
local TN_DEAF_MIN      = 30      -- minutes half deaf when they do...
local TN_DEAF_PER      = 10      -- ...plus this a point of load past it
local TN_DEAF_MAX      = 240     -- at most this long
local TN_WAKE          = 1.5     -- light wakes you x this while ringing

local function traitConst(name) return CharacterTrait and CharacterTrait[name] end

local function setTrait(player, name, on)
    local trait = traitConst(name)
    if not trait then return false end
    local ok = pcall(function()
        local traits = player:getCharacterTraits()
        if on and not traits:get(trait) then traits:add(trait) end
        if not on and traits:get(trait) then traits:remove(trait) end
    end)
    DanTraits_TraitsChanged(player)
    return ok
end

local function goDeaf(player, d)
    if not d.tnRinging then
        d.tnRinging = true
        if not hasVanillaTrait(player, "base:hardofhearing") and setTrait(player, "HARD_OF_HEARING", true) then d.tnGranted = true end
        if hasVanillaTrait(player, "base:keenhearing") and setTrait(player, "KEEN_HEARING", false) then d.tnKeen = true end
        d.tnBouts = (d.tnBouts or 0) + 1
        notify(player, "UI_DanTraits_TinnitusRinging")
    end
end

local function hearAgain(player, d, say)
    if d.tnGranted then setTrait(player, "HARD_OF_HEARING", false) end
    if d.tnKeen then setTrait(player, "KEEN_HEARING", true) end
    d.tnGranted, d.tnKeen, d.tnDeafMin, d.tnRinging = nil, nil, nil, nil
    if say then DanTraits_NotifyGood(player, "UI_DanTraits_TinnitusFaded") end
end

-- one shot of a gun this loud (its sound radius)
local function onShot(player, radius)
    if not player or not hasTrait(player, "tinnitus") then return false end
    local d = traitData(player)
    d.tnNoise = (d.tnNoise or 0) + math.min(TN_SHOT_MAX, (radius or TN_RADIUS_UNIT) / TN_RADIUS_UNIT)
    if d.tnNoise >= TN_DEAF_AT then
        local minutes = math.min(TN_DEAF_MAX, TN_DEAF_MIN + TN_DEAF_PER * (d.tnNoise - TN_DEAF_AT))
        d.tnDeafMin = math.min(TN_DEAF_MAX, math.max(d.tnDeafMin or 0, minutes) + ((d.tnDeafMin or 0) > 0 and TN_DEAF_PER or 0))
        goDeaf(player, d)
    end
    return true
end
DanTraits_TinnitusShot = onShot

local function onWeaponSwing(character, weapon)
    local player = getSpecificPlayer(0)
    if not player or character ~= player or not weapon then return end
    local ranged, radius = false, nil
    pcall(function() ranged = weapon:isRanged() end)
    if not ranged then return end
    pcall(function() radius = weapon:getSoundRadius() end)
    onShot(player, tonumber(radius))
end
DanTraits_TinnitusOnSwing = onWeaponSwing

local function updateTinnitusMinute(player, d)
    if (d.tnNoise or 0) > 0 then
        d.tnNoise = d.tnNoise * 0.5 ^ (1 / TN_HALF_MIN)
        if d.tnNoise < 0.05 then d.tnNoise = 0 end
    end
    if d.tnRinging or d.tnGranted or d.tnKeen or d.tnDeafMin then
        -- the trait was taken away: put the ears back at once
        if not hasTrait(player, "tinnitus") then hearAgain(player, d, false) return end
        d.tnDeafMin = (d.tnDeafMin or 0) - 1
        if d.tnDeafMin <= 0 then hearAgain(player, d, true) end
    end
end
DanTraits_updateTinnitusMinute = updateTinnitusMinute

DanTraits_AddHook("sleepWake", function(m, player, d)
    if not d or (d.tnDeafMin or 0) <= 0 then return nil end
    return m * TN_WAKE
end)

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.tinnitus = function(player, args)
    local d = traitData(player)
    if args[1] == "ring" then
        d.tnDeafMin = tonumber(args[2]) or TN_DEAF_MIN
        goDeaf(player, d)
        return "half deaf for " .. tostring(d.tnDeafMin) .. " minutes"
    end
    if args[1] == "clear" then hearAgain(player, d, false) d.tnNoise = 0 return "ears clear" end
    return "tinnitus ring [minutes] | tinnitus clear (noise load " .. tostring(d.tnNoise or 0) .. ")"
end

Events.OnWeaponSwing.Add(onWeaponSwing)
DanTraits_Every("minute", "Tinnitus", updateTinnitusMinute, 40)

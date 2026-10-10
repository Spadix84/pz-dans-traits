-- Project Zomboid Vitality Project: Bandits (Bandits2) compatibility.
require "DanTraits"

-- Does nothing unless Bandits is loaded. No dependency either way.
--
-- Phantom guard. Bandits are zombie bodies, and Bandits keeps a list of every
-- other zombie in the cell (BanditZombie.CacheLightZ) that its bandits pick
-- targets from, shoot at and trace bullets through. Its update also un-parks
-- every plain zombie it passes ("useless" off). The Schizophrenia phantom
-- (DanTraits_Hallucinations.lua) is a real zombie for a few seconds, so
-- bandits, hostile or friendly, would open fire at something only the player
-- can see. Bandits' own handlers are file locals and cannot be wrapped, so this
-- adds an OnZombieUpdate of its own at game start, after Bandits' (handlers
-- run in the order they were added): on a phantom it takes it back out of
-- Bandits' lists and parks it again. Bandits' once-a-minute rebuild of the
-- lists can put a phantom back for the rest of that frame; the next update
-- takes it out.
--
-- Hits. Bandit gunfire and blows go through BanditServer.Commands.PlayerDamage
-- (ReduceGeneralHealth, wounds set by hand), which fires no OnPlayerGetDamage.
-- It is wrapped to report the hit (DanTraits_OtherHit, DanTraits_Util.lua):
-- its healthDrop is the damage, and all of it counts against the head when the
-- hit landed there. A shot stopped by clothing, or a graze, has no healthDrop
-- and is not a hit. BanditServer.Commands is looked up on every command, so
-- replacing the field is enough.
local installed = false

local CACHES = { "Cache", "CacheLight", "CacheLightZ", "CacheLightB" }

local function isPhantom(zombie)
    return zombie ~= nil and DanTraits_IsPhantom ~= nil and DanTraits_IsPhantom(zombie)
end

local function hidePhantom(zombie)
    if not isPhantom(zombie) then return end
    pcall(function() if not zombie:isUseless() then zombie:setUseless(true) end end)
    if type(BanditZombie) ~= "table" or type(BanditUtils) ~= "table" or type(BanditUtils.GetZombieID) ~= "function" then return end
    local ok, id = pcall(BanditUtils.GetZombieID, zombie)
    if not ok or id == nil then return end
    for _, key in ipairs(CACHES) do
        if type(BanditZombie[key]) == "table" then BanditZombie[key][id] = nil end
    end
end

local function headIndex()
    local index = nil
    pcall(function() index = BodyPartType.ToIndex(BodyPartType.Head) end)
    return index
end

local function wrapDamage()
    local commands = type(BanditServer) == "table" and BanditServer.Commands
    if type(commands) ~= "table" or type(commands.PlayerDamage) ~= "function" then return false end
    local original = commands.PlayerDamage
    commands.PlayerDamage = function(player, args, ...)
        local result = original(player, args, ...)
        local drop = type(args) == "table" and tonumber(args.healthDrop) or nil
        if drop and drop > 0 then
            local onHead = args.bodyPartIndex ~= nil and args.bodyPartIndex == headIndex()
            DanTraits_OtherHit(player, drop, onHead and drop or 0)
        end
        return result
    end
    return true
end

-- Bandits' files load after this one: run at game start.
local function install()
    if installed or type(BanditZombie) ~= "table" then return end
    installed = true
    Events.OnZombieUpdate.Add(hidePhantom)
    local hits = wrapDamage()
    print("[DanTraits] Bandits found, phantom guard on, hits " .. tostring(hits))
end
DanTraits_BanditsInstall = install

Events.OnGameStart.Add(install)

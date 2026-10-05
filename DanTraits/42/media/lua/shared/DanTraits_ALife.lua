-- Project Zomboid Vitality Project: Project A-Life (ProjectALifeNPCs) compatibility.
require "DanTraits"

-- Does nothing unless A-Life is loaded. No dependency either way.
--
-- Phantom guard. A-Life's NPCs are zombie bodies, and it also steers every
-- other zombie in the cell: its horde code picks them prey (an NPC or the
-- player), un-parks "useless" ones and starts bites, and its NPCs spot and
-- shoot them. The Schizophrenia phantom (DanTraits_Hallucinations.lua) is a
-- real zombie for a few seconds, so all of that would reach it: a phantom
-- that turns on an NPC, or a squad opening fire at something only the
-- player can see. Three of A-Life's own functions are wrapped to leave a
-- phantom out; everything else passes straight through.
--   HordeRelations.steersHere   the gate before any horde thinking on a zombie
--   TargetPolicy.canAttack      the gate before any NPC attack on a target
--   Perception.quietRefuses     the gate before an NPC's sight check on a zombie
-- These are looked up through A-Life's tables on every call, so replacing the
-- field is enough. (Its OnZombieUpdate handler itself is registered by
-- reference; wrapping that one would do nothing.)
local installed = false

local function isPhantom(body)
    return body ~= nil and DanTraits_IsPhantom ~= nil and DanTraits_IsPhantom(body)
end

-- replace owner[name] with guard(original); false when A-Life has no such function
local function wrap(owner, name, guard)
    if type(owner) ~= "table" or type(owner[name]) ~= "function" then return false end
    owner[name] = guard(owner[name])
    return true
end

-- A-Life's client and server files load after this one: run at game start.
local function install()
    if installed or type(ProjectALife) ~= "table" then return end
    installed = true
    local horde = wrap(ProjectALife.HordeRelations, "steersHere", function(original)
        return function(zombie, ...)
            if isPhantom(zombie) then return false end
            return original(zombie, ...)
        end
    end)
    local target = wrap(ProjectALife.TargetPolicy, "canAttack", function(original)
        return function(target, ...)
            if isPhantom(target) then return false, "target_phantom" end
            return original(target, ...)
        end
    end)
    local sight = wrap(ProjectALife.Perception, "quietRefuses", function(original)
        return function(actor, shell, candidate, ...)
            if isPhantom(candidate) then return true end
            return original(actor, shell, candidate, ...)
        end
    end)
    print("[DanTraits] Project A-Life found, phantom guard: horde " .. tostring(horde)
        .. ", target " .. tostring(target) .. ", sight " .. tostring(sight))
end
DanTraits_ALifeInstall = install

Events.OnGameStart.Add(install)

-- Project Zomboid Vitality Project: Hunted.
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local traitData = DanTraits_Data

-- Hunted --------------------------------------------------------------------
-- They followed you here. A start to run from, for points, in the family of
-- A Really Bad Day, Wounded and Robbed: a horde set loose on the house you
-- wake in after a short grace, everything nearby pulled to it, a helicopter
-- over you that afternoon, and a smaller group at dawn for the first three
-- days, aimed at wherever you are. Stay and fortify and you are buried; pack
-- a bag, leave, sleep somewhere new each night and it fades.
--
-- The horde: HT_SPAWN_H hours after waking, HT_GROUPS zombies in two groups
-- are created HT_DIST tiles out (the farthest loaded distance, tried from the
-- far end in) and pathed to the house (createHordeFromTo). Zombies can only
-- be made on loaded ground, and the game keeps about 50 tiles around you
-- loaded (IsoChunkMap: 13 chunks of 8 tiles a side), so in practice they
-- start 50-65 tiles out, beyond sight, and a shambler covers that in a
-- quarter of an hour: hence the late release, so they arrive around hour
-- three, with the notice a few minutes' warning. For HT_PULL_H hours after
-- that a world sound at the house every HT_PULL_MIN minutes (radius
-- HT_PULL_RADIUS) keeps them, and the neighbours, coming. The helicopter: at
-- HT_HELI_H hours the game's own flyover (testHelicopter: the debug panel's
-- button, the real event). Dawn: at HT_DAWN_HOUR on the first HT_DAWN_DAYS
-- mornings after the horde is loose, HT_DAWN_N zombies HT_DAWN_DIST tiles
-- from where you are, pathed to you. Each piece is applied once, tracked in
-- mod data, so reloads and respawns are safe. Singleplayer: zombies are the
-- server's to make, so on a client or server nothing happens (the trait
-- script disables it in multiplayer; this guard covers a character carried
-- in). Console: `hunted [now|dawn|heli]`.
local HT_SPAWN_H     = 2.75       -- hours survived when the horde is set loose
local HT_GROUPS      = { 22, 23 } -- two groups, ~40 degrees apart
local HT_SPREAD      = 0.7        -- radians between the groups
local HT_DIST        = { 200, 175, 150, 125, 100, 80, 65, 50, 40 }  -- tiles out, farthest loaded distance wins
local HT_MAX_TRIES   = 30         -- minutes spent looking for loaded ground before giving up
local HT_PULL_H      = 4          -- hours the house keeps calling after the horde is loose
local HT_PULL_MIN    = 10         -- a sound every this many minutes
local HT_PULL_RADIUS = 120
local HT_HELI_H      = 4          -- hours survived when the helicopter comes
local HT_DAWN_HOUR   = 6
local HT_DAWN_DAYS   = 3
local HT_DAWN_N      = 15
local HT_DAWN_DIST   = { 150, 125, 100, 80, 65, 50, 40 }

local function multiplayer()
    return (isClient and isClient()) or (isServer and isServer()) or false
end

local function here(player)
    return { x = math.floor(player:getX()), y = math.floor(player:getY()), z = math.floor(player:getZ() or 0) }
end

-- the farthest loaded square along `angle` from (cx, cy); nil when none of the distances is loaded
local function loadedSpot(cx, cy, angle, dists)
    local cell = getCell()
    for _, dist in ipairs(dists) do
        local x, y = math.floor(cx + math.cos(angle) * dist), math.floor(cy + math.sin(angle) * dist)
        local sq = nil
        pcall(function() sq = cell:getGridSquare(x, y, 0) end)
        if sq then return x, y end
    end
    return nil
end

-- the groups, one per entry of `counts`, each pathed to (toX, toY); returns how many zombies were asked for
local function release(counts, toX, toY, dists)
    local base = ZombRand(360) * math.pi / 180
    local asked = 0
    for i, count in ipairs(counts) do
        local x, y = loadedSpot(toX, toY, base + (i - 1) * HT_SPREAD, dists)
        if x then
            local ok = pcall(function() createHordeFromTo(x, y, toX, toY, count) end)
            if ok then asked = asked + count end
        end
    end
    return asked
end

local function onHuntedCreatePlayer(playerNum, player)
    if not player or not hasTrait(player, "hunted") then return end
    if player:getHoursSurvived() > 0 then return end
    local d = traitData(player)
    if d.htHome then return end
    d.htHome = here(player)
    notify(player, "UI_DanTraits_HuntedWake")
end

local function huntedMinute(player, d)
    if multiplayer() then return end
    local home = d.htHome
    if not home then return end
    local hours = player:getHoursSurvived() or 0

    -- the horde
    if not d.htLoosed and hours >= HT_SPAWN_H then
        local asked = release(HT_GROUPS, home.x, home.y, HT_DIST)
        d.htTries = (d.htTries or 0) + 1
        if asked > 0 or d.htTries >= HT_MAX_TRIES then
            d.htLoosed = true
            d.htPullUntil = hours + HT_PULL_H
            d.htLastPull = nil
            if asked > 0 then notify(player, "UI_DanTraits_HuntedComing") end
        end
    end

    -- the house keeps calling
    if d.htLoosed and d.htPullUntil and hours < d.htPullUntil then
        local minute = math.floor(hours * 60)
        if not d.htLastPull or minute - d.htLastPull >= HT_PULL_MIN then
            d.htLastPull = minute
            pcall(function() addSound(player, home.x, home.y, home.z or 0, HT_PULL_RADIUS, HT_PULL_RADIUS) end)
        end
    end

    -- the helicopter
    if not d.htHeliDone and hours >= HT_HELI_H then
        d.htHeliDone = true
        pcall(function() testHelicopter() end)
    end

    -- dawn: the game counts a night survived at 07:00, so at 06:00 the nights
    -- so far number the mornings before this one; the first HT_DAWN_DAYS
    -- mornings once the horde is loose (a 05:00 start is not hunted at 06:00)
    local nights, hour = nil, nil
    pcall(function() local gt = getGameTime(); nights, hour = gt:getNightsSurvived(), gt:getHour() end)
    local morning = nights and nights + 1
    if d.htLoosed and morning and morning <= HT_DAWN_DAYS and hour == HT_DAWN_HOUR and d.htDawnDay ~= morning then
        d.htDawnDay = morning
        local at = here(player)
        if release({ HT_DAWN_N }, at.x, at.y, HT_DAWN_DIST) > 0 then notify(player, "UI_DanTraits_HuntedDawn") end
    end
end

-- Console `hunted [now|dawn|heli]` (Telemetry, via DanTraits_ExtraCommands):
-- `now` sets the horde on where you stand (and makes it home for the pull),
-- `dawn` the dawn group, `heli` the flyover; no argument lists the state.
function DanTraits_HuntedReplay(player, what)
    if not player then return "hunted: no player" end
    local d = traitData(player)
    if what == "now" then
        local at = here(player)
        d.htHome, d.htLoosed, d.htPullUntil, d.htLastPull = at, true, (player:getHoursSurvived() or 0) + HT_PULL_H, nil
        return "hunted: " .. tostring(release(HT_GROUPS, at.x, at.y, HT_DIST)) .. " zombies loosed on " .. at.x .. "," .. at.y
    elseif what == "dawn" then
        local at = here(player)
        return "hunted: dawn group, " .. tostring(release({ HT_DAWN_N }, at.x, at.y, HT_DAWN_DIST)) .. " zombies"
    elseif what == "heli" then
        local ok = pcall(function() testHelicopter() end)
        return ok and "hunted: helicopter called" or "hunted: no helicopter (testHelicopter failed)"
    end
    local home = d.htHome
    return "hunted: home " .. (home and (home.x .. "," .. home.y) or "none") .. ", horde " .. (d.htLoosed and "loose" or "waiting")
        .. ", heli " .. (d.htHeliDone and "done" or "waiting") .. ", dawn day " .. tostring(d.htDawnDay or 0)
end

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.hunted = function(player, args) return DanTraits_HuntedReplay(player, args[1]) end

Events.OnCreatePlayer.Add(onHuntedCreatePlayer)
DanTraits_Every("minute", "Hunted", huntedMinute, 60, { trait = "hunted" })

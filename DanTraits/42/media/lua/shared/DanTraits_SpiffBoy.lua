-- Project Zomboid Vitality Project: SpiffBoy (the handheld console) compatibility.
require "DanTraits"

-- Does nothing unless SpiffBoy is loaded. No dependency either way.
--
-- SpiffBoy makes vanilla's Base.VideoGame a working console. Playing opens its
-- SpiffBoyHandheldWindow (one per local player, SpiffBoyHandheldWindow.forPlayer),
-- and every real second it is on screen and powered SpiffBoy.Mood.applySecond
-- takes boredom and unhappiness off. A hit puts it away (hidden, still running
-- in the pocket); its put-away is what this file uses too.
--
-- The screen. DanTraits_ScreenTime(player) is nil, "screen" (powered and on
-- screen: the boot logo, a crash, no cartridge) or "game" (a cartridge's game
-- running). The systems read it in their own files:
--   Strain      an hour of play is a comfort ("game"), like an hour of reading
--   Concussion  screen time heals it at half speed, and at moderate or worse
--               (and in the headache that comes back) adds a little head pain
--   Migraine    in an attack the screen counts as a lit room
-- Putting it away. Vitality passing you out, a collapse, a seizure, falling
-- asleep: the console is put away as a hit puts it away (the passingOut hook,
-- DanTraits_Faint.lua; the minute below for sleep).
-- Old games. Each cartridge keeps the game hours played on it (d.sbPlayed, by
-- the cartridge's item type: { h = hours, at = world hours last played }); a
-- day it is not played takes SB.REST_H off. Its mood relief is full for the
-- first SB.FRESH_H hours, then falls to SB.STALE of it at SB.STALE_H. ADHD: a
-- new game grips (x SB.ADHD_NEW for the first SB.ADHD_FRESH_H hours) and goes
-- stale twice as fast. The relief is SpiffBoy's own, scaled inside its
-- applySecond, so its PlayingEasesMood sandbox switch still turns it all off.
--
-- Mod data: sbPlayed, sbPlayMin (minutes counted, for the tests).

local hasTrait = DanTraits_HasTrait

local SB = {
    FRESH_H = 3,        -- game hours on one cartridge at full relief...
    STALE_H = 20,       -- ...falling to SB.STALE of it by here
    STALE = 0.3,
    REST_H = 2,         -- hours forgotten a game day it is not played
    ADHD_NEW = 1.5,     -- ADHD: relief x this while new...
    ADHD_FRESH_H = 1.5, -- ...for this long; and both spans halved
    KEEP = 40,          -- cartridges remembered (the least played go first)
}
DanTraits_SpiffBoySB = SB   -- tests

local installed = false

local function nowHours()
    local h = 0
    pcall(function() h = getGameTime():getWorldAgeHours() end)
    return h
end

local function windowOf(player)
    local W = SpiffBoyHandheldWindow
    if not installed or type(W) ~= "table" or type(W.forPlayer) ~= "function" or not player then return nil end
    local w = nil
    pcall(function() w = W.forPlayer(player:getPlayerNum()) end)
    return w
end

local function shown(w)
    return w ~= nil and not w.closing and not w.hidden
end

-- nil, "screen" or "game", and the cartridge's item type while a game runs
local function screenOf(player)
    local w = windowOf(player)
    if not shown(w) or not w.powered then return nil end
    local rt = w.runtime
    local frozen = w.glitch ~= nil or w.linkLost == true
    if w.definition and not w.boot and not w.gameMissing and not frozen and rt and rt.game and not rt.crash then
        return "game", w.definition.item
    end
    return "screen"
end

function DanTraits_ScreenTime(player)
    return (screenOf(player))
end

-- the console out of your hands, as a hit does it (powered: into the pocket, still running)
local function putAway(player)
    local w = windowOf(player)
    if not shown(w) or type(w.putAway) ~= "function" then return false end
    local ok = pcall(function() w:putAway() end)
    if ok then DanTraits_Notify(player, "UI_DanTraits_SpiffBoyPutAway") end
    return ok
end
DanTraits_SpiffBoyPutAway = putAway

-- old games ------------------------------------------------------------------------------

-- the hours played on this cartridge, less what the days since have rested off
local function rested(rec, now)
    if not rec then return 0 end
    local idle = math.max(0, now - (rec.at or now))
    return math.max(0, (rec.h or 0) - idle / 24 * SB.REST_H)
end

-- the share of SpiffBoy's relief this cartridge gives now
function DanTraits_SpiffBoyFreshness(player, itemType)
    if not player or not itemType then return 1 end
    local d = DanTraits_Data(player)
    local h = rested(d.sbPlayed and d.sbPlayed[itemType], nowHours())
    -- a minute is 1/60, so the hours add up a hair off the round number
    local eps = 1e-9
    local fresh, stale = SB.FRESH_H, SB.STALE_H
    if hasTrait(player, "adhd") then
        fresh, stale = fresh / 2, stale / 2
        if h < SB.ADHD_FRESH_H - eps then return SB.ADHD_NEW end
    end
    if h <= fresh + eps then return 1 end
    if h >= stale - eps then return SB.STALE end
    return 1 - (1 - SB.STALE) * (h - fresh) / (stale - fresh)
end

-- room for one more: the least played goes when the list is full
local function makeRoom(played)
    local n, low, lowKey = 0, nil, nil
    for key, rec in pairs(played) do
        n = n + 1
        if not low or (rec.h or 0) < low then low, lowKey = rec.h or 0, key end
    end
    if n >= SB.KEEP and lowKey then played[lowKey] = nil end
end

local function countMinute(player, d, itemType)
    d.sbPlayed = d.sbPlayed or {}
    local now = nowHours()
    local rec = d.sbPlayed[itemType]
    if not rec then
        makeRoom(d.sbPlayed)
        rec = { h = 0, at = now }
        d.sbPlayed[itemType] = rec
        if hasTrait(player, "adhd") then DanTraits_NotifyGood(player, "UI_DanTraits_SpiffBoyNew") end
    end
    local before = DanTraits_SpiffBoyFreshness(player, itemType)
    rec.h = rested(rec, now) + 1 / 60
    rec.at = now
    d.sbPlayMin = (d.sbPlayMin or 0) + 1
    local after = DanTraits_SpiffBoyFreshness(player, itemType)
    if before > SB.STALE and after <= SB.STALE then DanTraits_Notify(player, "UI_DanTraits_SpiffBoyStale") end
end

local function updateSpiffBoyMinute(player, d)
    if not installed then return end
    if DanTraits_Asleep(player) then putAway(player) return end
    local kind, itemType = screenOf(player)
    if kind == "game" and itemType then countMinute(player, d, itemType) end
end
DanTraits_Every("minute", "SpiffBoy", updateSpiffBoyMinute, 44)

-- scale SpiffBoy's own per-second relief by the cartridge's freshness
local function wrapMood()
    local mood = type(SpiffBoy) == "table" and SpiffBoy.Mood
    if type(mood) ~= "table" then return false end
    return DanTraits_Wrap(mood, "applySecond", "dantraits-stale", function(original, playerObj, ...)
        local kind, itemType = screenOf(playerObj)
        local k = kind == "game" and DanTraits_SpiffBoyFreshness(playerObj, itemType) or 1
        if k == 1 then return original(playerObj, ...) end
        local b, u = mood.BOREDOM_PER_SECOND, mood.UNHAPPINESS_PER_SECOND
        mood.BOREDOM_PER_SECOND, mood.UNHAPPINESS_PER_SECOND = (b or 0) * k, (u or 0) * k
        local ok, err = pcall(original, playerObj, ...)
        mood.BOREDOM_PER_SECOND, mood.UNHAPPINESS_PER_SECOND = b, u
        if not ok then error(err) end
    end)
end

DanTraits_AddHook("passingOut", function(_, player)
    putAway(player)
    return nil
end)

-- SpiffBoy's client files load after this one: run at game start.
local function install()
    if installed or type(SpiffBoyHandheldWindow) ~= "table" then return end
    installed = true
    local mood = wrapMood()
    print("[DanTraits] SpiffBoy found, screen time and old games on, mood wrap " .. tostring(mood))
end
DanTraits_SpiffBoyInstall = install

Events.OnGameStart.Add(install)

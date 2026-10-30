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
-- Still Water (the Vitality Cartridges mod's breathing game, item STILL_WATER):
-- its game keeps self.vitality = { active, calm 0..1 } and
-- DanTraits_StillWaterCalm(player) reads it (0 unless a session is on screen).
-- A game minute at calm c takes SB.SW_STRESS x c stress and SB.SW_PANIC x c
-- panic off here; Sensory drains x (1 + c) (its calmOf); Strain counts its
-- minutes at SB.SW_CALM or more toward the comfort "breathe" (and not toward
-- "game": practice, not play).
--
-- The batch-2 cartridges (plans/cartridges-batch-2.md), each read or fed once a
-- game minute while its game runs, shown or in the pocket (gameOf):
--   Steady        writes vitality.tremor and vitality.slow (0..1) from the
--                 character: drink, withdrawal shakes, a diabetic low, an MS
--                 flare, panic, an adrenaline rush, caffeine withdrawal (Steady
--                 Hands halves it, unless the hands are shaking); concussion,
--                 drink, tiredness, a hangover, sumatriptan's day after
--   Spiffo Walk   writes vitality.steps (tiles walked on foot x SB.WALK_STEP,
--                 counted only while it runs, d.cwSteps) and vitality.day;
--                 its goalMet is Strain's comfort "walk", once a day
--   First Aid Quiz  a finished round of SB.QUIZ_PASS or more, once a day, gives
--                 First Aid SB.QUIZ_XP experience under level SB.QUIZ_LEVEL
--   Spiffo Pup    writes vitality.hours; a care action is Strain's comfort
--                 "pet"; its care feeds DanTraits_PupCare (MDD's floor); its
--                 running away costs SB.PUP_GONE unhappiness, once
-- What Vitality has already counted of a power-on it keeps in the game's own
-- vitality table (dtRounds, dtCared), so a new power-on starts from 0.
--
-- Mod data: sbPlayed, sbPlayMin (minutes counted, for the tests); cwSteps,
-- cwX, cwY, cwGoalDay (Spiffo Walk); fqDay (First Aid Quiz); ppCare, ppSeen,
-- ppGone (Spiffo Pup).

local hasTrait = DanTraits_HasTrait

local SB = {
    FRESH_H = 3,        -- game hours on one cartridge at full relief...
    STALE_H = 20,       -- ...falling to SB.STALE of it by here
    STALE = 0.3,
    REST_H = 2,         -- hours forgotten a game day it is not played
    ADHD_NEW = 1.5,     -- ADHD: relief x this while new...
    ADHD_FRESH_H = 1.5, -- ...for this long; and both spans halved
    KEEP = 40,          -- cartridges remembered (the least played go first)
    SW_STRESS = 0.004,  -- Still Water: stress (0..1) off a minute at full calm...
    SW_PANIC = 2,       -- ...and panic (0..100)
    SW_CALM = 0.6,      -- calm that counts toward Strain's comfort
    WALK_STEP = 1.5,    -- Spiffo Walk: steps a tile walked
    WALK_MAX = 60,      -- tiles in a minute past which it was no walk (a load, a teleport)
    QUIZ_PASS = 8,      -- First Aid Quiz: a round of this many right...
    QUIZ_XP = 20,       -- ...gives this First Aid experience, once a game day...
    QUIZ_LEVEL = 3,     -- ...under this level
    PUP_CARE = 0.5,     -- Spiffo Pup: cared for at this share of its lowest need...
    PUP_SEEN_H = 24,    -- ...seen this recently, MDD's floor eases
    PUP_GONE = 15,      -- unhappiness (0..100) when it runs away
}
local STILL_WATER = "VitalityCartridges.Cartridge_StillWater"
DanTraits_StillWaterItem = STILL_WATER
local STEADY = "VitalityCartridges.Cartridge_Steady"
local WALK = "VitalityCartridges.Cartridge_SpiffoWalk"
local QUIZ = "VitalityCartridges.Cartridge_FirstAidQuiz"
local PUP = "VitalityCartridges.Cartridge_SpiffoPup"
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

-- nil, "screen" or "game"; and with a game, the cartridge's item type
function DanTraits_ScreenTime(player)
    return screenOf(player)
end

-- 0..1: how even the breathing is in a Still Water session on screen, else 0
function DanTraits_StillWaterCalm(player)
    local kind, itemType = screenOf(player)
    if kind ~= "game" or itemType ~= STILL_WATER then return 0 end
    local w = windowOf(player)
    local game = w and w.runtime and w.runtime.game
    local v = type(game) == "table" and game.vitality
    if type(v) ~= "table" or v.active ~= true then return 0 end
    local c = tonumber(v.calm) or 0
    if c < 0 then return 0 end
    return c > 1 and 1 or c
end

-- the vitality table of this cartridge's game while it runs, shown or in the pocket
local function gameOf(player, itemType)
    local w = windowOf(player)
    if not w or w.closing or not w.powered or not w.definition or w.definition.item ~= itemType then return nil end
    local rt = w.runtime
    if w.boot or w.gameMissing or w.glitch ~= nil or w.linkLost == true or not rt or rt.crash then return nil end
    local v = type(rt.game) == "table" and rt.game.vitality
    if type(v) ~= "table" then return nil end
    return v
end
DanTraits_SpiffBoyGameOf = gameOf

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

-- the batch-2 cartridges ---------------------------------------------------------------

-- 1 - the product of (1 - each): several small causes add up, never past 1
local function combine(parts)
    local keep = 1
    for _, x in ipairs(parts) do keep = keep * (1 - math.max(0, math.min(1, x))) end
    return 1 - keep
end

local function stat01(player, stat)
    local v = 0
    pcall(function() v = DanTraits_StatFraction(player:getStats(), stat) end)
    return v
end

-- Steady's wobble: how much the hands shake now, 0..1
function DanTraits_SteadyTremor(player, d)
    local shakes = (d.alcShakes or 0) > 0
    local low = DanTraits_Strength("DanTraits_DiaLow", player)
    local intox = DanTraits_Intoxication and DanTraits_Intoxication(player) or 0
    local rush = DanTraits_AdrenalineRush ~= nil and DanTraits_AdrenalineRush(player) == true
    local t = combine({
        intox * 0.8, shakes and 0.7 or 0, low,
        ((d.msFlareH or 0) > 0 and hasTrait(player, "ms")) and 0.5 or 0,
        stat01(player, CharacterStat.PANIC) * 0.5, rush and 0.4 or 0,
        DanTraits_Strength("DanTraits_CaffeineWithdrawalOf", player) * 0.3,
    })
    -- Steady Hands, unless something has the hands shaking (its own rule)
    if hasTrait(player, "steadyhands") and not shakes and low <= 0 then t = t * 0.5 end
    return t
end

-- Steady's lag: how slow the reactions are now, 0..1
function DanTraits_SteadySlow(player, d)
    local intox = DanTraits_Intoxication and DanTraits_Intoxication(player) or 0
    return combine({
        DanTraits_Strength("DanTraits_ConcussionStrength", player), intox * 0.6,
        stat01(player, CharacterStat.FATIGUE) * 0.5,
        DanTraits_Strength("DanTraits_HangoverStrength", player) * 0.4,
        (d.tripAfterMin or 0) > 0 and 0.3 or 0,
    })
end

local function dayIndex()
    local day = 0
    pcall(function()
        local gt = getGameTime()
        day = math.floor((gt:getWorldAgeHours() - (gt:getTimeOfDay() or 0)) / 24 + 0.5)
    end)
    return day
end

local function inVehicle(player)
    local car = nil
    pcall(function() car = player:getVehicle() end)
    return car ~= nil
end

-- steps on foot since the last minute; the place is forgotten while the game is off.
-- The game's goalMet answers the day written last minute, so it is read before
-- the new day goes in (at midnight it still speaks for yesterday).
local function walkMinute(player, d, v)
    local goalDay = v.day
    if v.goalMet == true and goalDay ~= nil and d.cwGoalDay ~= goalDay then
        d.cwGoalDay = goalDay
        if DanTraits_StrainComfort then DanTraits_StrainComfort(player, "walk") end
        DanTraits_NotifyGood(player, "UI_DanTraits_SpiffoWalkGoal")
    end
    local x, y = nil, nil
    pcall(function() x, y = player:getX(), player:getY() end)
    if x and d.cwX and not inVehicle(player) then
        local dist = math.sqrt((x - d.cwX) * (x - d.cwX) + (y - d.cwY) * (y - d.cwY))
        if dist <= SB.WALK_MAX then d.cwSteps = (d.cwSteps or 0) + dist * SB.WALK_STEP end
    end
    d.cwX, d.cwY = x, y
    v.steps, v.day = math.floor(d.cwSteps or 0), dayIndex()
end

local function quizMinute(player, d, v)
    local rounds = tonumber(v.rounds) or 0
    if rounds <= (v.dtRounds or 0) then return end
    v.dtRounds = rounds
    local day = dayIndex()
    if (tonumber(v.lastScore) or 0) < SB.QUIZ_PASS or d.fqDay == day then return end
    local level = 0
    pcall(function() level = player:getPerkLevel(Perks.Doctor) end)
    if level >= SB.QUIZ_LEVEL then return end
    d.fqDay = day
    pcall(function() player:getXp():AddXP(Perks.Doctor, SB.QUIZ_XP) end)
    DanTraits_NotifyGood(player, "UI_DanTraits_FirstAidQuizXp")
end

local function pupMinute(player, d, v)
    local now = nowHours()
    v.hours = now
    local cared = tonumber(v.cared) or 0
    if cared > (v.dtCared or 0) then
        v.dtCared = cared
        if DanTraits_StrainComfort then DanTraits_StrainComfort(player, "pet") end
    end
    if tonumber(v.care) then d.ppCare, d.ppSeen = tonumber(v.care), now end
    if v.gone == true and not d.ppGone then
        d.ppGone = true
        DanTraits_StatAdd(player:getStats(), CharacterStat.UNHAPPINESS, SB.PUP_GONE)
        DanTraits_Notify(player, "UI_DanTraits_SpiffoPupGone")
    elseif v.gone ~= true then
        d.ppGone = nil
    end
end

-- 1 while the pup was last seen cared for, within the day; MDD's floor reads it
function DanTraits_PupCare(player)
    local d = player and DanTraits_Data(player)
    if not d or not d.ppSeen or nowHours() - d.ppSeen > SB.PUP_SEEN_H then return 0 end
    return (d.ppCare or 0) >= SB.PUP_CARE and 1 or 0
end

local function cartridgesMinute(player, d)
    local v = gameOf(player, STEADY)
    if v then v.tremor, v.slow = DanTraits_SteadyTremor(player, d), DanTraits_SteadySlow(player, d) end
    v = gameOf(player, WALK)
    if v then walkMinute(player, d, v) else d.cwX, d.cwY = nil, nil end
    v = gameOf(player, QUIZ)
    if v then quizMinute(player, d, v) end
    v = gameOf(player, PUP)
    if v then pupMinute(player, d, v) end
end

local function updateSpiffBoyMinute(player, d)
    if not installed then return end
    -- a game in the pocket keeps going while you sleep
    cartridgesMinute(player, d)
    if DanTraits_Asleep(player) then putAway(player) return end
    local kind, itemType = screenOf(player)
    if kind == "game" and itemType then countMinute(player, d, itemType) end
    local calm = DanTraits_StillWaterCalm(player)
    if calm > 0 then
        local stats = player:getStats()
        DanTraits_StatAdd(stats, CharacterStat.STRESS, -SB.SW_STRESS * calm)
        DanTraits_StatAdd(stats, CharacterStat.PANIC, -SB.SW_PANIC * calm)
    end
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
        local res = { pcall(original, playerObj, ...) }
        mood.BOREDOM_PER_SECOND, mood.UNHAPPINESS_PER_SECOND = b, u
        if not res[1] then error(res[2], 0) end
        return unpack(res, 2)
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

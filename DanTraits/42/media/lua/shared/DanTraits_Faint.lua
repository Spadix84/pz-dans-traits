-- Project Zomboid Vitality Project: passing out (health overhaul). Used by
-- shock (DanTraits_Blood.lua), concussion (DanTraits_Concussion.lua) and
-- Fear of Blood.
--
-- Passing out: the fall, then sitting on the floor, the screen faded to
-- black, movement, attacks and shoves blocked, until the time is up; then
-- the screen comes back and "You come round". The time is game minutes
-- (so it follows the day length and stops while paused), but never under
-- FT_MIN_REAL_S real seconds, so a short faint is felt.
--
-- Tried in play (2026-09-28):
--   the fall: the game's shove-fall (setBumpType "stagger" and the BumpFall
--     variables, as its debug stagger does) drops the character.
--   holding them down with setBlockMovement alone does not: they get
--     straight back up from the fall.
--   sleep does take control away, but in single player, while every player
--     is asleep, time runs at a flat 200x (GameTime.getUnmoddedMultiplier),
--     and the character stays standing.
--   the sit-on-the-ground state (EventSitOnGround, which only a movement key
--     normally ends) holds, with movement blocked, in real time. Chosen.
--   the knocked-down state (setKnockedDown) ended up the same, sitting.
--
-- In a vehicle there is no fall and no sitting on the floor (the seat holds
-- you); the screen goes black and the controls are dead just the same, and
-- a driver's engine cuts out, so the car rolls to a stop instead of driving
-- on. Not yet tried in play.
--
-- A faint is shallow: a new wound (a bite, a scratch, a cut: a zombie
-- getting to you) brings you round at once. A knockout (concussion) is not:
-- you stay down whatever happens.
--
--   DanTraits_PassOut(player, minutes, textKey, deep)   pass out for game minutes;
--                                                  deep: an attack doesn't wake you
--   DanTraits_Collapse(player)                    just the fall
--   DanTraits_IsPassedOut(player)
-- Console: faint fall | faint out [game minutes]
require "DanTraits"

local notify = DanTraits_Notify

local FT_MIN_REAL_S   = 8       -- never out for less than this, in real seconds
local FT_SETTLE_MS    = 1500    -- let the fall play out before sitting down
local FT_FALL_WOUND_MS = 4000   -- a scratch from the fall itself does not wake you (found in game: every diabetic blackout ended at once)

function DanTraits_Collapse(player)
    if not player or player:isDead() then return false end
    local front = true
    if ZombRand then front = ZombRand(2) == 0 end
    return pcall(function()
        player:setBumpType("stagger")
        player:setVariable("BumpDone", false)
        player:setVariable("BumpFall", true)
        player:setVariable("BumpFallType", front and "pushedFront" or "pushedBehind")
    end)
end

-- the one who is out: { player, startMs, untilMs, untilHours, textKey, deep, wounds }
local hold = nil
local FT_CHECK_TICKS = 10      -- look for new wounds this often

-- open wounds, counted: a new one means something got to you
local function woundCount(player)
    local n = 0
    pcall(function()
        local parts = player:getBodyDamage():getBodyParts()
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            if part:getScratchTime() > 0 then n = n + 1 end
            if part:getCutTime() > 0 then n = n + 1 end
            if part:getBiteTime() > 0 then n = n + 1 end
            if part:getDeepWoundTime() > 0 then n = n + 1 end
        end
    end)
    return n
end

local function worldHours()
    local h = 0
    pcall(function() h = GameTime.getInstance():getWorldAgeHours() end)
    return h
end

local function setBlocked(player, blocked)
    pcall(function() player:setBlockMovement(blocked) end)
    pcall(function() player:setIgnoreMovement(blocked) end)
    pcall(function() player:setAuthorizeMeleeAction(not blocked) end)
    pcall(function() player:setAuthorizeShoveStomp(not blocked) end)
end

local function fade(player, out)
    pcall(function()
        if out then UIManager.FadeOut(player:getPlayerNum(), 1) else UIManager.FadeIn(player:getPlayerNum(), 1) end
    end)
end

local function comeRound(say)
    if not hold then return end
    local player, key = hold.player, hold.textKey
    setBlocked(player, false)
    fade(player, false)
    hold = nil
    if say and not player:isDead() then notify(player, key) end
end

function DanTraits_IsPassedOut(player)
    return hold ~= nil and hold.player == player
end

local function vehicleOf(player)
    local v = nil
    pcall(function() v = player:getVehicle() end)
    return v
end

-- the driver goes out: cut the engine (the game's own shut-off command,
-- the direct call if that is not there)
local function stopCar(player, car)
    local driving = false
    pcall(function() driving = car:getDriver() == player end)
    if not driving then return end
    local ok = pcall(function() sendClientCommand(player, "vehicle", "shutOff", {}) end)
    if not ok then pcall(function() car:shutOff() end) end
end

function DanTraits_PassOut(player, minutes, textKey, deep)
    if not player or player:isDead() or hold then return false end
    local car = vehicleOf(player)
    if car then stopCar(player, car) else DanTraits_Collapse(player) end
    local now = getTimestampMs()
    hold = { player = player, startMs = now, untilMs = now + FT_MIN_REAL_S * 1000,
             untilHours = worldHours() + (minutes or 5) / 60, textKey = textKey or "UI_DanTraits_ComeTo",
             deep = deep == true, wounds = woundCount(player), ticks = 0 }
    setBlocked(player, true)
    fade(player, true)
    return true
end

local function onFaintTick()
    if not hold then return end
    local player = hold.player
    if player:isDead() then comeRound(false) return end
    local now = getTimestampMs()
    if now >= hold.untilMs and worldHours() >= hold.untilHours then
        comeRound(true)
        return
    end
    hold.ticks = hold.ticks + 1
    if not hold.deep and hold.ticks % FT_CHECK_TICKS == 0 then
        local n = woundCount(player)
        if now - hold.startMs < FT_FALL_WOUND_MS then
            n = math.max(n, hold.wounds)   -- still landing: what the fall did counts as already there
        elseif n > hold.wounds then
            hold.textKey = "UI_DanTraits_JoltedAwake"
            comeRound(true)
            return
        end
        hold.wounds = n
    end
    setBlocked(player, true)
    if vehicleOf(player) then return end   -- the seat holds you
    if now - hold.startMs >= FT_SETTLE_MS then
        local sitting = false
        pcall(function() sitting = player:isSitOnGround() end)
        if not sitting then pcall(function() player:reportEvent("EventSitOnGround") end) end
    end
end
DanTraits_FaintTick = onFaintTick

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.faint = function(player, args)
    if args[1] == "fall" then return "collapsed: " .. tostring(DanTraits_Collapse(player)) end
    if args[1] == "out" then
        local minutes = tonumber(args[2]) or 5
        return "out for " .. tostring(minutes) .. " game minutes: " .. tostring(DanTraits_PassOut(player, minutes))
    end
    return "faint fall | faint out [game minutes]"
end

Events.OnTick.Add(onFaintTick)

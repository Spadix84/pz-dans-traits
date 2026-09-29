-- Project Zomboid Vitality Project: Hallucinations (trait id "schizophrenia").
require "DanTraits"

local hasTrait = DanTraits_HasTrait

-- Schizophrenia -------------------------------------------------------------
-- Episodes roll every ten minutes. The base chance never goes away; stress,
-- unhappiness, tiredness and night all push it up. Three kinds of episode:
-- a phantom zombie sound nearby, a door or window shaking as if thumped, or a
-- sudden bout of panic with the startle sting. Sounds are audio only: they do
-- not attract real zombies.
local SCHIZO_BASE_CHANCE     = 0.12   -- per 10 minutes, floor
local SCHIZO_STRESS_WEIGHT   = 0.30   -- times stress (0..1)
local SCHIZO_UNHAPPY_WEIGHT  = 0.20   -- times unhappiness/100
local SCHIZO_FATIGUE_WEIGHT  = 0.20   -- times fatigue (0..1)
local SCHIZO_NIGHT_BONUS     = 0.08
local SCHIZO_COOLDOWN_TICKS  = 0      -- ten-minute ticks to skip after an episode (0 = can fire every tick)
local SCHIZO_SOUND_PANIC     = 8      -- panic added by a phantom sound or thump (0..100)
local SCHIZO_BOUT_PANIC_MIN  = 35     -- panic bout adds this plus up to 20 more
local SCHIZO_THUMP_RADIUS    = 7      -- tiles to search for a door or window
-- TESTING: set the default below to true and every 10-minute tick fires a phantom charge
-- (the offline tests define DanTraitsTestCharge = false to keep the normal roll).
local SCHIZO_TEST_CHARGE     = (DanTraitsTestCharge == nil) and false or DanTraitsTestCharge
local SCHIZO_CHARGE_PANIC    = 15     -- panic added by a phantom zombie charge
local CHARGE_DIST_MIN, CHARGE_DIST_MAX = 4, 7   -- tiles ahead of the player where the phantom appears
local CHARGE_MAX_FRAMES      = 240    -- give up after about 4 s
local CHARGE_FADE_AT         = 4.0    -- tiles from the player: start fading out
local CHARGE_GONE_AT         = 1.6    -- tiles from the player: gone, just outside a zombie's attack reach
local CHARGE_FADE_FRAMES     = 30     -- about half a second
local CHARGE_REPATH_FRAMES   = 10     -- re-aim at the player's current square this often

local PHANTOM_SOUNDS = {
    "MaleZombieVoiceA", "MaleZombieVoiceB", "MaleZombieVoiceC",
    "FemaleZombieVoiceA", "FemaleZombieVoiceB", "FemaleZombieVoiceC",
    "ZombieScratch",
}
-- Whispers: the game's own whispered "psst" and "hey" (used for the whisper
-- shout), plus muffled radio chatter pitched down and turned right down,
-- which reads as voices through a wall. The chatter is a loop, so it is cut
-- after a few seconds.
local WHISPER_SOUNDS = {
    "VoiceMaleWhisperPsst", "VoiceMaleWhisperHey",
    "VoiceFemaleWhisperPsst", "VoiceFemaleWhisperHey",
}
-- Footsteps use the game's combined footstep event and pick the surface
-- through its FMOD parameters (values are the game's own enum order).
local FOOTSTEP_SOUNDS = { "HumanFootstepsCombined", "HumanFootstepsCombined", "ZombieFootstepsCombined" }
local FOOTSTEP_MATERIAL = { Upstairs = 0, Concrete = 2, Grass = 3, Gravel = 4, Puddle = 5, Wood = 7 }
local FOOTSTEP_INDOOR   = { "Upstairs", "Upstairs", "Wood", "Puddle" }
local FOOTSTEP_OUTDOOR  = { "Puddle", "Puddle", "Grass", "Gravel", "Concrete" }
local FOOTSTEP_STEPS_MIN, FOOTSTEP_STEPS_SPREAD = 3, 4      -- 3 to 6 steps
local FOOTSTEP_GAP_MIN, FOOTSTEP_GAP_SPREAD   = 22, 10     -- frames between steps
local GLASS_SOUND       = "SmashWindow"
local GLASS_PANIC       = 15
local MUTTER_SOUND        = "RadioTalk"
local MUTTER_VOLUME       = 0.25
local MUTTER_PITCH        = 0.7
local MUTTER_FRAMES_MIN   = 150     -- about 2.5 s at 60 fps
local MUTTER_FRAMES_SPREAD = 150

-- The frame scheduler (a thump is a burst of two to four hits) is
-- DanTraits_Later in the core file.
local schizoLater = DanTraits_Later
local phantomsOnTick   -- defined with the phantom zombie episode below
local function schizoOnTick()
    if phantomsOnTick then phantomsOnTick() end
end

local function playSoundAt(name, x, y, z)
    local emitter, handle
    local ok = pcall(function()
        emitter = getWorld():getFreeEmitter(x, y, z)
        handle = emitter:playSound(name)
    end)
    if not ok then
        emitter, handle = nil, nil
        pcall(function()
            emitter = getWorld():getFreeEmitter()
            emitter:setPos(x, y, z)
            handle = emitter:playSound(name)
        end)
    end
    return emitter, handle
end

-- A point a few tiles from the player in a random direction.
local function offsetFromPlayer(player, minDist, spread)
    local angle = ZombRand(360) * math.pi / 180
    local distance = minDist + ZombRand(spread + 1)
    return player:getX() + math.cos(angle) * distance, player:getY() + math.sin(angle) * distance, player:getZ()
end

local function addPanic(player, amount)
    local stats = player:getStats()
    pcall(function()
        stats:set(CharacterStat.PANIC, math.min(100, stats:get(CharacterStat.PANIC) + amount))
    end)
end

local function isNight()
    local ok, hour = pcall(function() return getGameTime():getHour() end)
    return ok and (hour >= 22 or hour < 6)
end

-- Doors and windows around the player, including player-built doors.
local function nearbyThumpables(player)
    local found = {}
    local px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    local cell = getCell()
    for dx = -SCHIZO_THUMP_RADIUS, SCHIZO_THUMP_RADIUS do
        for dy = -SCHIZO_THUMP_RADIUS, SCHIZO_THUMP_RADIUS do
            local sq = cell:getGridSquare(px + dx, py + dy, pz)
            local objects = sq and sq:getObjects()
            if objects then
                for i = 0, objects:size() - 1 do
                    local obj = objects:get(i)
                    if instanceof(obj, "IsoWindow") then
                        found[#found + 1] = { obj = obj, sound = "ZombieThumpWindow", extra = "WindowRattle" }
                    elseif instanceof(obj, "IsoDoor") or (instanceof(obj, "IsoThumpable") and obj:isDoor()) then
                        found[#found + 1] = { obj = obj, sound = "ZombieThumpWood" }
                    end
                end
            end
        end
    end
    return found
end

local function episodePhantomSound(player)
    local x, y, z = offsetFromPlayer(player, 6, 8)
    playSoundAt(PHANTOM_SOUNDS[ZombRand(#PHANTOM_SOUNDS) + 1], x, y, z)
    addPanic(player, SCHIZO_SOUND_PANIC)
end

local function episodeWhisper(player)
    if ZombRand(100) < 60 then
        -- a whispered word from just behind you
        local x, y, z = offsetFromPlayer(player, 2, 3)
        playSoundAt(WHISPER_SOUNDS[ZombRand(#WHISPER_SOUNDS) + 1], x, y, z)
    else
        -- muttering through the wall
        local x, y, z = offsetFromPlayer(player, 5, 4)
        local emitter, handle = playSoundAt(MUTTER_SOUND, x, y, z)
        if emitter and handle then
            pcall(function()
                emitter:setVolume(handle, MUTTER_VOLUME)
                emitter:setPitch(handle, MUTTER_PITCH)
            end)
            schizoLater(MUTTER_FRAMES_MIN + ZombRand(MUTTER_FRAMES_SPREAD + 1), function()
                pcall(function() emitter:stopSound(handle) end)
            end)
        end
    end
    addPanic(player, SCHIZO_SOUND_PANIC)
end

-- The door wobble is RenderEffectType.Hit_Door, an enum the game does not
-- expose to Lua, and reflection is debug-mode only. The one public route to
-- it is the door's own toggle: a closed door whose plain "locked" flag is set
-- rattles (locked-door sound plus the wobble) and returns without opening.
-- So: set the flag, toggle, restore the flag. Doors already locked by key,
-- barricaded doors, open doors, and doors the player has the key for are
-- skipped, because the toggle would unlock or open those instead.
-- Doors only rattle when the player is outdoors: from inside, the game lets
-- the player through a locked door, so the toggle opens it. Windows have
-- no wobble at all. Anything skipped is sound only. Returns "opened" if the
-- door opened anyway (it is shut again), so the caller stops rattling it.
local function rattleDoor(obj, player)
    if RenderEffectType and RenderEffectType.Hit_Door then
        local ok = pcall(function() obj:setRenderEffect(RenderEffectType.Hit_Door, true) end)
        if ok then return true end
    end

    local isDoor = instanceof(obj, "IsoDoor")
    local isBuilt = (not isDoor) and instanceof(obj, "IsoThumpable")
    if not isDoor and not isBuilt then return false end
    if obj:isOpen() or obj:isBarricaded() or obj:isLockedByKey() then return false end
    if not player:isOutside() then return false end

    local hasKey = false
    pcall(function() hasKey = player:getInventory():haveThisKeyId(obj:getKeyId()) ~= nil end)
    if hasKey then return false end

    local wasLocked = obj:isLocked()
    local ok = pcall(function()
        if isDoor then obj:setLocked(true) else obj:setIsLocked(true) end
        obj:ToggleDoorActual(player)
    end)
    pcall(function()
        if isDoor then obj:setLocked(wasLocked) else obj:setIsLocked(wasLocked) end
        obj:setLockedByKey(false)
    end)
    if obj:isOpen() then
        -- should be impossible given the checks above; put it back regardless
        pcall(function() obj:ToggleDoorActual(player) end)
        return "opened"
    end
    return ok
end

local function episodeThump(player)
    local targets = nearbyThumpables(player)
    if #targets == 0 then
        return false
    end
    local target = targets[ZombRand(#targets) + 1]
    local obj, sound, extra = target.obj, target.sound, target.extra
    local hits = 2 + ZombRand(3)
    local canRattle = true
    local function thump()
        if canRattle and rattleDoor(obj, player) == "opened" then canRattle = false end
        pcall(function() playSoundAt(sound, obj:getX(), obj:getY(), obj:getZ()) end)
        if extra then pcall(function() playSoundAt(extra, obj:getX(), obj:getY(), obj:getZ()) end) end
    end
    thump()
    for n = 1, hits - 1 do
        schizoLater(n * (35 + ZombRand(15)), thump)
    end
    addPanic(player, SCHIZO_SOUND_PANIC)
    return true
end

local function episodeGlass(player)
    local x, y, z = offsetFromPlayer(player, 5, 6)
    playSoundAt(GLASS_SOUND, x, y, z)
    addPanic(player, GLASS_PANIC)
end

local function episodeFootsteps(player)
    local materials = player:isOutside() and FOOTSTEP_OUTDOOR or FOOTSTEP_INDOOR
    local material = FOOTSTEP_MATERIAL[materials[ZombRand(#materials) + 1]] or 0
    local sound = FOOTSTEP_SOUNDS[ZombRand(#FOOTSTEP_SOUNDS) + 1]
    local shoe = 1 + ZombRand(5)                -- boots .. sneakers, never barefoot
    local steps = FOOTSTEP_STEPS_MIN + ZombRand(FOOTSTEP_STEPS_SPREAD)

    -- start a few tiles out and drift one tile per step in a random direction
    local x, y, z = offsetFromPlayer(player, 4, 5)
    local heading = ZombRand(360) * math.pi / 180
    local dx, dy = math.cos(heading), math.sin(heading)

    local function step(n)
        local emitter, handle = playSoundAt(sound, x + dx * n, y + dy * n, z)
        if emitter and handle then
            pcall(function()
                emitter:setParameterValueByName(handle, "FootstepMaterial", material)
                emitter:setParameterValueByName(handle, "ShoeType", shoe)
            end)
        end
    end
    step(0)
    local delay = 0
    for n = 1, steps - 1 do
        delay = delay + FOOTSTEP_GAP_MIN + ZombRand(FOOTSTEP_GAP_SPREAD + 1)
        local at = n
        schizoLater(delay, function() step(at) end)
    end
    addPanic(player, SCHIZO_SOUND_PANIC)
end

local function episodePanicBout(player)
    pcall(function() player:getEmitter():playSound("ZombieSurprisedPlayer") end)
    addPanic(player, SCHIZO_BOUT_PANIC_MIN + ZombRand(21))
end

-- Phantom zombie: a real zombie, spawned in view a few tiles ahead and run
-- straight at the player's square, then faded and removed on arrival.
-- It is marked "useless" (what the vanilla tutorial does to its scripted
-- zombies): it cannot acquire a target by sight or sound, and it is never
-- given one (any target the game hands it on sight is cleared every frame),
-- so it never attacks; it only paths to where the player is. It is
-- non-solid, so it does not bump anyone. If the player swings at it, or an
-- attack ever starts, it vanishes on the spot. (Do not flag it
-- "reanimated for grapple only": that stops attacks too, but the on-ground
-- state turns such a zombie into a real corpse the moment it drops.) The
-- game re-lerps zombie alpha every logic update, so the fade is re-applied on
-- the render tick as well. Single player only.
local schizoPhantoms = {}

local function chargeSpawnSquare(player)
    local found
    pcall(function()
        local dir = player:getForwardDirection()
        local dx, dy = dir:getX(), dir:getY()
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 0.01 then return end
        dx, dy = dx / len, dy / len
        local px, py, pz = player:getX(), player:getY(), math.floor(player:getZ())
        local here = player:getCurrentSquare()
        local outside = here and here:isOutside()
        local cell = getCell()
        for dist = CHARGE_DIST_MAX, CHARGE_DIST_MIN, -1 do
            local sq = cell:getGridSquare(math.floor(px + dx * dist), math.floor(py + dy * dist), pz)
            if sq and sq:isFree(false) and sq:isCanSee(player:getPlayerNum()) and (here == nil or sq:isOutside() == outside) then
                found = sq
                return
            end
        end
    end)
    return found
end

-- Removed zombies go into the game's reuse pool, and the pool does not reset
-- the flags below, so the next zombie it hands out (a real one, or our next
-- phantom) would come back useless, non-solid and at zero alpha. Put
-- everything back before letting go of it.
local function removePhantom(ph)
    local z = ph.zombie
    pcall(function() z:setUseless(false) end)
    pcall(function() z:setCollidable(true) end)
    pcall(function() z:setSolid(true) end)
    pcall(function() z:setInvincible(false) end)
    pcall(function() z:setAvoidDamage(false) end)
    pcall(function() z:setNoTeeth(false) end)
    pcall(function()
        z:setAlpha(ph.playerNum, 1)
        z:setTargetAlpha(ph.playerNum, 1)
    end)
    ph.alpha = nil
    pcall(function() z:removeFromWorld() end)
    pcall(function() z:removeFromSquare() end)
end

local function phantomRunAt(ph)
    pcall(function() ph.zombie:pathToLocationF(ph.player:getX(), ph.player:getY(), ph.player:getZ()) end)
end

local function phantomApplyAlpha(ph)
    if ph.alpha == nil then return end
    pcall(function()
        ph.zombie:setAlpha(ph.playerNum, ph.alpha)
        ph.zombie:setTargetAlpha(ph.playerNum, ph.alpha)
    end)
end

phantomsOnTick = function()
    for i = #schizoPhantoms, 1, -1 do
        local ph = schizoPhantoms[i]
        ph.frames = ph.frames + 1
        local ok, dist = pcall(function() return ph.zombie:DistTo(ph.player) end)
        if not ok or dist == nil then dist = 0 end
        -- the game hands even a "useless" zombie a target when it sees the
        -- player (it just does nothing else with it), so drop it every frame
        -- and only bail if an attack actually begins
        pcall(function() if ph.zombie:getTarget() ~= nil then ph.zombie:setTarget(nil) end end)
        -- (player:isAttacking() is "attack type is set", which stays true
        -- long after a swing; the animation flag is only up during one)
        local abort = false
        pcall(function()
            abort = ph.zombie:isAttacking() or ph.player:isPerformingAttackAnimation()
        end)
        local gone = abort or dist <= CHARGE_GONE_AT or ph.frames >= CHARGE_MAX_FRAMES
        if not gone and (ph.fade or dist <= CHARGE_FADE_AT or ph.frames >= CHARGE_MAX_FRAMES - CHARGE_FADE_FRAMES) then
            ph.fade = (ph.fade or CHARGE_FADE_FRAMES) - 1
            ph.alpha = math.max(0, ph.fade / CHARGE_FADE_FRAMES)
            phantomApplyAlpha(ph)
            if ph.fade <= 0 then gone = true end
        end
        if gone then
            removePhantom(ph)
            table.remove(schizoPhantoms, i)
        elseif ph.frames % CHARGE_REPATH_FRAMES == 0 then
            phantomRunAt(ph)
        end
    end
end

local function phantomsOnRender()
    for _, ph in ipairs(schizoPhantoms) do phantomApplyAlpha(ph) end
end
Events.OnRenderTick.Add(phantomsOnRender)

local function episodeCharge(player)
    if isClient() or isServer() then return false end
    local sq = chargeSpawnSquare(player)
    if not sq then return false end
    local zombie
    pcall(function()
        local x, y, z = sq:getX(), sq:getY(), sq:getZ()
        local list
        -- long form: crawler, fallOnFront, fakeDead, knockedDown, invulnerable, sitting, health
        local okLong = pcall(function()
            list = addZombiesInOutfit(x, y, z, 1, nil, 50, false, false, false, false, true, false, 1.0)
        end)
        if not okLong or not list then list = addZombiesInOutfit(x, y, z, 1, nil, 50) end
        if list and list:size() > 0 then zombie = list:get(0) end
    end)
    if not zombie then return false end
    pcall(function() zombie:setUseless(true) end)
    pcall(function() zombie:setCollidable(false) end)
    pcall(function() zombie:setSolid(false) end)
    pcall(function() zombie:setInvincible(true) end)
    pcall(function() zombie:setAvoidDamage(true) end)
    pcall(function() zombie:setNoTeeth(true) end)
    pcall(function() zombie:setWalkType("sprint" .. (1 + ZombRand(3))) end)
    pcall(function() zombie:setSpeedTypeFromWalkType() end)
    pcall(function() zombie:faceThisObject(player) end)
    pcall(function() zombie:playSound(PHANTOM_SOUNDS[ZombRand(6) + 1]) end)
    local ph = { zombie = zombie, player = player, playerNum = player:getPlayerNum(), frames = 0 }
    phantomRunAt(ph)
    schizoPhantoms[#schizoPhantoms + 1] = ph
    addPanic(player, SCHIZO_CHARGE_PANIC)
    return true
end
DanTraits_episodeCharge = episodeCharge
-- every episode by name, for the dashboard's command channel
DanTraits_Episodes = {
    charge = episodeCharge, sound = episodePhantomSound, whisper = episodeWhisper, thump = episodeThump,
    glass = episodeGlass, footsteps = episodeFootsteps, panic = episodePanicBout,
}

local function schizoChance(player)
    local stats = player:getStats()
    local chance = SCHIZO_BASE_CHANCE
        + stats:get(CharacterStat.STRESS) * SCHIZO_STRESS_WEIGHT
        + (stats:get(CharacterStat.UNHAPPINESS) / 100) * SCHIZO_UNHAPPY_WEIGHT
        + stats:get(CharacterStat.FATIGUE) * SCHIZO_FATIGUE_WEIGHT
    if isNight() then chance = chance + SCHIZO_NIGHT_BONUS end
    return chance
end

local function updateSchizophrenia(player, d)
    if not hasTrait(player, "schizophrenia") then return end
    if DanTraits_Asleep(player) then return end

    if (d.schizoCooldown or 0) > 0 then
        d.schizoCooldown = d.schizoCooldown - 1
        return
    end

    if SCHIZO_TEST_CHARGE then
        if not episodeCharge(player) then episodePhantomSound(player) end
        return
    end

    if ZombRand(1000) >= schizoChance(player) * 1000 then return end
    d.schizoCooldown = SCHIZO_COOLDOWN_TICKS

    local roll = ZombRand(100)
    if roll < 15 then
        episodePanicBout(player)
    elseif roll < 40 then
        if not episodeThump(player) then episodePhantomSound(player) end
    elseif roll < 60 then
        episodeWhisper(player)
    elseif roll < 70 then
        episodeGlass(player)
    elseif roll < 85 then
        episodeFootsteps(player)
    elseif roll < 95 then
        if not episodeCharge(player) then episodePhantomSound(player) end
    else
        episodePhantomSound(player)
    end
end

Events.OnTick.Add(schizoOnTick)

-- exposed for the ten-minute driver in the core file
DanTraits_updateSchizophrenia = updateSchizophrenia

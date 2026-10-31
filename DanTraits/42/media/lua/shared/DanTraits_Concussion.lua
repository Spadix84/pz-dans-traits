-- Project Zomboid Vitality Project: concussion (health overhaul, phase 5).
--
-- Not a trait: every character has it. A hard knock to the head leaves a
-- concussion, a score (ccScore, 0..1) that sets how bad it is:
--   mild      (under CC_MODERATE) a headache, drowsy
--   moderate  sick to the stomach too, light hurts, slow to get your breath
--             back (the enduranceRegen hook of the stat delta pipeline), and running can bring on a dizzy spell (a fall)
--   severe    (CC_SEVERE and over) all of it worse; the blow itself knocks
--             you out for 5 to 15 game minutes (DanTraits_Faint.lua)
-- Rest heals it, sleep twice as fast; running, sprinting and fighting
-- stop it healing and make it a little worse. Screen time (a handheld
-- console, DanTraits_SpiffBoy.lua's DanTraits_ScreenTime) heals it at
-- CC_SCREEN_HEAL and, moderate and worse or in the headache that comes back,
-- adds CC_SCREEN_PAIN. A second knock while still
-- concussed lands on top of the first. It brings on migraine attacks
-- (Migraines) and makes light wake you more easily (sleep and light).
--
-- The headache that comes back: a concussion may (CC_LATE_CHANCE, likelier
-- the worse it was) leave a post-concussion headache one to two and a half
-- days later, often after the concussion itself has cleared. It builds over
-- six hours to a pain worse than the knock's own (CC_LATE_PAIN), holds,
-- fades over its last twelve hours, and lasts one to two days by how bad
-- the concussion was; sleep gets through it half as fast again, bright
-- daylight makes it worse, painkillers dull it as they do any pain. The
-- Concussion moodle shows Dazed while it lasts.
--
-- Mod data: ccScore, ccTier, ccLastImpact; ccLate = { wait = hours to go,
-- s } before the headache, { left, total, s, screen } while it lasts;
-- ccScreen (a screen is hurting: told once until it stops).
--
-- What counts as a knock (the game's own damage reports, OnPlayerGetDamage):
--   FALLDOWN       a fall: the amount is the health it cost (vanilla
--                  IsoGameCharacter.handleLandingImpact; 1000 for a lethal
--                  one). The last one is kept in ccLastImpact.
--   CARCRASHDAMAGE, CARHITDAMAGE   a car crash, being hit by a car: on the
--                  crash's own scale (BaseVehicle.addRandomDamageFromCrash:
--                  up to 40 one body part hurt for 5 up to the amount; 40+ a
--                  chance of a deep wound, 50+ a break; over 70 two or three
--                  parts). A crash in a car is judged by the speed the car
--                  lost (CC_CRASH_KMH): its top speed in the second before,
--                  less the lowest it reads in the moment after (the report
--                  comes mid-impact, so the knock waits CC_SPEED_AFTER_MS for
--                  that). The game's amount levels off, 42 at 49 km/h and 47
--                  at 71 (measured in play), so it cannot tell a hard crash
--                  from a very hard one; and it reports a zombie run down at
--                  60 km/h, or a worn suspension clipping a corpse, as a
--                  crash too, though the car barely slows. If the speed after
--                  cannot be read (thrown clear, the car gone) the top speed
--                  alone decides. Being hit by a car on foot has no speed to
--                  read and uses the amount.
--   WEAPONHIT      a weapon hit (other players, or mods that add them) that
--                  took health off the head. The game sends it only from
--                  IsoGameCharacter.Hit; NPC mods that hurt the player
--                  another way report through DanTraits_OtherHit instead
--                  (DanTraits_ALife.lua, DanTraits_Bandits.lua).
-- A helmet (the head's clothing defense, CC_HELMET or more) makes a
-- concussion less likely and less bad.
--
-- Hooks offered: concussionHeal (the score healed a minute, player, d);
-- Vitality speeds it up or slows it. concussionChance and concussionScore
-- (a knock's chance and how bad, player), before a helmet's cut; Thick
-- Skull lowers both. impact (nil, player, chance 0..1, amount, kind): every
-- fall, crash and car hit, with the chance this scale gives it of a
-- concussion, before any roll, Concussion on or off; Brittle rolls a
-- fracture on it.
require "DanTraits"

local notify = DanTraits_Notify
local notifyGood = DanTraits_NotifyGood
local traitData = DanTraits_Data

-- falls and crashes each on their own scale: { no concussion under, certain from, how bad per point over }
local CC_FALL          = { 3, 15, 0.04 }   -- in play a second-floor drop costs about 5, a third-floor
                                           -- one about 7: the rest of a fall goes to the legs
local CC_CRASH         = { 25, 70, 0.012 } -- a bump into a sign ~20: nothing; 40 (a wounding crash)
                                           -- a third of a chance, moderate; 70 certain, severe
local CC_CRASH_KMH     = { 25, 70, 0.01 }  -- in a car, by speed lost: under 25 km/h nothing; 50 about half
                                           -- a chance, moderate; 70 certain, severe
local CC_SPEED_WINDOW_MS = 1000  -- the top speed is taken over this much of the drive before the crash
local CC_SPEED_AFTER_MS  = 250   -- ...and the speed after over this much (or CC_SPEED_AFTER_FRAMES frames) following it
local CC_SPEED_AFTER_FRAMES = 30
local CC_BASE          = 0.25    -- how bad at the least, plus the scale's per point
local CC_HEAD_SURE     = 20      -- a weapon taking this much off the head: certain
local CC_HEAD_PER      = 0.025   -- how bad per point off the head, over CC_BASE
local CC_HELMET        = 50      -- head clothing defense counted as a helmet
local CC_HELMET_CHANCE = 0.4     -- x chance with a helmet
local CC_HELMET_SCORE  = 0.6     -- x how bad with a helmet
local CC_STACK         = 0.5     -- a second knock adds this x the smaller of the two
local CC_MODERATE      = 0.4
local CC_SEVERE        = 0.7
local CC_KO_MIN        = { 5, 15 }   -- severe: minutes out cold, from CC_SEVERE to 1
local CC_KO_MODERATE   = 0.25    -- moderate: chance of a brief blackout...
local CC_KO_BRIEF      = { 1, 3 }    -- ...this many minutes
local CC_HEAL_DAY      = 0.25    -- score healed a game day awake at rest
local CC_HEAL_ASLEEP   = 2       -- x asleep
local CC_STRAIN        = 0.0005  -- score added a minute running, sprinting or fighting
local CC_PAIN          = { 15, 35 }  -- head pain floor: this, plus this x score
local CC_LIGHT_PAIN    = 10      -- more in bright daylight (moderate and worse)
local CC_SCREEN_HEAL   = 0.5     -- healing x this a minute of screen time
local CC_SCREEN_PAIN   = 5       -- head pain a screen adds (moderate and worse, and the headache that comes back)
local CC_SICK          = 0.3     -- food sickness floor x score (moderate and worse)
local CC_FATIGUE       = 0.0003  -- tiredness a minute awake x score
local CC_ENDURANCE     = 0.3     -- endurance recovery x (1 - this x score)
local CC_DIZZY         = 0.18    -- chance a minute of running or fighting of a dizzy fall x score (moderate and worse)
local CC_WAKE          = 1       -- light wakes you (1 + this x score) times as easily
local CC_TIER          = { 0.02, CC_MODERATE, CC_SEVERE }
-- the headache that comes back
local CC_LATE_CHANCE   = { 0.5, 0.5 }   -- chance: this, plus this x how bad the concussion was
local CC_LATE_WAIT     = { 24, 60 }     -- hours before it comes
local CC_LATE_HOURS    = { 24, 24 }     -- how long: this, plus this x how bad
local CC_LATE_PAIN     = { 20, 45 }     -- head pain floor at its worst: this, plus this x how bad
local CC_LATE_RISE_H   = 6              -- hours to build to its worst...
local CC_LATE_FADE_H   = 12             -- ...and to fade at the end
local CC_LATE_ASLEEP   = 1.5            -- x as fast asleep

local clamp01 = DanTraits_Clamp01

local function sandboxOn() return DanTraits_SandboxOn("ConcussionEnabled") end

local roll = DanTraits_Roll
local randRange = DanTraits_RandRange

-- 0..1, for other systems (Migraines, the health panel); 0 while the option is off
function DanTraits_ConcussionStrength(player)
    if not sandboxOn() then return 0 end
    local d = player and player:getModData().DanTraits
    return (d and d.ccScore) or 0
end

local function helmeted(player)
    local defense = 0
    pcall(function()
        defense = player:getBodyPartClothingDefense(BodyPartType.ToIndex(BodyPartType.Head), false, false) or 0
    end)
    return defense >= CC_HELMET
end

local function headPart(player) return DanTraits_PartOf(player, "head") end

-- a knock: chance 0..1 that it concusses, and how bad (0..1)
function DanTraits_KnockHead(player, chance, score)
    if not player or player:isDead() or not sandboxOn() then return 0 end
    chance = DanTraits_RunHooks("concussionChance", chance, player)
    score = DanTraits_RunHooks("concussionScore", score, player)
    if helmeted(player) then chance, score = chance * CC_HELMET_CHANCE, score * CC_HELMET_SCORE end
    if not roll(chance) then return 0 end
    local d = traitData(player)
    local old = d.ccScore or 0
    local new = clamp01(math.max(old, score) + CC_STACK * math.min(old, score))
    d.ccScore = new
    -- the headache that may come back days later (one at a time; a worse knock before it comes makes it worse)
    local late = d.ccLate
    if (not late or (late.wait and new > (late.s or 0))) and roll(CC_LATE_CHANCE[1] + CC_LATE_CHANCE[2] * new) then
        d.ccLate = { wait = (late and late.wait) or randRange(CC_LATE_WAIT[1], CC_LATE_WAIT[2]), s = new }
    end
    if score >= CC_SEVERE or (new >= CC_SEVERE and old > 0) then
        local t = clamp01((new - CC_SEVERE) / (1 - CC_SEVERE))
        if DanTraits_PassOut then DanTraits_PassOut(player, CC_KO_MIN[1] + (CC_KO_MIN[2] - CC_KO_MIN[1]) * t, "UI_DanTraits_ConcussionComeTo", true) end
    elseif new >= CC_MODERATE and roll(CC_KO_MODERATE) then
        if DanTraits_PassOut then DanTraits_PassOut(player, randRange(CC_KO_BRIEF[1], CC_KO_BRIEF[2]), "UI_DanTraits_ConcussionComeTo", true) end
    else
        notify(player, new >= CC_MODERATE and "UI_DanTraits_ConcussionModerate" or "UI_DanTraits_ConcussionMild")
    end
    return new
end

-- a weapon took this much off the head (CC_HEAD_SURE: certain); also how
-- another mod's NPC hit arrives (DanTraits_OtherHit)
function DanTraits_HeadHit(player, lost)
    if not DanTraits_IsLocalPlayer(player) then return 0 end
    lost = tonumber(lost) or 0
    if lost <= 0 then return 0 end
    return DanTraits_KnockHead(player, clamp01(lost / CC_HEAD_SURE), clamp01(CC_BASE + CC_HEAD_PER * lost))
end

-- a fall or crash of this amount, on its scale (CC_FALL, CC_CRASH, CC_CRASH_KMH).
-- Every impact first goes out on the "impact" hook (nil, player, chance 0..1,
-- amount, kind "fall" | "crash" | "hit") so other systems can judge the same
-- knock by the same scale: Brittle rolls a fracture on it. That runs with
-- Concussion off too; only the concussion itself is gated.
local function impactKnock(player, amount, scale, kind)
    scale = scale or CC_FALL
    if amount >= 1000 then return 0 end   -- a lethal fall is the game's business
    local chance = amount < scale[1] and 0 or clamp01((amount - scale[1]) / (scale[2] - scale[1]))
    DanTraits_RunHooks("impact", nil, player, chance, amount, kind or "fall")
    if chance <= 0 then return 0 end
    local score = clamp01(CC_BASE + scale[3] * (amount - scale[1]))
    return DanTraits_KnockHead(player, chance, score)
end

local function nowMs() return getTimestampMs and getTimestampMs() or 0 end

-- What the frame and event handlers remember between calls, per player
-- object (a weak-keyed table: a character that is gone takes its state with
-- it, so a multiplayer respawn or a second split-screen player never inherits
-- a crash or a head reading that was somebody else's):
--   speedTop, speedTopMs  the car's top speed over about the last second (the crash itself slows it)
--   crash                 a crash waiting on the speed after it: { top, note, at, frames, low = the lowest read since }
--   headWas               the head's health last frame, for weapon hits
--   ran, fought           moved hard or swung since the minute last ran (strain)
--   moodleShown           whether the moodle was last set above nothing
local states = setmetatable({}, { __mode = "k" })
local function stateOf(player)
    local st = states[player]
    if not st then
        st = { speedTop = 0, speedTopMs = 0, ran = false, fought = false, moodleShown = false }
        states[player] = st
    end
    return st
end

-- the crash's knock, once the window after it closes: by the speed lost, or
-- by the top speed alone if nothing could be read after
local function judgeCrash(player)
    local st = stateOf(player)
    local c = st.crash
    st.crash = nil
    local d = traitData(player)
    if c.low then
        local lost = math.max(0, c.top - c.low)
        d.ccLastImpact = c.note .. " at " .. tostring(math.floor(c.top + 0.5)) .. " km/h, lost " .. tostring(math.floor(lost + 0.5))
        impactKnock(player, lost, CC_CRASH_KMH, "crash")
    else
        d.ccLastImpact = c.note .. " at " .. tostring(math.floor(c.top + 0.5)) .. " km/h"
        impactKnock(player, c.top, CC_CRASH_KMH, "crash")
    end
end

local function trackSpeed(player)
    local st = stateOf(player)
    if not st.inVehicle and not st.crash then return end   -- on foot with no crash pending: no game call this frame
    local kmh = nil
    local okV, v = pcall(player.getVehicle, player)
    if okV and v then
        local okS, s = pcall(v.getCurrentSpeedKmHour, v)
        kmh = math.abs(okS and tonumber(s) or 0)
    end
    local crash = st.crash
    if not crash and not kmh then return end   -- on foot with no crash pending: the usual frame, and nothing to read
    local now = nowMs()
    if crash then
        if kmh then crash.low = math.min(crash.low or kmh, kmh) end
        crash.frames = crash.frames + 1
        if now - crash.at >= CC_SPEED_AFTER_MS or crash.frames >= CC_SPEED_AFTER_FRAMES then judgeCrash(player) end
    end
    if not kmh then return end   -- on foot: nothing to track
    if kmh >= st.speedTop or now - st.speedTopMs > CC_SPEED_WINDOW_MS then st.speedTop, st.speedTopMs = kmh, now end
end
local function recentTopSpeed(player)
    local st = stateOf(player)
    if st.speedTopMs <= 0 or nowMs() - st.speedTopMs > CC_SPEED_WINDOW_MS * 1.5 then return nil end
    return st.speedTop
end

local function onConcussionDamage(character, damageType, amount)
    if not sandboxOn() and damageType == "WEAPONHIT" then return end   -- falls and crashes are still judged for the impact hook
    if not DanTraits_IsLocalPlayer(character) then return end
    local player = character
    amount = tonumber(amount) or 0
    local st = stateOf(player)
    if damageType == "FALLDOWN" or damageType == "CARCRASHDAMAGE" or damageType == "CARHITDAMAGE" then
        local note = damageType .. " " .. tostring(DanTraits_Round(amount))
        local top = damageType == "CARCRASHDAMAGE" and recentTopSpeed(player) or nil
        if top then
            -- judged once the speed after it is read (trackSpeed); a second report in that window joins the first
            if st.crash then st.crash.top = math.max(st.crash.top, top)
            else st.crash = { top = top, note = note, at = nowMs(), frames = 0 } end
            if DanTraits_FrameWake then DanTraits_FrameWake(player) end   -- the frames judge it (trackSpeed): into the frame set now
        else
            traitData(player).ccLastImpact = note
            if damageType == "FALLDOWN" then impactKnock(player, amount, CC_FALL, "fall")
            else impactKnock(player, amount, CC_CRASH, damageType == "CARHITDAMAGE" and "hit" or "crash") end
        end
    elseif damageType == "WEAPONHIT" then
        local head = headPart(player)
        local now = nil
        pcall(function() now = head:getHealth() end)
        if now and st.headWas and now < st.headWas then DanTraits_HeadHit(player, st.headWas - now) end
        if now then st.headWas = now end   -- the next hit is judged from here, not from the last quarter-second read
    end
end

-- per frame: the head's health (for the next weapon hit), whether the player ran
-- The head's health is read every CC_HEAD_EVERY frames (a quarter second at
-- 60 fps), not every frame: a weapon hit is judged against the last read, and
-- the read after a hit is the hit's own (onConcussionDamage). The strain of
-- running counts only with a concussion in progress, so the movement snapshot
-- is only asked for then.
local CC_HEAD_EVERY = 15
local function updateConcussionFrame(player, d)
    local st = stateOf(player)
    local tick = (st.headTick or 0) + 1
    if tick >= CC_HEAD_EVERY or st.headWas == nil then
        tick = 0
        local head = st.head   -- the part object lives as long as the character: looked up once (the state is per player object)
        if not head then head = headPart(player); st.head = head end
        if head then
            local ok, h = pcall(head.getHealth, head)
            if ok then st.headWas = h end
        end
    end
    st.headTick = tick
    if d and (d.ccScore or 0) > 0 then
        local f = DanTraits_Frame(player)   -- the frame's movement snapshot (DanTraits.lua)
        if f.sprinting or f.running then st.ran = true end
    end
end

-- slower endurance recovery, through the stat delta pipeline (DanTraits_Util.lua)
DanTraits_AddHook("enduranceRegen", function(delta, player, d)
    local s = d and d.ccScore or 0
    if s <= 0 or not sandboxOn() then return nil end
    return delta * (1 - CC_ENDURANCE * s)
end)

local function onConcussionSwing(character)
    if DanTraits_IsLocalPlayer(character) then stateOf(character).fought = true end
end

local function updateMoodle(player, s)
    stateOf(player).moodleShown = s > 0
    DanTraits_BadMoodle(player, "Concussion", s, CC_TIER)
end

local function inBright(player)
    return DanTraits_InBrightLight ~= nil and DanTraits_InBrightLight(player) == true
end

-- looking at a screen (a handheld console); told once a session when it hurts
local function onScreen(player)
    return DanTraits_ScreenTime ~= nil and DanTraits_ScreenTime(player) ~= nil
end
local function screenHurts(player, d, hurts)
    if hurts and not d.ccScreen then notify(player, "UI_DanTraits_ConcussionScreen") end
    d.ccScreen = hurts or nil
end

-- 0..1 where the headache that came back is in its course: building, at its worst, fading
local function lateShape(late)
    if not late or not late.left or not late.total then return 0 end
    local done = late.total - late.left
    return math.max(0, math.min(1, done / CC_LATE_RISE_H, late.left / CC_LATE_FADE_H))
end
-- 0..1 how bad it is right now (0 before it comes and after)
local function lateStrength(late)
    return lateShape(late) * (late and late.s or 0)
end
DanTraits_ConcussionLateStrength = function(player)
    if not sandboxOn() then return 0 end
    local d = player and player:getModData().DanTraits
    return lateStrength(d and d.ccLate)
end

-- the headache that comes back: count down to it, then run it; returns how bad it is now
local function updateLate(player, d, asleep)
    local late = d.ccLate
    if not late then return 0 end
    if late.wait then
        late.wait = late.wait - 1 / 60
        if late.wait > 0 then return 0 end
        local total = CC_LATE_HOURS[1] + CC_LATE_HOURS[2] * (late.s or 0)
        d.ccLate = { left = total, total = total, s = late.s }
        late = d.ccLate
        notify(player, "UI_DanTraits_ConcussionLate")
    end
    late.left = late.left - (asleep and CC_LATE_ASLEEP or 1) / 60
    if late.left <= 0 then
        d.ccLate = nil
        notifyGood(player, "UI_DanTraits_ConcussionLateEnd")
        return 0
    end
    local shape = lateShape(late)
    local pain = shape * (CC_LATE_PAIN[1] + CC_LATE_PAIN[2] * (late.s or 0))
    if inBright(player) then pain = pain + CC_LIGHT_PAIN * shape end
    if shape > 0 and onScreen(player) then
        pain = pain + CC_SCREEN_PAIN * shape
        late.screen = true
    else
        late.screen = nil
    end
    DanTraits_HeadPainAtLeast(player, pain)
    return shape * (late.s or 0)
end

-- switched off mid-game (sandbox, a server admin): stand down once, so the
-- tier and the moodle do not stay on (the strength getters above already
-- read 0, so Migraines, Epilepsy and Hallucinations stop feeling it). The
-- score and the headache to come are kept and it all resumes if it is
-- switched back on.
local function standDown(player, d)
    local st = stateOf(player)
    st.ran, st.fought, st.crash = false, false, nil
    if d and (d.ccTier or 0) > 0 then d.ccTier = 0 end
    if st.moodleShown then updateMoodle(player, 0) end
end

local function updateConcussionMinute(player, d)
    if not sandboxOn() then standDown(player, d) return end
    local st = stateOf(player)
    local strained = st.ran or st.fought
    st.ran, st.fought = false, false
    local lateNow = updateLate(player, d, DanTraits_Asleep(player))
    local s = d.ccScore or 0
    if s <= 0 then
        screenHurts(player, d, (d.ccLate and d.ccLate.screen) or false)
        if d.ccTier and d.ccTier > 0 then d.ccTier = 0 end
        updateMoodle(player, lateNow > 0 and CC_TIER[1] or 0)
        return
    end
    local asleep = DanTraits_Asleep(player)
    local screen = not asleep and onScreen(player)
    if strained then
        s = s + CC_STRAIN
    else
        local heal = CC_HEAL_DAY / 1440 * (asleep and CC_HEAL_ASLEEP or 1) * (screen and CC_SCREEN_HEAL or 1)
        s = s - DanTraits_RunHooks("concussionHeal", heal, player, d)
    end
    s = clamp01(s)
    if s < 0.005 then s = 0 end
    d.ccScore = s > 0 and s or nil
    local tier = DanTraits_TierOf(s, CC_TIER)
    if tier == 0 and (d.ccTier or 0) > 0 then notifyGood(player, "UI_DanTraits_ConcussionClear") end
    d.ccTier = tier
    updateMoodle(player, s)
    if s <= 0 then return end

    -- the headache
    local pain = CC_PAIN[1] + CC_PAIN[2] * s
    if s >= CC_MODERATE and inBright(player) then pain = pain + CC_LIGHT_PAIN end
    if s >= CC_MODERATE and screen then pain = pain + CC_SCREEN_PAIN end
    screenHurts(player, d, screen and (s >= CC_MODERATE or (d.ccLate and d.ccLate.screen)) or false)
    DanTraits_HeadPainAtLeast(player, pain)
    local stats = player:getStats()
    if s >= CC_MODERATE then
        -- straight to the floor (a ramp as wide as the stat), recorded as a mod floor
        local stat = CharacterStat.FOOD_SICKNESS
        local max = DanTraits_StatMax(stat)
        DanTraits_FloorUp(stats, stat, CC_SICK * s * max, max)
        if strained and not asleep and roll(CC_DIZZY * s) then
            if DanTraits_Collapse then DanTraits_Collapse(player) end
            notify(player, "UI_DanTraits_ConcussionDizzy")
        end
    end
    if not asleep then DanTraits_StatAdd(stats, CharacterStat.FATIGUE, CC_FATIGUE * s) end
end

-- light wakes a concussed sleeper more easily
DanTraits_AddHook("sleepWake", function(m, player)
    local s = DanTraits_ConcussionStrength(player)
    if s <= 0 then return nil end
    return m * (1 + CC_WAKE * s)
end)

-- console: concussion <score> | concussion fall <amount> | concussion clear
DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.concussion = function(player, args)
    local d = traitData(player)
    if args[1] == "clear" then d.ccScore, d.ccLate = nil, nil; return "concussion cleared" end
    if args[1] == "late" then
        local s = clamp01(tonumber(args[2]) or 0.5)
        d.ccLate = { wait = 1 / 60, s = s }
        return "the headache that comes back, strength " .. tostring(s) .. ", starts next minute"
    end
    if args[1] == "fall" then
        local amount = tonumber(args[2]) or 30
        return "a fall costing " .. tostring(amount) .. ": concussion " .. tostring(impactKnock(player, amount))
    end
    if args[1] == "crash" then
        local amount = tonumber(args[2]) or 40
        return "a crash of " .. tostring(amount) .. ": concussion " .. tostring(impactKnock(player, amount, CC_CRASH))
    end
    local s = tonumber(args[1])
    if not s then return "concussion <0..1> | concussion fall <amount> | concussion crash <amount> | concussion late [0..1] | concussion clear" end
    return "concussion " .. tostring(DanTraits_KnockHead(player, 1, clamp01(s)))
end

Events.OnPlayerGetDamage.Add(onConcussionDamage)
DanTraits_Every("minute", "Concussion", updateConcussionMinute, 24)
DanTraits_Every("frame", "Concussion", function(player, d)
    trackSpeed(player)   -- the crash speeds feed the impact hook even with Concussion off
    if sandboxOn() then updateConcussionFrame(player, d) end
end, 24, {
    -- frames while Concussion is on (the head's health for the weapon hits, cheap), and
    -- with it off only in a vehicle or with a crash to judge (OnEnterVehicle wakes the set)
    active = function(player)
        local st = stateOf(player)
        local ok, v = pcall(player.getVehicle, player)
        st.inVehicle = ok and v ~= nil   -- trackSpeed's early return; the vehicle events keep it between minutes
        if sandboxOn() then return true end
        return st.inVehicle or st.crash ~= nil
    end })
if Events.OnEnterVehicle then Events.OnEnterVehicle.Add(function(ch) if DanTraits_IsLocalPlayer(ch) then stateOf(ch).inVehicle = true end end) end
if Events.OnExitVehicle then Events.OnExitVehicle.Add(function(ch) if DanTraits_IsLocalPlayer(ch) then stateOf(ch).inVehicle = false end end) end
Events.OnWeaponSwing.Add(onConcussionSwing)

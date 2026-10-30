-- Project Zomboid Vitality Project: ADHD.
--
-- A mind that wanders off the job, and locks on when it catches. Every
-- minute awake:
--   boredom  climbs half as fast again: the stat delta pipeline's boredomRise
--            (registered here, minute order 0) offers each minute's rise and
--            this trait returns it x A.BOREDOM_MULT (less with coffee in you,
--            none hyperfocused). A fall is never touched, so reading, a drink
--            or company bring it down as fast as ever.
--   skill    a skill book (vanilla's SkillBook table knows its skill) at the
--   books    head of the action queue adds A.BOOK_BOREDOM a minute, which the
--            next minute's pipeline counts at x1.5 like any other rise.
--            Novels and magazines are not skill books (DanTraits_Reading).
--            A skill book never builds focus, but hyperfocus carries you
--            through one without the boredom.
--   drifting off  a timed action that is running has a small chance a minute
--            to stop (forceStop: like any interruption, the rest of the queue
--            goes too), more when bored, less with coffee, never while
--            panicked (any Panic moodle) or hyperfocused, never twice within
--            A.GAP_MIN, and never for walking, getting in or out of a car,
--            climbing, resting or a stim (EXEMPT).
--   hyperfocus  each minute with a real action running builds focus;
--            A.FOCUS_AT minutes of it (fewer with coffee) and you lock in:
--            actions started take A.HYPER_TIME of the time (adjustMaxTime,
--            where vanilla's unhappy and drunk slow-downs live), experience
--            x A.HYPER_XP (Events.AddXP, through Age's quiet adjust), boredom
--            does not rise and eases. Walking between jobs neither builds nor
--            breaks it; A.IDLE_END minutes with nothing running, panic, sleep
--            or drifting off end it. Moodle Hyperfocus: Getting Into It (-1)
--            from half way, Hyperfocused (-2).
--   coffee   anyone's caffeine dose reaches DanTraits_AdhdOnCaffeine (the
--            Caffeine file's dose); the trait keeps its own level, halving
--            every A.CAF_HALF_LIFE_H hours, A.CAF_FULL for the full effect: the
--            boredom multiplier down to A.CAF_BOREDOM_MULT, drifting off x
--            (1 - A.CAF_DRIFT_CUT), focus sooner by A.CAF_FOCUS_CUT minutes.
--   novelty  the first time in a building (its footprint, Home's placeOf)
--            takes A.NEW_BOREDOM boredom and A.NEW_UNHAPPY unhappiness off,
--            at most once every A.NEW_GAP_MIN (a building found in the gap
--            stays new). Home eases boredom only A.HOME_BOREDOM as much
--            (Home's homeBoredom hook). Not with Homebody.
--
-- Mod data: adhdNext (world hours: no drifting off before), adhdBookSaid
-- (the id of the skill book whose notice was given), adhdForce (the console's next
-- minute), adhdDrifts (count), adhdFocus (minutes built), adhdIdle (minutes
-- with nothing running), adhdHyper (locked in), adhdCaf (caffeine level),
-- adhdSeen (building keys) and adhdSeenN, adhdNewNext (world hours).
-- Console: adhd | adhd distract | adhd focus
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local notifyGood = DanTraits_NotifyGood
local clamp01 = DanTraits_Clamp01

local A = {
    BOREDOM_MULT  = 1.5,     -- every rise in boredom
    BOOK_BOREDOM  = 0.3,     -- boredom (0..100) a minute reading a skill book, before the x1.5
    DRIFT         = 1 / 150, -- chance a minute a running action stops...
    DRIFT_BORED   = 1.0,     -- ...x(1 + this x boredom 0..1): twice as likely fully bored
    GAP_MIN       = 60,      -- game minutes after drifting off before it can happen again
    DRIFT_MIN_TIME = 200,    -- an action quicker than this (maxTime: a transfer, an equip) is never the one
                             -- drifted off from: stopping it would throw away the whole queue behind it
    PANIC_LEVELS  = { 0.06, 0.3, 0.65, 0.8 },   -- the Panic moodle's tiers, for the fallback read
    LINES         = 4,       -- UI_DanTraits_AdhdDrift_1..n
    -- hyperfocus
    FOCUS_AT      = 20,      -- minutes of steady work to lock in
    IDLE_END      = 3,       -- minutes with nothing running that end it (and reset the build)
    HYPER_TIME    = 0.85,    -- actions started while locked in take this much of the time
    HYPER_XP      = 1.1,     -- experience while locked in
    HYPER_BOREDOM = 0.1,     -- boredom off a minute while locked in
    -- coffee
    CAF_HALF_LIFE_H = 5,
    CAF_FULL      = 100,     -- a mug of coffee
    CAF_BOREDOM_MULT = 1.25, -- the boredom multiplier at the full effect
    CAF_DRIFT_CUT = 0.5,
    CAF_FOCUS_CUT = 5,
    CAF_TELL      = 0.5,     -- the "clearer head" notice from this much effect
    -- novelty
    NEW_BOREDOM   = 15,
    NEW_UNHAPPY   = 3,
    NEW_GAP_MIN   = 30,
    NEW_MAX       = 3000,    -- buildings remembered; past this the list starts over
    HOME_BOREDOM  = 0.5,     -- of Home's boredom relief
}
DanTraits_AdhdC = A

local CAF_DECAY = 0.5 ^ (1 / (A.CAF_HALF_LIFE_H * 60))

-- never interrupted, and neither builds nor breaks focus: moving, cars,
-- climbing, resting, and the things that help
local EXEMPT = {
    ISWalkToTimedAction = true, ISWalkToTimedActionF = true, ISPathFindAction = true,
    ISEnterVehicle = true, ISExitVehicle = true, ISSwitchVehicleSeat = true,
    ISClimbThroughWindow = true, ISOpenCloseDoor = true,
    ISRestAction = true, ISSitOnGround = true, ISSensoryStimAction = true,
}
DanTraits_AdhdExempt = EXEMPT

local function now() return getGameTime():getWorldAgeHours() end

local function adhdData(player)
    local md = player and player:getModData()
    return md and md.DanTraits
end

local function queueHead(player)
    local action = nil
    pcall(function()
        local q = ISTimedActionQueue.getTimedActionQueue(player)
        action = q and q.queue and q.queue[1]
    end)
    return action
end

local function started(action)
    local ok, yes = pcall(function() return action:isStarted() end)
    return not ok or yes ~= false
end

local function isSkillBook(item)
    local yes = false
    pcall(function() yes = SkillBook ~= nil and SkillBook[item:getSkillTrained()] ~= nil end)
    return yes
end

local function panicked(player)
    return DanTraits_MoodleLevel(player, "PANIC", CharacterStat.PANIC, A.PANIC_LEVELS) > 0
end

local function boredom01(player)
    local b = 0
    pcall(function() b = DanTraits_StatFraction(player:getStats(), CharacterStat.BOREDOM) end)
    return b
end

-- 0..1: how much coffee is helping
local function calm(d) return clamp01((d and d.adhdCaf or 0) / A.CAF_FULL) end

local function focusAt(d) return A.FOCUS_AT - A.CAF_FOCUS_CUT * calm(d) end

local function hyper(player)
    local d = adhdData(player)
    return d ~= nil and d.adhdHyper == true and hasTrait(player, "adhd")
end
DanTraits_AdhdHyper = hyper

-- the pipeline: one remembered boredom for everyone, and this trait scales the rise
DanTraits_DeltaHook(CharacterStat and CharacterStat.BOREDOM, "boredomRise", "minute")
DanTraits_AddHook("boredomRise", function(delta, player, d)
    if not hasTrait(player, "adhd") then return nil end
    -- a floor another system raised (Sensory's shutdown, Endorphin Junkie's Restless)
    -- is not the game's rise: DanTraits_FloorUp flags it, and it is neither
    -- multiplied nor, hyperfocused, wiped out (2026-10-22)
    if d and d.floorsThisMinute and d.floorsThisMinute.boredomRise then return nil end
    if d and d.adhdHyper then return 0 end
    local c = calm(d)
    return delta * (A.BOREDOM_MULT + (A.CAF_BOREDOM_MULT - A.BOREDOM_MULT) * c)
end)

-- home is a little dull (DanTraits_Home.lua's relief)
DanTraits_AddHook("homeBoredom", function(amount, player)
    if not hasTrait(player, "adhd") then return nil end
    return amount * A.HOME_BOREDOM
end)

-- coffee: any dose, trait or not, reaches here from DanTraits_Caffeine.lua
function DanTraits_AdhdOnCaffeine(player, amount)
    if not player or not amount or amount <= 0 or not hasTrait(player, "adhd") then return end
    local d = DanTraits_Data(player)
    local before = calm(d)
    d.adhdCaf = (d.adhdCaf or 0) + amount
    if before < A.CAF_TELL and calm(d) >= A.CAF_TELL then notifyGood(player, "UI_DanTraits_AdhdCoffee") end
end

-- locked in, and out
local function lockIn(player, d)
    d.adhdHyper = true
    notifyGood(player, "UI_DanTraits_AdhdHyper")
end

local function snapOut(player, d, quiet)
    local was = d.adhdHyper
    d.adhdHyper, d.adhdFocus = nil, 0
    if was and not quiet then notify(player, "UI_DanTraits_AdhdHyperEnd") end
end

local function driftOff(player, d, action)
    d.adhdNext = now() + A.GAP_MIN / 60
    d.adhdDrifts = (d.adhdDrifts or 0) + 1
    d.adhdFocus = 0
    pcall(function() action:forceStop() end)
    notify(player, "UI_DanTraits_AdhdDrift_" .. tostring(ZombRand and (ZombRand(A.LINES) + 1) or 1))
end

-- somewhere new: the building's footprint is its key
local function buildingKey(player)
    local place = DanTraits_HomePlaceOf and DanTraits_HomePlaceOf(player)
    local b = place and place.b
    if not b then return nil end
    return tostring(b[1]) .. "," .. tostring(b[2])
end

local function novelty(player, d)
    local key = buildingKey(player)
    if not key then return end
    if not d.adhdSeen then
        d.adhdSeen, d.adhdSeenN = { [key] = true }, 1   -- where they start is not new
        return
    end
    if d.adhdSeen[key] or (d.adhdNewNext or 0) > now() then return end
    if (d.adhdSeenN or 0) >= A.NEW_MAX then d.adhdSeen, d.adhdSeenN = {}, 0 end
    d.adhdSeen[key] = true
    d.adhdSeenN = (d.adhdSeenN or 0) + 1
    d.adhdNewNext = now() + A.NEW_GAP_MIN / 60
    local stats = player:getStats()
    DanTraits_StatAdd(stats, CharacterStat.BOREDOM, -A.NEW_BOREDOM)
    DanTraits_StatAdd(stats, CharacterStat.UNHAPPINESS, -A.NEW_UNHAPPY)
    notifyGood(player, "UI_DanTraits_AdhdNew")
end

local function updateAdhdMinute(player, d)
    if d.adhdCaf then
        d.adhdCaf = d.adhdCaf * CAF_DECAY
        if d.adhdCaf < 0.5 then d.adhdCaf = nil end
    end
    if DanTraits_Asleep(player) then
        snapOut(player, d, true)
        d.adhdIdle = 0
        return
    end
    pcall(novelty, player, d)

    local action = queueHead(player)
    local scared = panicked(player)
    if scared then snapOut(player, d) end
    if not action then
        d.adhdBookSaid = nil
        d.adhdIdle = (d.adhdIdle or 0) + 1
        if d.adhdIdle >= A.IDLE_END then snapOut(player, d) end
    elseif not EXEMPT[action.Type or ""] then
        d.adhdIdle = 0
        -- a skill book: a slog, unless locked in already
        local book = action.Type == "ISReadABook" and action.item and isSkillBook(action.item) and action.item or nil
        if book then
            if not d.adhdHyper then
                DanTraits_StatAdd(player:getStats(), CharacterStat.BOREDOM, A.BOOK_BOREDOM)
                local id = book
                pcall(function() id = book:getID() end)
                id = tostring(id)
                if d.adhdBookSaid ~= id then
                    d.adhdBookSaid = id
                    notify(player, "UI_DanTraits_AdhdBook")
                end
            end
        else
            d.adhdBookSaid = nil
            if not scared and started(action) then d.adhdFocus = (d.adhdFocus or 0) + 1 end
        end

        -- drifting off (never from a quick action: the loot queue behind it would go too)
        local quick = tonumber(action.maxTime) ~= nil and action.maxTime < A.DRIFT_MIN_TIME
        if not d.adhdHyper and not scared and not quick and started(action) then
            local force = d.adhdForce
            d.adhdForce = nil
            if force or ((d.adhdNext or 0) <= now()
                    and DanTraits_Roll(A.DRIFT * (1 + A.DRIFT_BORED * boredom01(player)) * (1 - A.CAF_DRIFT_CUT * calm(d)))) then
                driftOff(player, d, action)
                return
            end
        end

        if not d.adhdHyper and not scared and (d.adhdFocus or 0) >= focusAt(d) then lockIn(player, d) end
    end

    if d.adhdHyper then
        -- eased, and the pipeline told: next minute's rise counts from here, so
        -- wiping it does not put this back
        local stats = player:getStats()
        DanTraits_StatAdd(stats, CharacterStat.BOREDOM, -A.HYPER_BOREDOM)
        pcall(function() DanTraits_DeltaRemember(d, "boredomRise", stats:get(CharacterStat.BOREDOM)) end)
    end
end

local function clearAdhd(player, d)
    d.adhdBookSaid, d.adhdForce, d.adhdHyper, d.adhdFocus, d.adhdIdle = nil, nil, nil, nil, nil
end

DanTraits_Every("minute", "ADHD", updateAdhdMinute, 40, { trait = "adhd", clear = clearAdhd })

-- the moodle's level (DanTraits_Moodles.lua): -1 getting into it, -2 locked in
function DanTraits_AdhdMoodle(player, d)
    if not d or not hasTrait(player, "adhd") then return 0 end
    if d.adhdHyper then return -2 end
    if (d.adhdFocus or 0) >= focusAt(d) / 2 then return -1 end
    return 0
end

-- locked in: actions started now go quicker (vanilla's own slow-downs live in
-- adjustMaxTime; wrapped again on OnGameStart in case the class loads late)
local function wrapHyper()
    DanTraits_Wrap(ISBaseTimedAction, "adjustMaxTime", "adhd-hyper", function(original, self, maxTime, ...)
        local t = original(self, maxTime, ...)
        if type(t) == "number" and t > 1 and self.character and hyper(self.character) then t = t * A.HYPER_TIME end
        return t
    end)
end
wrapHyper()
if Events and Events.OnGameStart then Events.OnGameStart.Add(wrapHyper) end

-- locked in: a little more experience (Events.AddXP fires after the game has
-- added it; the factor goes through core's DanTraits_XpFactor, so it multiplies
-- with the other systems' factors on the same gain)
local xpBusy = false
local function onAdhdAddXP(player, perk, amount)
    if xpBusy or not player or not perk or not amount or amount <= 0 then return end
    if DanTraits_AgeXpBusy and DanTraits_AgeXpBusy() then return end
    if not hyper(player) then return end
    xpBusy = true
    DanTraits_XpFactor(player, perk, amount, A.HYPER_XP)
    xpBusy = false
end
if Events and Events.AddXP then Events.AddXP.Add(onAdhdAddXP) end

DanTraits_ExtraCommands = DanTraits_ExtraCommands or {}
DanTraits_ExtraCommands.adhd = function(player, args)
    local d = DanTraits_Data(player)
    if args[1] == "distract" then
        d.adhdForce = true
        return "the next running action stops within a minute (not while panicked or hyperfocused)"
    elseif args[1] == "focus" then
        d.adhdFocus = math.ceil(focusAt(d))
        return "focus full: locked in at the next working minute"
    end
    local action = queueHead(player)
    local wait = math.max(0, ((d.adhdNext or 0) - now()) * 60)
    return "boredom " .. tostring(DanTraits_Round(boredom01(player) * 100, 1))
        .. ", action " .. tostring(action and action.Type or "none")
        .. ", focus " .. tostring(d.adhdFocus or 0) .. "/" .. tostring(DanTraits_Round(focusAt(d), 1))
        .. (d.adhdHyper and " (hyperfocused)" or "")
        .. ", coffee " .. tostring(DanTraits_Round(calm(d), 2))
        .. ", drifted off " .. tostring(d.adhdDrifts or 0) .. " times"
        .. (wait > 0 and (", calm for " .. tostring(math.floor(wait)) .. " more minutes") or "")
        .. ", buildings seen " .. tostring(d.adhdSeenN or 0)
end
